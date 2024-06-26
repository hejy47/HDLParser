
// See HDMI 1.4a Section 5.3.3.
module audio_clock_regeneration_packet
#(
    parameter VIDEO_ID_CODE = 1,
    // 59.94 Hz = 0, 60 Hz = 1
    parameter VIDEO_RATE = 0,
    // 0000 = 44.1 kHz, 0100 = 48 kHz, 1100 = 32 kHz
    parameter AUDIO_RATE = 4'b0000
)
(
    input logic clk_pixel,
    input logic packet_enable,
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);

// See Section 7.2.3. Values taken from Tables 7-1, 7-2, 7-3.
// Indexed by audio rate, video code, video rate, N/CTS
logic [19:0] TABLE [0:2] [0:5] [0:1] [0:1] =
'{
    '{ // 32 kHz
        '{
            '{20'd4576, 20'd28125}, '{20'd4096, 20'd25200}
        },
        '{
            '{20'd4096, 20'd27000}, '{20'd4096, 20'd27027}
        },
        '{
            '{20'd4096, 20'd54000}, '{20'd4096, 20'd54054}
        },
        '{
            '{20'd11648, 20'd210937}, '{20'd4096, 20'd74250}
        },
        '{
            '{20'd11648, 20'd421875}, '{20'd4096, 20'd148500}
        },
        '{
            '{20'd5824, 20'd421875}, '{20'd3072, 20'd222750}
        }
    },
    '{ // 44.1 kHz
        '{
            '{20'd7007, 20'd31250}, '{20'd6272, 20'd28000}
        },
        '{
            '{20'd6272, 20'd30000}, '{20'd6272, 20'd30030}
        },
        '{
            '{20'd6272, 20'd60000}, '{20'd6272, 20'd60060}
        },
        '{
            '{20'd17836, 20'd234375}, '{20'd6272, 20'd82500}
        },
        '{
            '{20'd8918, 20'd234375}, '{20'd6272, 20'd165000}
        },
        '{
            '{20'd4459, 20'd234375}, '{20'd4704, 20'd247500}
        }
    },
    '{ // 48 kHz
        '{
            '{20'd6864, 20'd28125}, '{20'd6144, 20'd25200}
        },
        '{
            '{20'd6144, 20'd27000}, '{20'd6144, 20'd27027}
        },
        '{
            '{20'd6144, 20'd54000}, '{20'd6144, 20'd54054}
        },
        '{
            '{20'd11648, 20'd140625}, '{20'd6144, 20'd74250}
        },
        '{
            '{20'd5824, 20'd140625}, '{20'd6144, 20'd148500}
        },
        '{
            '{20'd5824, 20'd281250}, '{20'd5120, 20'd247500}
        }
    }
};

logic [19:0] N, CTS;

// Intentionally select an invalid index if none of the below were selected
logic [2:0] audio_rate_index = AUDIO_RATE == 4'b0000 ? 3'd1 : AUDIO_RATE == 4'b0100 ? 3'd2 : AUDIO_RATE == 4'b1100 ? 3'd0 : 3'd3;

generate
    case (VIDEO_ID_CODE)
        1:
        begin
            assign N = TABLE[audio_rate_index][0][VIDEO_RATE][0];
            assign CTS = TABLE[audio_rate_index][0][VIDEO_RATE][1];
        end
        2, 3, 6, 7, 8, 9, 17, 18:
        begin
            assign N = TABLE[audio_rate_index][1][VIDEO_RATE][0];
            assign CTS = TABLE[audio_rate_index][1][VIDEO_RATE][1];
            end
        4, 5, 19:
        begin
            assign N = TABLE[audio_rate_index][3][VIDEO_RATE][0];
            assign CTS = TABLE[audio_rate_index][3][VIDEO_RATE][1];
        end
        16:
        begin
            assign N = TABLE[audio_rate_index][4][VIDEO_RATE][0];
            assign CTS = TABLE[audio_rate_index][4][VIDEO_RATE][1];
        end
    endcase
endgenerate


