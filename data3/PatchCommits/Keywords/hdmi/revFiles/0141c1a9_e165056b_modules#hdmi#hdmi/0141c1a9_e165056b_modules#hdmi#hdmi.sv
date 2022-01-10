// Implementation of HDMI Spec v1.4a Section 5.1: Overview, Section 5.2: Operating Modes, Section 5.3.1: Packet Header, Section 5.3.2: Null Packet, Section 5.4.1: Serialization
// By Sameer Puri https://github.com/sameer

module hdmi 
#(
    // Defaults to 640x480 which should be supported by almost if not all HDMI sinks.
    // See CEA-861-D for enumeration of video id codes.
    // Formats 1, 2, 3, 4, 16, 17, 18, and 19 are supported.
    // Pixel repetition, interlaced scans and other special output modes are not implemented.
    parameter VIDEO_ID_CODE = 1,

    // 59.94 Hz = 0, 60Hz = 1
    parameter VIDEO_RATE = 0,

    // As noted in Section 7.3, the minimal audio requirements are met: 16-bit to 24-bit L-PCM audio at 32 kHz, 44.1 kHz, or 48 kHz.
    // 0000 = 44.1 kHz, 0010 = 48 kHz, 0011 = 32 kHz (same as those in IEC 60958-3)
    parameter AUDIO_RATE = 4'b0011,

    // Defaults to minimum bit lengths required to represent positions.
    // Modify these parameters if you have alternate desired bit lengths.
    parameter BIT_WIDTH = VIDEO_ID_CODE < 4 ? 10 : VIDEO_ID_CODE == 4 ? 11 : 12,
    parameter BIT_HEIGHT = VIDEO_ID_CODE == 16 ? 11: 10,

    // Defaults to 16-bit audio.
    parameter AUDIO_BIT_WIDTH = 16,

    // A true HDMI signal can send auxiliary data (i.e. audio, preambles) which prevents it from being parsed by DVI signal sinks.
    // HDMI signal sinks are fortunately backwards-compatible with DVI signals.
    // Enable this flag if the output should be a DVI signal. You might want to do this to reduce logic cell usage or if you're only outputting video.
    parameter DVI_OUTPUT = 1'b0
)
(
    input logic clk_tmds,
    input logic clk_pixel,
    input logic [23:0] rgb,
    input logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word [1:0],
    input logic [7:0] packet_type,

    output logic [2:0] tmds_p,
    output logic tmds_clock_p,
    output logic [2:0] tmds_n,
    output logic tmds_clock_n,
    output logic [BIT_WIDTH-1:0] cx = 0,
    output logic [BIT_HEIGHT-1:0] cy = 0,
    output logic packet_enable
);

// All channels are initialized to the 0,0 control signal from 5.4.2.
// This gives time for the first pixel to be generated due to the 1-pixel clock delay.
logic [9:0] tmds_shift_red = 10'b1101010100, tmds_shift_green = 10'b1101010100, tmds_shift_blue = 10'b1101010100;

// True differential buffer built with altera_gpio_lite from the Intel IP Catalog.
// Interchangeable with Xilinx OBUFDS primitive where .din is .I, .pad_out is .O, .pad_out_b is .OB
OBUFDS obufds(.din({tmds_shift_red[0], tmds_shift_green[0], tmds_shift_blue[0], clk_pixel}), .pad_out({tmds_p, tmds_clock_p}), .pad_out_b({tmds_n,tmds_clock_n}));

// See CEA-861-D for more specifics formats described below.
logic [BIT_WIDTH-1:0] frame_width;
logic [BIT_HEIGHT-1:0] frame_height;
logic [BIT_WIDTH-1:0] screen_width;
logic [BIT_HEIGHT-1:0] screen_height;
logic [BIT_WIDTH-1:0] screen_start_x;
logic [BIT_HEIGHT-1:0] screen_start_y;

generate
    case (VIDEO_ID_CODE)
        1:
        begin
            assign frame_width = 800;
            assign frame_height = 525;
            assign screen_width = 640;
            assign screen_height = 480;
            end
        2, 3:
        begin
            assign frame_width = 858;
            assign frame_height = 525;
            assign screen_width = 720;
            assign screen_height = 480;
            end
        4:
        begin
            assign frame_width = 1650;
            assign frame_height = 750;
            assign screen_width = 1280;
            assign screen_height = 720;
        end
        16:
        begin
            assign frame_width = 2200;
            assign frame_height = 1125;
            assign screen_width = 1920;
            assign screen_height = 1080;
        end
        17, 18:
        begin
            assign frame_width = 864;
            assign frame_height = 625;
            assign screen_width = 720;
            assign screen_height = 576;
        end
        19:
        begin
            assign frame_width = 1980;
            assign frame_height = 750;
            assign screen_width = 1280;
            assign screen_height = 720;
        end
    endcase
    assign screen_start_x = frame_width - screen_width;
    assign screen_start_y = frame_height - screen_height;
