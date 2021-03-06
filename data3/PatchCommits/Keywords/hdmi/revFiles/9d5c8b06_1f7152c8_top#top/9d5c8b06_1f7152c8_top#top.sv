module top ();
logic [2:0] tmds_p;
logic tmds_clock_p;
logic [2:0] tmds_n;
logic tmds_clock_n;

logic clk_pixel;
logic clk_pixel_x10;
logic clk_audio;

pll pll(.c0(clk_pixel_x10), .c1(clk_pixel), .c2(clk_audio));

logic [15:0] audio_sample_word [1:0] = '{16'sd0, 16'sd0};
always @(posedge clk_audio)
  audio_sample_word <= '{audio_sample_word[0] + 16'sd1, audio_sample_word[1] - 16'sd1};

logic [23:0] rgb;
logic [9:0] cx, cy;
// Border test (left = red, top = green, right = blue, bottom = blue, fill = black)
always @(posedge clk_pixel)
  rgb <= {cx == 138 ? ~8'd0 : 8'd0, cy == 45 ? ~8'd0 : 8'd0, cx == 857 || cy == 524 ? ~8'd0 : 8'd0};

// 720x480 @ 59.94Hz
hdmi #(.VIDEO_ID_CODE(3), .VIDEO_REFRESH_RATE(59.94), .AUDIO_RATE(48000), .AUDIO_BIT_WIDTH(16)) hdmi(.clk_pixel_x10(clk_pixel_x10), .clk_pixel(clk_pixel), .clk_audio(clk_audio), .rgb(rgb), .audio_sample_word(audio_sample_word), .tmds_p(tmds_p), .tmds_clock_p(tmds_clock_p), .tmds_n(tmds_n), .tmds_clock_n(tmds_clock_n), .cx(cx), .cy(cy));

endmodule