wire [55:0] single_sub = {N[7:0], N[15:8], {4'd0, N[19:16]}, CTS[7:0], CTS[15:8], {4'd0, CTS[19:16]}, 8'd0};
assign header = {8'd0, 8'd0, 8'd1};
// "The four Subpackets each contain the same Audio Clock logiceneration Subpacket."
assign sub = '{single_sub, single_sub, single_sub, single_sub};

endmodule

// See Section 5.3.4.
// 2-channel L-PCM or IEC 61937 audio in IEC 60958 frames with consumer grade IEC 60958-3.
module audio_sample_packet 
#(
    // A thorough explanation of the below parameters can be found in IEC 60958-3 5.2, 5.3.

    // 0 = Consumer, 1 = Professional
    parameter GRADE = 1'b0,

    // 0 = LPCM, 1 = IEC 61937 compressed
    parameter SAMPLE_WORD_TYPE = 1'b0,

    // 0 = asserted, 1 = not asserted
    parameter COPYRIGHT_ASSERTED = 1'b1,

    // 000 = no pre-emphasis, 100 = 50μs/15μs pre-emphasis
    parameter PRE_EMPHASIS = 3'b000,

    // Only one valid value
    parameter MODE = 2'b00,

    // Set to all 0s for general device.
    parameter CATEGORY_CODE = 8'b00000000,

    // TODO: not really sure what this is...
    // 0000 = "Do no take into account"
    parameter SOURCE_NUMBER = 4'b0000,

    // 0000 = 44.1 kHz
    parameter SAMPLING_FREQUENCY = 4'b0000,

    // Normal accuracy: +/- 1000 * 10E-6 (00), High accuracy +/- 50 * 10E-6 (10)
    parameter CLOCK_ACCURACY = 2'b00,

    // Maxmium length of 20 bits (0) or 24 bits (1) followed by a 3-bit representation of the number of bits to subtract (except 101 is actually subtract 0)
    parameter WORD_LENGTH = 4'b0100,

    // Frequency prior to conversion in a consumer playback system. 0000 = not indicated.
    parameter ORIGINAL_SAMPLING_FREQUENCY = 4'b0000,

    // 2-channel = 0, >= 3-channel = 1
    parameter LAYOUT = 1'b0

)
(
    input logic clk_pixel,
    input logic packet_enable,
    // See IEC 60958-1 4.4 and Annex A. 0 indicates the signal is suitable for decoding to an analog audio signal.
    input logic [1:0] valid_bit,
    // See IEC 60958-3 Section 6. 0 indicates that no user data is being sent
    input logic [1:0] user_data_bit,
    input logic [23:0] audio_sample_word [1:0],
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);

// Left/right channel for stereo audio
const bit [3:0] CHANNEL_LEFT = 4'b1000;
const bit [3:0] CHANNEL_RIGHT = 4'b0100;

localparam CHANNEL_STATUS_LENGTH = 8'd192;
// See IEC 60958-1 5.1, Table 2
wire [CHANNEL_STATUS_LENGTH-1:0] channel_status_left = {GRADE, SAMPLE_WORD_TYPE, COPYRIGHT_ASSERTED, PRE_EMPHASIS, MODE, CATEGORY_CODE, SOURCE_NUMBER, CHANNEL_LEFT, SAMPLING_FREQUENCY, CLOCK_ACCURACY, 2'b00, WORD_LENGTH, ORIGINAL_SAMPLING_FREQUENCY, 152'd0};
wire [CHANNEL_STATUS_LENGTH-1:0] channel_status_right = {GRADE, SAMPLE_WORD_TYPE, COPYRIGHT_ASSERTED, PRE_EMPHASIS, MODE, CATEGORY_CODE, SOURCE_NUMBER, CHANNEL_RIGHT, SAMPLING_FREQUENCY, CLOCK_ACCURACY, 2'b00, WORD_LENGTH, ORIGINAL_SAMPLING_FREQUENCY, 152'd0};


logic [7:0] frame_counter = 8'd0;

wire [1:0] parity_bit = {^{audio_sample_word[1], valid_bit[1], user_data_bit[1], channel_status_right[frame_counter]}, ^{audio_sample_word[0], valid_bit[0], user_data_bit[0], channel_status_left[frame_counter]}};

always @(posedge clk_pixel)
begin
    if (packet_enable)
        frame_counter <= frame_counter == (CHANNEL_STATUS_LENGTH-1) ? 8'd0 : frame_counter + 8'd1;
end

// See HDMI 1.4a Table 5-12: Audio Sample Packet Header.
assign header = {{3'b000, frame_counter == 8'd0, 4'b0000}, {3'b000, LAYOUT, 4'b0001}, 8'd2};
// See HDMI 1.4a Table 5-13: Audio Sample Subpacket.
assign sub[3:1] = '{56'd0, 56'd0, 56'd0};
assign sub[0] = {{parity_bit[1], channel_status_right[frame_counter], user_data_bit[1], valid_bit[1], parity_bit[0], channel_status_left[frame_counter], user_data_bit[0], valid_bit[0]}, audio_sample_word[1], audio_sample_word[0]};

endmodule