endgenerate

logic hsync = 0;
logic vsync = 0;
always @(posedge clk_pixel)
begin
case (VIDEO_ID_CODE)
    1:
    begin
        hsync <= ~(cx > 15 && cx <= 15 + 96);
        vsync <= ~(cy < 2);
    end
    2, 3:
    begin
        hsync <= ~(cx > 15 && cx <= 15 + 62);
        vsync <= ~(cy > 5 && cy < 12);
    end
    4:
    begin
        hsync <= cx > 109 && cx <= 109 + 40;
        vsync <= cy < 5;
    end
    16:
    begin
        hsync <= cx > 87 && cx <= 87 + 44;
        vsync <= cy < 5;
    end
    17, 18:
    begin
        hsync <= ~(cx > 11 && cx <= 11 + 64);
        vsync <= ~(cy < 5);
    end
    19:
    begin
        hsync <= cx > 439 && cx <= 439 + 40;
        vsync <= cy < 5;
    end
endcase
end

// Wrap-around pixel position counters
always @(posedge clk_pixel)
begin
    cx <= cx == frame_width-1'b1 ? 1'b0 : cx + 1'b1;
    cy <= cx == frame_width-1'b1 ? cy == frame_height-1'b1 ? 1'b0 : cy + 1'b1 : cy;
end

// See Section 5.2
wire video_data_period = cx >= screen_start_x && cy >= screen_start_y;
wire video_guard = !DVI_OUTPUT && (cx >= screen_start_x - 2 && cx < screen_start_x) && cy >= screen_start_y;
wire video_preamble = !DVI_OUTPUT && (cx >= screen_start_x - 10 && cx < screen_start_x - 2) && cy >= screen_start_y;

// See Section 5.2.3.1
logic data_island_guard;
logic data_island_preamble;
logic data_island_period;
logic [4:0] num_packets;

assign num_packets = (((frame_width - screen_start_x - 2) - ((frame_width - screen_start_x - 2) % 32)) / 32 > 18) ? 5'd18 : ((frame_width - screen_start_x - 2) - ((frame_width - screen_start_x - 2) % 32)) / 32; // See 5.2.3.2 -- limited to 18 or fewer.
assign data_island_guard = !DVI_OUTPUT && ((cx >= screen_start_x - 2 && cx < screen_start_x) || (cx >= screen_start_x + num_packets * 32 && cx < screen_start_x + num_packets *32 + 2)) && cy < screen_start_y;
assign data_island_preamble = !DVI_OUTPUT && (cx >= screen_start_x - 10 && cx < screen_start_x - 2) && cy < screen_start_y;
assign data_island_period = !DVI_OUTPUT && (cx >= screen_start_x && cx < screen_start_x + num_packets * 32) && cy < screen_start_y;

logic [2:0] mode = 3'd0;
logic [23:0] video_data = 24'd0;
logic [11:0] data_island_data = 12'd0;
logic [5:0] control_data = 6'd0;


logic [8:0] packet_data;
logic packet_enable_fanout [127:0];

logic [23:0] headers [127:0];
logic [55:0] subs [127:0] [3:0];

logic [23:0] header;
logic [55:0] sub [3:0];

// See Section 5.3

// NULL packet
assign headers[0] = 24'd0; assign subs[0] = '{56'd0, 56'd0, 56'd0, 56'd0};

audio_clock_regeneration_packet #(.VIDEO_ID_CODE(VIDEO_ID_CODE), .VIDEO_RATE(VIDEO_RATE), .AUDIO_RATE(AUDIO_RATE)) audio_clock_regeneration_packet (.clk_pixel(clk_pixel), .packet_enable(packet_enable_fanout[1]), .header(headers[1]), .sub(subs[1]));

logic [23:0] audio_sample_word_padded [1:0];

assign audio_sample_word_padded = '{{(24-AUDIO_BIT_WIDTH)'(0), audio_sample_word[1]}, {(24-AUDIO_BIT_WIDTH)'(0), audio_sample_word[0]}};
generate
    if (AUDIO_BIT_WIDTH < 16 || AUDIO_BIT_WIDTH > 24)
        audio_sample_packet #(.SAMPLING_FREQUENCY(AUDIO_RATE), .WORD_LENGTH(-1))                                    audio_sample_packet (.clk_pixel(clk_pixel), .packet_enable(packet_enable_fanout[2]), .valid_bit(2'b11), .user_data_bit(2'b00), .audio_sample_word(audio_sample_word_padded), .header(headers[2]), .sub(subs[2]));
    else if (AUDIO_BIT_WIDTH == 20)
        audio_sample_packet #(.SAMPLING_FREQUENCY(AUDIO_RATE), .WORD_LENGTH({3'b101, 1'b0}))                        audio_sample_packet (.clk_pixel(clk_pixel), .packet_enable(packet_enable_fanout[2]), .valid_bit(2'b11), .user_data_bit(2'b00), .audio_sample_word(audio_sample_word_padded), .header(headers[2]), .sub(subs[2]));
    else if (AUDIO_BIT_WIDTH < 20)
        audio_sample_packet #(.SAMPLING_FREQUENCY(AUDIO_RATE), .WORD_LENGTH({3'(20 - AUDIO_BIT_WIDTH) << 3, 1'b0})) audio_sample_packet (.clk_pixel(clk_pixel), .packet_enable(packet_enable_fanout[2]), .valid_bit(2'b11), .user_data_bit(2'b00), .audio_sample_word(audio_sample_word_padded), .header(headers[2]), .sub(subs[2]));
    else if (AUDIO_BIT_WIDTH == 24)
        audio_sample_packet #(.SAMPLING_FREQUENCY(AUDIO_RATE), .WORD_LENGTH({3'b101, 1'b1}))                        audio_sample_packet (.clk_pixel(clk_pixel), .packet_enable(packet_enable_fanout[2]), .valid_bit(2'b11), .user_data_bit(2'b00), .audio_sample_word(audio_sample_word_padded), .header(headers[2]), .sub(subs[2]));
    else if (AUDIO_BIT_WIDTH < 24)
        audio_sample_packet #(.SAMPLING_FREQUENCY(AUDIO_RATE), .WORD_LENGTH({3'(24 - AUDIO_BIT_WIDTH) << 3, 1'b1}))   audio_sample_packet (.clk_pixel(clk_pixel), .packet_enable(packet_enable_fanout[2]), .valid_bit(2'b11), .user_data_bit(2'b00), .audio_sample_word(audio_sample_word_padded), .header(headers[2]), .sub(subs[2]));
endgenerate


// See Section 5.2.3.4
packet_picker packet_picker (.packet_enable(packet_enable), .packet_type(packet_type), .headers(headers), .subs(subs), .packet_enable_fanout(packet_enable_fanout), .header(header), .sub(sub));
packet_assembler packet_assembler (.clk_pixel(clk_pixel), .enable(data_island_period), .header(header), .sub(sub), .packet_data(packet_data), .packet_enable(packet_enable));

always @(posedge clk_pixel)
begin
    mode <= data_island_guard ? 3'd4 : data_island_period ? 3'd3 : video_guard ? 3'd2 : video_data_period ? 3'd1 : 3'd0;
    video_data <= rgb;
    // See Section 5.2.3.4, Section 5.3.1, Section 5.3.2
    data_island_data[11:4] <= packet_data[8:1];
    data_island_data[3] <= cx != screen_start_x;
    data_island_data[2] <= packet_data[0];
    data_island_data[1:0] <= {vsync, hsync};
    control_data <= {{1'b0, data_island_preamble}, {1'b0, video_preamble || data_island_preamble}, {vsync, hsync}}; // ctrl3, ctrl2, ctrl1, ctrl0, vsync, hsync
end

logic [9:0] tmds_red, tmds_green, tmds_blue;
tmds_channel #(.CN(2)) red_channel (.clk_pixel(clk_pixel), .video_data(video_data[23:16]), .data_island_data(data_island_data[11:8]), .control_data(control_data[5:4]), .mode(mode), .tmds(tmds_red));
tmds_channel #(.CN(1)) green_channel (.clk_pixel(clk_pixel), .video_data(video_data[15:8]), .data_island_data(data_island_data[7:4]), .control_data(control_data[3:2]), .mode(mode), .tmds(tmds_green));
tmds_channel #(.CN(0)) blue_channel (.clk_pixel(clk_pixel), .video_data(video_data[7:0]), .data_island_data(data_island_data[3:0]), .control_data(control_data[1:0]), .mode(mode), .tmds(tmds_blue));

// See Section 5.4.1
logic [3:0] tmds_counter = 4'd0;

always @(posedge clk_tmds)
begin
    if (tmds_counter == 4'd10)
    begin
        tmds_shift_red <= tmds_red;
        tmds_shift_green <= tmds_green;
        tmds_shift_blue <= tmds_blue;
        tmds_counter <= 4'd1;
    end
    else
    begin
        tmds_shift_red <= tmds_shift_red[9:1];
        tmds_shift_green <= tmds_shift_green[9:1];
        tmds_shift_blue <= tmds_shift_blue[9:1];
        tmds_counter <= tmds_counter + 4'd1;
    end
end

endmodule
