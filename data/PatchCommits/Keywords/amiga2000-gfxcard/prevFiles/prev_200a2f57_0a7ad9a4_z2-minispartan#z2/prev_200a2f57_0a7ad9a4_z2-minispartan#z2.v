`timescale 1ns / 1ns
// Company: MNT Media and Technology UG
// Engineer: Lukas F. Hartmann (@mntmn)
// Create Date:    21:49:19 03/22/2016 
// Design Name:    Amiga 2000/3000/4000 Graphics Card (VA2000) Revision 1.7.2
// Module Name:    z2
// Target Devices: 

module z2(
input CLK50,

// zorro
input znCFGIN,
output znCFGOUT,
output znSLAVEN,
output zXRDY,
input znBERR,
input znRST,
input zE7M,
input zREAD,
input zDOE,

// z3
input zSENSEZ3,
input znFCS,
input zFC0,
input zFC1,
input zFC2,
input znDS0,
input znDS1,
output znCINH,
output znDTACK,

// address bus
input znAS,
input znUDS, // ds2+ds3
input znLDS,
inout [22:0] zA,

// data bus
output zDIR1,
output zDIR2,
output zDIR3,
output zDIR4,
inout [15:0] zD,

// SD
output SD_nCS,
output SD_MOSI,
input  SD_MISO,
output SD_SCLK,
input SD_DAT1,
input SD_DAT2,

// Capture
input videoHS,
input videoVS,
input videoR0,
input videoR1,
input videoR2,
input videoR3,
input videoG0,
input videoG1,
input videoG2,
input videoG3,
input videoB0,
input videoB1,
input videoB2,
input videoB3,

// SDRAM
output SDRAM_CLK,  
output SDRAM_CKE,  
output SDRAM_nCS,   
output SDRAM_nRAS,  
output SDRAM_nCAS,
output SDRAM_nWE,   
output [1:0]  SDRAM_DQM,  
output [12:0] A, 
output [1:0]  SDRAM_BA,
inout  [15:0] D,

// HDMI
output [3:0] TMDS_out_P,
output [3:0] TMDS_out_N

`ifdef SIMULATION
,
input z_sample_clk,
input vga_clk
`endif
);

reg clk_reset=0;

`ifndef SIMULATION
clk_wiz_v3_6 DCM(
  .CLK_IN1(CLK50),
  
  .CLK_OUT1(z_sample_clk),
  .CLK_OUT2(sd_clk),
  
  .CLK_OUT3(clk75_unbuffered),
  .CLK_OUT4(clk40_unbuffered)
);

reg dcm7_psen = 0;
reg dcm7_psincdec = 0;
reg dcm7_rst = 0;

reg [7:0] dcm7_counter = 32;

DCM_SP #(
  .CLKIN_PERIOD(140.0),
  .CLKOUT_PHASE_SHIFT("VARIABLE"),
  .CLKFX_MULTIPLY(2),
  .CLKDV_DIVIDE(2),
  // -16, -4 perfect on A2000
  // 16 perfect on A3000
  .PHASE_SHIFT(0),
  .CLKFX_DIVIDE(1))
dcm7 (
  .CLKIN(zE7M),
  .RST(dcm7_rst),
  .CLKFB(dcm7_0),
  .CLK0(dcm7_0),
  .CLK90(dcm7_90),
  .CLK180(dcm7_180),
  .CLK270(dcm7_270),
  .PSCLK(z_sample_clk),
  .PSEN(dcm7_psen),
  .PSINCDEC(dcm7_psincdec),
  .PSDONE(dcm7_psdone)
);

reg [1:0] vga_clk_sel = 0;

// pixel clock selector
// 00 == 75mhz
// 01 == 40mhz
// 11 == 100mhz
// #(.CLK_SEL_TYPE("ASYNC"))

reg [1:0] vga_clk_sel0_latch = 0;

BUFGMUX vga_clk_mux2(
  .O(vga_clk), 
  .I0(clk75_unbuffered),
  .I1(clk40_unbuffered),
  .S(vga_clk_sel0_latch[1])
);

// sd card interface
reg sd_reset = 0;
reg sd_read = 0;
reg sd_write = 0;
reg sd_continue = 0;

reg [31:0] sd_addr_in = 0;
reg [7:0] sd_data_in = 0;
reg sd_handshake_in = 0;

wire sd_busy;
wire [7:0] sd_data_out;
wire [15:0] sd_error;
wire sd_handshake_out;
wire sd_state;

reg [7:0] sd_data_out_sync;
reg [15:0] sd_error_sync;
reg sd_busy_sync;
reg sd_handshake_out_sync;

SdCardCtrl sdcard(
  .clk_i(sd_clk),
  .reset_i(sd_reset),
  .rd_i(sd_read),
  .wr_i(sd_write),
  .continue_i(sd_continue),
  .addr_i(sd_addr_in),
  .data_i(sd_data_in),
  .data_o(sd_data_out),
  .busy_o(sd_busy),
  .error_o(sd_error),
  .state_o(sd_state),
  
  .cs_bo(SD_nCS),
  .mosi_o(SD_MOSI),
  .miso_i(SD_MISO),
  .sclk_o(SD_SCLK),
  
  .hndShk_i(sd_handshake_in),
  .hndShk_o(sd_handshake_out)
);

`endif

reg  sdram_reset = 0;
reg  ram_enable = 0;
reg  [23:0] ram_addr = 0;
wire [15:0] ram_data_out;
wire data_out_ready;
wire data_out_queue_empty;
wire [4:0] sdram_state;
wire sdram_btb;
reg  [15:0] ram_data_in;
reg  [15:0] ram_data_in_next;
reg  ram_write = 0;
reg  ram_burst = 0;
reg  ram_write_burst = 0;
reg  [1:0]  ram_byte_enable;

parameter FETCHW = 1024;
reg  [15:0] fetch_buffer [0:(FETCHW+40)];
reg  [23:0] scale_buffer [0:639];
reg  [15:0] sb0;
reg  [11:0] fetch_x = 0;

reg  [23:0] fetch_y = 0;
reg  [23:0] pan_ptr = 0;
reg  fetching = 0;

reg display_enable = 1;

reg [10:0] glitchx2_reg = 'h1fd;
reg [8:0]  ram_burst_col = 'h1fe; //'b111111010;

reg [15:0] fetch_w = FETCHW;
reg [15:0] fetch_preroll = 1;//'h3ff;
//parameter fetch_preroll = 64;

reg [15:0] row_pitch = 1024;
reg [3:0] row_pitch_shift = 10; // 1024 = 1<<10

reg [15:0] blitter_row_pitch = 2048;
reg [3:0] blitter_row_pitch_shift = 11; // 2048 = 1<<11

// custom refresh mechanism
reg [23:0] refresh_addr = 0;
reg [23:0] refresh_counter = 0;
reg [23:0] refresh_max = 'h100;

// SDRAM
SDRAM_Controller_v sdram(
  .clk(z_sample_clk),
  .reset(sdram_reset),
  
  // command and write port
  .cmd_ready(cmd_ready),
  .cmd_enable(ram_enable),
  .cmd_wr(ram_write),
  .cmd_byte_enable(ram_byte_enable),
  .cmd_address(ram_addr),
  .cmd_data_in(ram_data_in),
  .cmd_data_in_next(ram_data_in_next),
  .burst_col(ram_burst_col),
  .burst(ram_burst),
  .write_burst(ram_write_burst),
  
  // read data port
  .data_out(ram_data_out),
  .data_out_ready(data_out_ready),
  .data_out_queue_empty(data_out_queue_empty),

  // signals
  .SDRAM_CLK(SDRAM_CLK),
  .SDRAM_CKE(SDRAM_CKE),
  .SDRAM_CS(SDRAM_nCS),
  .SDRAM_RAS(SDRAM_nRAS),
  .SDRAM_CAS(SDRAM_nCAS),
  .SDRAM_WE(SDRAM_nWE),
  .SDRAM_DATA(D),
  .SDRAM_ADDR(A),
  .SDRAM_DQM(SDRAM_DQM),
  .SDRAM_BA(SDRAM_BA)
);

// dvi out
reg [7:0] red_p;
reg [7:0] green_p;
reg [7:0] blue_p;
reg [7:0] red_p_dly;
reg [7:0] green_p_dly;
reg [7:0] blue_p_dly;
reg dvi_vsync;
reg dvi_hsync;
reg dvi_blank;
reg dvi_vsync_dly;
reg dvi_hsync_dly;
reg dvi_blank_dly;
reg [3:0] tmds_out_pbuf;
reg [3:0] tmds_out_nbuf;
assign TMDS_out_P = tmds_out_pbuf;
assign TMDS_out_N = tmds_out_nbuf;
reg dvid_reset = 0;
reg [1:0] dvid_reset_sync = 0;

`ifndef SIMULATION
dvid_out dvid_out(
  // Clocking
  .clk_pixel(vga_clk),
  // VGA signals
  .red_p(red_p),
  .green_p(green_p),
  .blue_p(blue_p),
  .blank(dvi_blank),
  .hsync(dvi_hsync),
  .vsync(dvi_vsync),
  // TMDS outputs
  .tmds_out_p(tmds_out_pbuf),
  .tmds_out_n(tmds_out_nbuf),
  .reset(dvid_reset_sync[1])
);
`endif

// vga registers
reg [11:0] counter_x = 0;
reg [11:0] counter_y = 0;
reg [11:0] display_x2 = 0;
reg [11:0] display_x3 = 0;

// modeline
reg [11:0] h_rez        = 1280;
reg [11:0] h_sync_start = 1280+72;
reg [11:0] h_sync_end   = 1280+80;
reg [11:0] h_max        = 1647;
reg [11:0] v_rez        = 720;
reg [11:0] v_sync_start = 720+3;
reg [11:0] v_sync_end   = 720+8;
reg [11:0] v_max        = 749;
reg [11:0] screen_w = 1280;
reg [11:0] screen_h = 720;
reg [11:0] screen_w_with_margin = 1280;

// zorro port buffers / flags
reg ZORRO3 = 1; 
reg [23:0] zaddr; // zorro 2 address
reg [31:0] zaddr_sync;
reg [31:0] zaddr_sync2;
reg [23:0] z2_mapped_addr;
reg [15:0] data;
reg [15:0] data_in;
reg [15:0] regdata_in;
reg [15:0] data_z3_hi16;
reg [15:0] data_z3_low16;

reg [15:0] data_z3_hi16_latched;
reg [15:0] data_z3_low16_latched;

reg [15:0] data_in_z3_low16;
reg [15:0] zdata_in_sync;
reg [15:0] z3_din_high_s2;
reg [15:0] z3_din_low_s2;
reg [31:0] z3addr;
reg [31:0] z3addr2;
reg [31:0] z3addr3;
reg [31:0] z3_mapped_addr;
reg [31:0] z3_read_addr;
reg [15:0] z3_read_data;
reg [31:0] rr_data;

reg z_confout = 0;
assign znCFGOUT = znCFGIN?1'b1:(~z_confout);

// zorro data output stages
reg dataout = 0;
reg dataout_z3 = 0;
reg dataout_z3_latched = 0;
reg dataout_enable = 0;
reg slaven = 0;
reg dtack = 0;
reg dtack_latched = 0;

// level shifter direction pins
assign zDIR1     = zDOE & ((dataout_enable | dataout_z3_latched)); // d2-d9
assign zDIR2     = zDOE & ((dataout_enable | dataout_z3_latched)); // d10-15, d0-d1
assign zDIR3     = zDOE & (dataout_z3_latched); // a16-a23 <- input
assign zDIR4     = zDOE & (dataout_z3_latched); // a8-a15 <- input

reg z_ovr = 0;
assign zXRDY  = 1'bZ;
assign znCINH = z_ovr?1'b0:1'bZ; // Z2 = /OVR

assign znSLAVEN = (/*dataout &&*/ slaven)?1'b0:1'b1;
assign znDTACK  = (zDOE & dtack_latched)?1'b0:1'bZ;

assign zD  = (zDOE & dataout_z3_latched) ? data_z3_hi16_latched : ((zDOE & dataout) ? data : 16'bzzzz_zzzz_zzzz_zzzz); // data = Z2: full 16 bit or Z3: upper 16 bit
assign zA  = (zDOE & dataout_z3_latched) ? {data_z3_low16_latched, 7'bzzzz_zzz} : 23'bzzz_zzzz_zzzz_zzzz_zzzz_zzzz;

// autoconf status
reg z3_confdone = 0;

// zorro synchronizers
// (inspired by https://github.com/endofexclusive/greta/blob/master/hdl/bus_interface/bus_interface.vhdl)

reg [3:0] znAS_sync  = 3'b111;
reg [3:0] znUDS_sync = 3'b000;
reg [3:0] znLDS_sync = 3'b000;
reg [3:0] zREAD_sync = 3'b000;

reg [2:0] znFCS_sync = 3'b111;
reg [2:0] znDS1_sync = 3'b000;
reg [2:0] znDS0_sync = 3'b000;
reg [1:0] znRST_sync = 2'b11;
reg [1:0] zDOE_sync = 2'b00;
reg [4:0] zE7M_sync = 5'b00000;
reg [2:0] znCFGIN_sync = 3'b000;

reg SD_DAT1_sync = 1'b0;
reg SD_DAT2_sync = 1'b0;
reg zFC0_sync = 1'b0;
reg zFC1_sync = 1'b0;
reg zFC2_sync = 1'b0;
reg zSENSEZ3_sync = 1'b0;
reg znBERR_sync = 1'b0;

wire e7m_shifted1;
assign e7m_shifted1 = zE7M_sync[2];

reg [23:0] last_addr = 0;
reg [23:0] last_read_addr = 0;
reg [15:0] last_data = 0;
reg [15:0] last_read_data = 0;

// 8 bit palette regs
reg [7:0] palette_r [0:255];
reg [7:0] palette_g [0:255];
reg [7:0] palette_b [0:255];

// sprites, currently disabled
/*reg [15:0] sprite_a1 [0:127];
reg [15:0] sprite_a2 [0:127];
reg [10:0] sprite_ax = 0;
reg [10:0] sprite_ay = 0;
reg [10:0] sprite_ax2 = 15;
reg [10:0] sprite_ay2 = 15;
reg [7:0] sprite_ptr  = 0;
reg [4:0] sprite_bit = 15;
reg [1:0] sprite_pidx = 0;
reg [7:0] sprite_palette_r [0:3];
reg [7:0] sprite_palette_g [0:3];
reg [7:0] sprite_palette_b [0:3];*/

// 0 == 8 bit
// 1 == 16 bit
// 2 == 32 bit
reg [2:0] colormode = 1;
reg [2:0] blitter_colormode = 1;
reg [1:0] scalemode_h = 0;
reg [1:0] scalemode_v = 0;

reg [15:0] REVISION = 72; // 1.7.2

// memory map
parameter reg_size = 32'h01000;
parameter autoconf_low  = 24'he80000;
parameter autoconf_high = 24'he80080;
reg [31:0] z3_ram_low = 32'h48000000;
parameter z3_ram_size = 32'h02000000;
reg [31:0] z3_ram_high = 32'h48000000 + z3_ram_size-'h10000-4;
reg [31:0] z3_reg_low  = 32'h48000000 + z3_ram_size-'h10000;
reg [31:0] z3_reg_high = 32'h48000000 + z3_ram_size-'h10000 + reg_size;

reg [31:0] ram_low = 32'h600000;
parameter ram_size = 32'h400000;
reg [31:0] ram_high = 32'h9f0000;
reg [31:0] reg_low  = 32'h9f0000;
reg [31:0] reg_high = 32'h9f1000;

reg [7:0] read_counter = 0;
reg [7:0] dataout_time = 'h02;
reg [7:0] datain_time = 'h10;
reg [7:0] datain_counter = 0;

reg [4:0] margin_x = 10;
reg [10:0] safe_x1 = 0;
reg [10:0] safe_x2 = 'h220; //'h60;

// blitter registers
reg [15:0] blitter_x1 = 0; // 20
reg [15:0] blitter_y1 = 0; // 22
reg [15:0] blitter_x2 = 0; // 24
reg [15:0] blitter_y2 = 0; // 26
reg [15:0] blitter_x3 = 0; // 2c
reg [15:0] blitter_y3 = 0; // 2e
reg [15:0] blitter_x4 = 0; // 30
reg [15:0] blitter_y4 = 0; // 32

reg [15:0] blitter_rgb = 'h0008; // 28
reg [15:0] blitter_copy_rgb = 'h0000;
reg [15:0] blitter_rgb32 [0:1];
reg blitter_rgb32_t = 0;
reg [2:0]  blitter_enable = 0; // 2a
reg [23:0] blitter_base = 0;
reg [23:0] blitter_base2 = 0;
reg [23:0] blitter_ptr = 0;
reg [23:0] blitter_ptr2 = 0;

reg [15:0] blitter_curx = 0;
reg [15:0] blitter_cury = 0;
reg [15:0] blitter_curx2 = 0;
reg [15:0] blitter_cury2 = 0;

reg write_stall = 0;

// main FSM
parameter RESET = 0;
parameter Z2_CONFIGURING = 1;
parameter Z2_IDLE = 2;
parameter WAIT_WRITE = 3;
parameter WAIT_WRITE2 = 4;
parameter Z2_WRITE_FINALIZE = 5;
parameter WAIT_READ = 6;
parameter WAIT_READ2 = 7;
parameter WAIT_READ3 = 8;

parameter CONFIGURED = 9;
parameter CONFIGURED_CLEAR = 10;
parameter DECIDE_Z2_Z3 = 11;

parameter Z3_IDLE = 12;
parameter Z3_WRITE_UPPER = 13;
parameter Z3_WRITE_LOWER = 14;
parameter Z3_READ_UPPER = 15;
parameter Z3_READ_LOWER = 16;
parameter Z3_READ_DELAY = 17;
parameter Z3_READ_DELAY1 = 18;
parameter Z3_READ_DELAY2 = 19;
parameter Z3_WRITE_PRE = 20;
parameter Z3_WRITE_FINALIZE = 21;
parameter Z3_ENDCYCLE = 22;
parameter Z3_DTACK = 23;
parameter Z3_CONFIGURING = 24;

parameter Z2_REGWRITE = 25;
parameter REGWRITE = 26;
parameter REGREAD = 27;
parameter Z2_REGREAD_POST = 28;
parameter Z3_REGREAD_POST = 29;
parameter Z3_REGWRITE = 30;
parameter Z2_REGREAD = 31;
parameter Z3_REGREAD = 32;

parameter Z2_PRE_CONFIGURED = 34;
parameter Z2_ENDCYCLE = 35;

parameter RESET_DVID = 39;
parameter COLD = 40;

reg [6:0] zorro_state = COLD;
reg zorro_read = 0;
reg zorro_write = 0;
reg z2_read = 0;
reg z2_write = 0;

reg datastrobe_synced = 0;
reg zaddr_in_ram = 0;
reg zaddr_in_reg = 0;
reg zaddr_autoconfig = 0;

reg z_cfgin = 0;
reg z_cfgin_lo = 0;
reg z_reset = 0;
reg z3addr_in_ram = 0;
reg z3addr_in_reg = 0;
reg z3addr_autoconfig = 0;
reg [15:0] zaddr_regpart = 0;
reg [15:0] z3addr_regpart = 0;
reg [15:0] regread_addr = 0;
reg [15:0] regwrite_addr = 0;

//`define ANALYZER 1
//`define TRACE 1
parameter ANSIZE = 639;

`ifdef ANALYZER
// logic analyzer
reg rec_enable = 0;
reg [11:0] rec_idx;
reg rec_zreadraw [0:ANSIZE];
reg rec_zread [0:ANSIZE];
reg rec_zwrite [0:ANSIZE];
reg rec_zas0 [0:ANSIZE];
reg rec_zas1 [0:ANSIZE];
reg rec_zaddr_in_ram [0:ANSIZE];
reg rec_state [0:ANSIZE];
reg rec_statew [0:ANSIZE];
reg rec_ready [0:ANSIZE];
reg rec_endcycle [0:ANSIZE];
`endif

reg row_fetched = 0;

reg z2_uds = 0;
reg z2_lds = 0;

reg z3_din_latch = 0;
reg z3_fcs_state = 0;

// video capture regs
reg videocap_mode = 0;
reg [9:0] videocap_x = 0;
reg [9:0] videocap_x2 = 0;
reg [9:0] videocap_y = 0;
reg [9:0] videocap_y2 = 0;
reg [9:0] videocap_ymax = 0;
reg [9:0] videocap_y3 = 0;
reg [23:0] videocap_addr = 0;
reg [15:0] videocap_data = 0;
reg [9:0] videocap_hs = 0;
reg [9:0] videocap_hs2 = 0;
reg [9:0] videocap_vs = 0;
reg [2:0] videocap_state = 0;
reg [9:0] videocap_xpoint = 'h27e; //'h3ff;
reg [9:0] videocap_save_x = 0;
reg [9:0] videocap_save_x2 = 0;
reg [9:0] videocap_line_saved_y = 0;
reg  [23:0] videocap_save_next_addr = 0;
reg  [23:0] videocap_save_base = 0;
reg videocap_line_saved = 0;

reg [15:0] videocap_rgbin = 0;
reg [15:0] videocap_rgbin2 = 0;
reg [9:0]  videocap_default_w = 640;
reg [9:0]  videocap_default_h = 512; //480;
reg [9:0]  videocap_voffset = 'h2a;
reg [9:0] videocap_prex = 'h41;
reg [9:0] videocap_prex2 = 0;
reg [9:0] videocap_height = 'h200; //'h117; // 'h127;
reg [8:0] videocap_width = 320; //318; // FIXME

reg [7:0] vscount = 0;
reg vsynced = 0;

reg vcbuf=0;

parameter VCAPW = 399;

reg [15:0] videocap_buf [0:VCAPW];
reg [15:0] videocap_buf2 [0:VCAPW];
reg videocap_lace_field=0;
reg videocap_interlace=0;
reg videocap_ntsc=0;
reg [9:0] videocap_voffset2=0;

// VIDEO CAPTURE -----------------------------------------------------
always @(posedge dcm7_0) begin
  videocap_hs <= {videocap_hs[8:0], videoHS};
  videocap_vs <= {videocap_vs[8:0], videoVS};
  
  videocap_rgbin <= {videoR3,videoR2,videoR1,videoR0,videoR3, 
                     videoG3,videoG2,videoG1,videoG0,videoG3,videoG2,
                     videoB3,videoB2,videoB1,videoB0,videoB3};
  
  if (!videocap_mode) begin
    // do nothing
  end else if (videocap_vs[6:1]=='b111000) begin
    if (videocap_y2>1) begin
      if (videocap_ymax=='h270 || videocap_ymax=='h20c)
        videocap_lace_field <= 0;
      else
        videocap_lace_field <= ~videocap_lace_field;
        
      if (videocap_ymax=='h138 || videocap_ymax=='h271) begin
        videocap_interlace <= 1;
        videocap_ntsc <= 0;
      end else if (videocap_ymax=='h106 || videocap_ymax=='h20d) begin
        videocap_interlace <= 1;
        videocap_ntsc <= 1;
      end else if (videocap_ymax=='h273) begin
        videocap_interlace <= 0;
        videocap_ntsc <= 0;
      end else  if (videocap_ymax=='h20f) begin
        videocap_interlace <= 0;
        videocap_ntsc <= 1;
      end
      
      if (videocap_interlace) begin
        videocap_y2 <= videocap_lace_field;
        videocap_voffset2 <= videocap_voffset<<1;
      end else begin
        videocap_y2 <= 0;
        videocap_voffset2 <= videocap_voffset;
      end
      
      videocap_ymax <= videocap_y2;
    end
  end else if (videocap_hs[6:1]=='b000111) begin
    videocap_x <= 0;
    if (videocap_interlace)
      videocap_y2 <= videocap_y2 + 2'b10;
    else
      videocap_y2 <= videocap_y2 + 1'b1;
  end else if (videocap_x<VCAPW) begin
    videocap_x <= videocap_x + 1'b1;
    videocap_buf[videocap_x-videocap_prex] <= videocap_rgbin;
  end
end

always @(posedge dcm7_180) begin
  videocap_rgbin2 <= {videoR3,videoR2,videoR1,videoR0,videoR3, 
                    videoG3,videoG2,videoG1,videoG0,videoG3,videoG2,
                    videoB3,videoB2,videoB1,videoB0,videoB3};
  
  if (!videocap_mode) begin
    // do nothing
  end else if (videocap_hs[6:1]=='b000111) begin
    videocap_x2 <= 0;
  end else if (videocap_x2<VCAPW) begin
    videocap_x2 <= videocap_x2 + 1'b1;
    videocap_buf2[videocap_x2-videocap_prex] <= videocap_rgbin2;
  end
end

always @(posedge z_sample_clk) begin
  znUDS_sync  <= {znUDS_sync[1:0],znUDS};
  znLDS_sync  <= {znLDS_sync[1:0],znLDS};
  znAS_sync   <= {znAS_sync[1:0],znAS};
  zREAD_sync  <= {zREAD_sync[1:0],zREAD};
  
  znDS1_sync  <= {znDS1_sync[1:0],znDS1};
  znDS0_sync  <= {znDS0_sync[1:0],znDS0};
  zDOE_sync   <= {zDOE_sync[0],zDOE};
  zE7M_sync   <= {zE7M_sync[3:0],zE7M};
  znRST_sync  <= {znRST_sync[0],znRST};
  znCFGIN_sync  <= {znCFGIN_sync[1:0],znCFGIN};
  znFCS_sync <= {znFCS_sync[1:0],znFCS};
  
  // unused signals ------------------------------------
  SD_DAT1_sync <= SD_DAT1;
  SD_DAT2_sync <= SD_DAT2;
  zFC0_sync <= zFC0;
  zFC1_sync <= zFC1;
  zFC2_sync <= zFC2;
  zSENSEZ3_sync <= zSENSEZ3;
  znBERR_sync <= znBERR;
  
  // Z2 ------------------------------------------------
  z2_addr_valid <= (znAS_sync[2]==0);
  
  data_in <= zD;
  zdata_in_sync <= data_in;
  
  need_row_fetch_y_latched <= need_row_fetch_y;
  
  zaddr <= {zA[22:0],1'b0};
  zaddr_sync  <= zaddr;
  zaddr_sync2 <= zaddr_sync;
  
  z2_mapped_addr <= ((zaddr_sync2-ram_low)>>1);
  z2_read  <= (zREAD_sync[0] == 1'b1);
  z2_write <= (zREAD_sync[0] == 1'b0);
  
  datastrobe_synced <= (znUDS_sync==0 || znLDS_sync==0);
  z2_uds <= (znUDS_sync==0);
  z2_lds <= (znLDS_sync==0);
  
  // CHECK
  zaddr_in_ram <= (zaddr_sync==zaddr_sync2 && zaddr_sync2>=ram_low && zaddr_sync2<ram_high);
  zaddr_in_reg <= (zaddr_sync==zaddr_sync2 && zaddr_sync2>=reg_low && zaddr_sync2<reg_high);
  if (znAS_sync[1]==0 && zaddr_sync2>=autoconf_low && zaddr_sync2<autoconf_high)
    zaddr_autoconfig <= 1'b1;
  else
    zaddr_autoconfig <= 1'b0;
  
  // Z3 ------------------------------------------------
  z3addr2 <= {zD[15:8],zA[22:1],2'b00};
  //z3addr2 <= {zD[15:8],zaddr[23:2],2'b00};
  
  // sample z3addr on falling edge of /FCS
  if (z3_fcs_state==0) begin
    if (znFCS_sync[0]==1 /*3'b111*/) begin
      z3_fcs_state <= 1;
      z3_end_cycle <= 1;
      z3addr <= 0; 
    end
  end else
  if (z3_fcs_state==1) begin
    if (znFCS_sync[0]==0 /*3'b000*/) begin // CHECK: if responding too quickly, this causes crashes
      z3_fcs_state <= 0;
      z3_end_cycle <= 0;
      z3addr <= z3addr2;
      zorro_read  <= zREAD_sync[1];
      zorro_write  <= ~zREAD_sync[1];
    end
  end
  
  if (z3_fcs_state==0) begin
    z3addr_in_ram <= (z3addr >= z3_ram_low) && (z3addr < z3_ram_high);
    z3addr_in_reg <= (z3addr >= z3_reg_low) && (z3addr < z3_reg_high);
  end else begin
    z3addr_in_ram <= 0;
    z3addr_in_reg <= 0;
  end
  
  z3addr_autoconfig <= (z3addr[31:16]=='hff00);
  
  z3_mapped_addr <= (z3addr-z3_ram_low)>>1;
  data_in_z3_low16 <= zaddr[23:8]; //zA[22:7]; // FIXME why sample this twice?
  
  //if (znUDS_sync==3'b000 || znLDS_sync==3'b000 || znDS1_sync==3'b000 || znDS0_sync==3'b000)
  if (znUDS_sync[1]==0 || znLDS_sync[1]==0 || znDS1_sync[1]==0 || znDS0_sync[1]==0)
    z3_din_latch <= 1;
  else
    z3_din_latch <= 0;

  //z3_end_cycle <= (z3_fcs_state==1); //(znFCS_sync[0]==1); //(znFCS_sync==3'b111);
  
  // pipelined for better timing
  if (z3_din_latch) begin
    z3_din_high_s2 <= data_in; //zD;
    z3_din_low_s2  <= data_in_z3_low16; //zA[22:7];
  end
  
  // pipelined for better timing
  data_z3_hi16_latched <= data_z3_hi16;
  data_z3_low16_latched <= data_z3_low16;
  dataout_z3_latched <= dataout_z3;
  dtack_latched <= dtack;
  
  // RESET, CONFIG
  z_reset <= (znRST_sync==3'b000);
  z_cfgin <= (znCFGIN_sync==3'b000);
  z_cfgin_lo <= (znCFGIN_sync==3'b111);
  
  // SD sync
  sd_handshake_out_sync <= sd_handshake_out;
  sd_data_out_sync <= sd_data_out;
  sd_busy_sync <= sd_busy;
  sd_error_sync <= sd_error;
end

// ram arbiter
reg zorro_ram_read_request = 0;
reg zorro_ram_read_done = 1;
reg zorro_ram_write_request = 0;
reg zorro_ram_write_done = 1;
reg [23:0] zorro_ram_read_addr;
reg [15:0] zorro_ram_read_data;
reg [1:0] zorro_ram_read_bytes;
reg [23:0] zorro_ram_write_addr;
reg [15:0] zorro_ram_write_data;
reg [1:0] zorro_ram_write_bytes;

reg [5:0] ram_arbiter_state = 0;

parameter RAM_READY = 0;
parameter RAM_READY2 = 1;
parameter RAM_FETCHING_ROW8 = 2;
parameter RAM_ROW_FETCHED = 3;
parameter RAM_READING_ZORRO_PRE = 4;
parameter RAM_WRITING_ZORRO = 5;
parameter RAM_BURST_OFF = 6;
parameter RAM_BURST_OFF2 = 7;
parameter RAM_BURST_ON = 8;
parameter RAM_BLIT_WRITE = 9;
parameter RAM_REFRESH = 10;
parameter RAM_READING_ZORRO = 11;
parameter RAM_REFRESH_PRE = 12;
parameter RAM_WRITING_ZORRO_PRE = 13;
parameter RAM_BLIT_COPY_READ = 14;
parameter RAM_BLIT_COPY_WRITE = 15;
parameter RAM_WRITE_END1 = 16;
parameter RAM_WRITE_END = 17;

reg [11:0] need_row_fetch_y = 0;
reg [11:0] need_row_fetch_y_latched = 0;
reg [11:0] fetch_line_y = 0;
reg [2:0] linescalecount = 0;

reg blitter_dirx = 0;
reg blitter_diry = 0;

reg [4:0] dtack_time = 0;
reg [5:0] dvid_reset_counter = 0;
reg z2_addr_valid = 0;
reg z3_end_cycle = 0;

// =================================================================================
// ZORRO MACHINE

reg [31:0] trace_1 = 0;
reg [31:0] trace_2 = 0;
reg [31:0] trace_3 = 0;
reg [15:0] trace_4 = 0;
reg [31:0] trace_5 = 0;
reg [31:0] trace_6 = 0;
reg [15:0] trace_7 = 0;
reg [15:0] trace_8 = 0;
reg [15:0] trace_9 = 0;
reg [7:0] write_counter = 0;

reg z3_ds3=0;
reg z3_ds2=0;
reg z3_ds1=0;
reg z3_ds0=0;

reg [1:0] zorro_write_capture_bytes = 0;
reg [15:0] zorro_write_capture_data = 0;

reg [15:0] default_data = 'hffff; // causes read/write glitches on A2000 (data bus interference) when 0

reg [31:0] coldstart_counter = 0;

always @(posedge z_sample_clk) begin

  screen_w_with_margin <= (screen_w+margin_x);
  if (dcm7_psen==1'b1) dcm7_psen <= 1'b0;
  if (dcm7_rst==1'b1) dcm7_rst <= 1'b0;

`ifdef ANALYZER
  if (rec_enable) begin
    if (rec_idx==(ANSIZE*4)) begin
      rec_enable <= 0;
      rec_idx <= 0;
    end else begin
      rec_idx <= rec_idx+1;
      rec_zreadraw[rec_idx>>2] <= !znAS_sync[0]; // zREAD;
      rec_zread[rec_idx>>2] <= z2_read;
      rec_zwrite[rec_idx>>2] <= z2_write;
      rec_zas0[rec_idx>>2] <= !znLDS_sync[0]; //znAS_sync[0];
      rec_zas1[rec_idx>>2] <= !znUDS_sync[0]; //znAS_sync[1];
      rec_zaddr_in_ram[rec_idx>>2] <= zorro_ram_read_request; //z3addr_in_ram;
      rec_state[rec_idx>>2] <= zorro_ram_write_request;
      rec_statew[rec_idx>>2] <= ((zorro_state==WAIT_WRITE2)||(zorro_state==WAIT_WRITE)||(zorro_state==Z2_WRITE_FINALIZE))?1'b1:1'b0;
      rec_ready[rec_idx>>2] <= ((zorro_state==WAIT_READ2)||(zorro_state==WAIT_READ3))?1'b1:1'b0;
      rec_endcycle[rec_idx>>2] <= ((zorro_state==Z2_ENDCYCLE))?1'b1:1'b0;
      ///rec_zaddr[rec_idx] <= zaddr;
    end
  end
`endif

  if (zorro_state!=COLD && (z_cfgin_lo || z_reset)) begin
    zorro_state <= RESET;
  end else
  case (zorro_state)
    COLD: begin
      zorro_state <= RESET;
    end

    RESET: begin
      vga_clk_sel  <= 1;
      refresh_counter <= 0;
      refresh_max <= 'h1000;
      
      // new default mode is 640x480 wrapped in 800x600@60hz
      screen_w     <= videocap_default_w;
      h_rez        <= videocap_default_w;
      h_sync_start <= 832;
      h_sync_end   <= 896;
      h_max        <= 1048;
      
      screen_h     <= videocap_default_h;
      v_rez        <= videocap_default_h;
      v_sync_start <= 601;
      v_sync_end   <= 604;
      v_max        <= 631;
      
      row_pitch    <= 1024;
      row_pitch_shift <= 10;
      
      safe_x1 <= 0;
      safe_x2 <= 'h220;
      fetch_preroll <= 1;
      
      videocap_mode <= 0;
      dvid_reset <= 1;
      aligned_row_mode <= 1;
      
      scalemode_h <= 0;
      scalemode_v <= 0; //1;
      colormode <= 1;
      blitter_colormode <= 1;
      
      blitter_base <= 'hf80000; //+(videocap_voffset<<10); // capture vertical offset
      pan_ptr <= 'hf80000; //+(videocap_voffset<<10); // capture vertical offset
      margin_x <= 10;
      fetch_preroll <= 1;
      
      blitter_x1 <= 0;
      blitter_y1 <= 0; 
      blitter_x2 <= 4094; // FIXME crashes with 4095
      blitter_y2 <= 4095;
      blitter_ptr <= 0;
      blitter_rgb <= 0;
      blitter_row_pitch <= 4096;
      blitter_row_pitch_shift <= 12;
      blitter_enable <= 0;
      
      ram_low   <= 'h600000;
      ram_high  <= 'h600000 + ram_size-4;
      reg_low   <= 'h600000 + ram_size;
      reg_high  <= 'h600000 + ram_size + reg_size;
      
      sdram_reset <= 1;
      dataout_enable <= 0;
      dataout <= 0;
      slaven <= 0;
      zorro_ram_read_done <= 1;
      z_ovr <= 0;
      z_confout <= 0;
      z3_confdone <= 0;
      
      sd_reset <= 1;

      zorro_state <= DECIDE_Z2_Z3;
    end
    
    DECIDE_Z2_Z3: begin
      // poor man's z3sense
      /*if (zaddr_autoconfig) begin
        sd_reset <= 0;
        ZORRO3 <= 0;
        zorro_state <= Z2_CONFIGURING;
      end else*/ if (z3addr_autoconfig) begin
        sd_reset <= 0;
        ZORRO3 <= 1;
        zorro_state <= Z3_CONFIGURING;
      end
    end
    
    Z3_CONFIGURING: begin
      if (z_cfgin && z3addr_autoconfig && /*z3_fcs_state==0*/ znFCS_sync[2]==0) begin
        if (zorro_read) begin
          // autoconfig ROM
          dataout_enable <= 1;
          dataout_z3 <= 1;
          data_z3_low16 <= 'hffff;
          slaven <= 1;
          dtack_time <= 0;
          zorro_state <= Z3_DTACK;
          
          case (z3addr[15:0])
            'h0000: data_z3_hi16 <= 'b1001_1111_1111_1111; // zorro 3 (10), no pool link (0), autoboot ROM (1)
            'h0100: data_z3_hi16 <= 'b0001_1111_1111_1111; // next board unrelated (0), 32mb
            
            'h0004: data_z3_hi16 <= 'b1111_1111_1111_1111; // product number
            'h0104: data_z3_hi16 <= 'b1110_1111_1111_1111; // (1)
            
            'h0008: data_z3_hi16 <= 'b0000_1111_1111_1111; // flags inverted 0111 io,shutup,extension,reserved(1)
            'h0108: data_z3_hi16 <= 'b1111_1111_1111_1111; // inverted zero
            
            'h000c: data_z3_hi16 <= 'b1111_1111_1111_1111; // reserved?
            'h010c: data_z3_hi16 <= 'b1111_1111_1111_1111; // 
            
            'h0010: data_z3_hi16 <= 'b1001_1111_1111_1111; // manufacturer high byte inverted
            'h0110: data_z3_hi16 <= 'b0010_1111_1111_1111; // 
            'h0014: data_z3_hi16 <= 'b1001_1111_1111_1111; // manufacturer low byte
            'h0114: data_z3_hi16 <= 'b0001_1111_1111_1111;
            
            'h0018: data_z3_hi16 <= 'b1111_1111_1111_1111; // serial 01 01 01 01
            'h0118: data_z3_hi16 <= 'b1110_1111_1111_1111; //
            'h001c: data_z3_hi16 <= 'b1111_1111_1111_1111; //
            'h011c: data_z3_hi16 <= 'b1110_1111_1111_1111; //
            'h0020: data_z3_hi16 <= 'b1111_1111_1111_1111; //
            'h0120: data_z3_hi16 <= 'b1110_1111_1111_1111; //
            'h0024: data_z3_hi16 <= 'b1111_1111_1111_1111; //
            'h0124: data_z3_hi16 <= 'b1110_1111_1111_1111; //
            
            'h0028: data_z3_hi16 <= 'b1111_1111_1111_1111; // autoboot rom vector (er_InitDiagVec)
            'h0128: data_z3_hi16 <= 'b1111_1111_1111_1111; // ff7f = ~0080
            'h002c: data_z3_hi16 <= 'b0111_1111_1111_1111;
            'h012c: data_z3_hi16 <= 'b1111_1111_1111_1111;
           
            default: data_z3_hi16 <= 'b1111_1111_1111_1111;
          endcase
        end else begin
          // write to autoconfig register
          slaven <= 1;
          if (((znUDS_sync[2]==0) || (znLDS_sync[2]==0))) begin
            dtack_time <= 0;
            zorro_state <= Z3_DTACK;
            casex (z3addr[15:0])
              'hXX44: begin
                z3_ram_low[31:16] <= data_in;
                z3_confdone <= 1;
              end
              'hXX48: begin
              end
              'hXX4c: begin
                // shutup
                z3_confdone <= 1;
              end
            endcase
          end
        end
      end else begin
        // no address match
        dataout_z3 <= 0;
        dataout_enable <= 0;
        slaven <= 0;
        dtack <= 0;
      end
    end
    
    Z3_DTACK: begin
      /*if (dtack_time < 2)
        dtack_time <= dtack_time + 1'b1;
      else*/ 
      if (z3_end_cycle) begin
        dtack <= 0;
        dataout_z3 <= 0;
        dataout_enable <= 0;
        slaven <= 0;
        dtack_time <= 0;
        if (z3_confdone) begin
          zorro_state <= CONFIGURED;
        end else
          zorro_state <= Z3_CONFIGURING;
      end else
        dtack <= 1;
    end
    
    Z2_CONFIGURING: begin
      // CHECK
      z_ovr <= 0;
      if (zaddr_autoconfig && z_cfgin) begin
        if (z2_read) begin
          // read iospace 'he80000 (Autoconfig ROM)
          dataout_enable <= 1;
          dataout <= 1;
          slaven <= 1;
          
          case (zaddr_sync2[7:0])
            8'h00: data <= 'b1101_1111_1111_1111; // zorro 2 (11), no pool (0) rom (1)
            8'h02: data <= 'b0111_1111_1111_1111; // next board unrelated (0), 4mb
            
            8'h04: data <= 'b1111_1111_1111_1111; // product number
            8'h06: data <= 'b1110_1111_1111_1111; // (1)
            
            8'h08: data <= 'b0011_1111_1111_1111; // flags inverted 0011
            8'h0a: data <= 'b1110_1111_1111_1111; // inverted 0001 = OS sized
            
            8'h10: data <= 'b1001_1111_1111_1111; // manufacturer high byte inverted (02)
            8'h12: data <= 'b0010_1111_1111_1111; // 
            8'h14: data <= 'b1001_1111_1111_1111; // manufacturer low byte (9a)
            8'h16: data <= 'b0001_1111_1111_1111;
            
            8'h18: data <= 'b1111_1111_1111_1111; // serial 01 01 01 01
            8'h1a: data <= 'b1110_1111_1111_1111; //
            8'h1c: data <= 'b1111_1111_1111_1111; //
            8'h1e: data <= 'b1110_1111_1111_1111; //
            8'h20: data <= 'b1111_1111_1111_1111; //
            8'h22: data <= 'b1110_1111_1111_1111; //
            8'h24: data <= 'b1111_1111_1111_1111; //
            8'h26: data <= 'b1110_1111_1111_1111; //
            
            8'h28: data <= 'b1111_1111_1111_1111; // autoboot rom vector (er_InitDiagVec)
            8'h2a: data <= 'b1111_1111_1111_1111; // ff7f = ~0080
            8'h2c: data <= 'b0111_1111_1111_1111;
            8'h2e: data <= 'b1111_1111_1111_1111;
            
            //'h000040: data <= 'b0000_0000_0000_0000; // interrupts (not inverted)
            //'h000042: data <= 'b0000_0000_0000_0000; //
           
            default: data <= 'b1111_1111_1111_1111;
          endcase
        end else begin
          // write to autoconfig register
          if (datastrobe_synced) begin
            case (zaddr_sync2[7:0])
              8'h48: begin
                ram_low[31:24] <= 8'h0;
                ram_low[23:20] <= zdata_in_sync[15:12];
                ram_low[15:0] <= 16'h0;
                zorro_state <= Z2_PRE_CONFIGURED; // configured
              end
              8'h4a: begin
                ram_low[31:24] <= 8'h0;
                ram_low[19:16] <= zdata_in_sync[15:12];
                ram_low[15:0] <= 16'h0;
              end
              
              8'h4c: begin 
                zorro_state <= Z2_PRE_CONFIGURED; // configured, shut up
              end
            endcase
          end
        end
      end else begin
        // no address match
        dataout <= 0;
        dataout_enable <= 0;
        slaven <= 0;
      end
    end
    
    Z2_PRE_CONFIGURED: begin
      if (znAS_sync[2]==1) begin
        z_confout<=1;
        zorro_state <= CONFIGURED;
      end
    end
    
    CONFIGURED: begin
      ram_low <= ram_low + 'h10000;
      ram_high <= ram_low + ram_size;
      reg_low <= ram_low;
      reg_high <= ram_low + reg_size;
      
      z3_ram_low   <= z3_ram_low + 'h10000;
      z3_ram_high  <= z3_ram_low + z3_ram_size;
      z3_reg_low   <= z3_ram_low;
      z3_reg_high  <= z3_ram_low + reg_size;
      
      z_confout <= 1;
      refresh_max <= 'h100;
      
      sdram_reset <= 0;
      blitter_enable <= 1;
      
      zorro_state <= CONFIGURED_CLEAR;
    end
    
    CONFIGURED_CLEAR: begin
      //videocap_mode <= 1;
      if (ZORRO3) begin
        zorro_state <= Z3_IDLE;
      end else begin
        zorro_state <= Z2_IDLE;
      end
    end
  
    // ----------------------------------------------------------------------------------
    Z2_IDLE: begin
      if (dvid_reset) begin
        dvid_reset_counter <= 2;
        zorro_state <= RESET_DVID;
      end else
      if (z2_addr_valid) begin
        `ifdef ANALYZER
          if (!rec_enable && zaddr_in_ram) begin 
            rec_enable <= 1;
            rec_idx <= 0;
          end
        `endif
      
        if (z2_read && zaddr_in_ram) begin
          // read RAM
          // request ram access from arbiter
          last_addr <= z2_mapped_addr;
          data <= default_data; //'hffff;
          read_counter <= 0;
          slaven <= 1;
          dataout_enable <= 1;
          dataout <= 1;
          z_ovr <= 1;
          zorro_state <= WAIT_READ3;
          
        end else if (z2_write && zaddr_in_ram) begin
          // write RAM
          last_addr <= z2_mapped_addr;
          dataout_enable <= 0;
          dataout <= 0;
          datain_counter <= 0;
          z_ovr <= 1;
          zorro_state <= WAIT_WRITE;
          
        end else if (z2_write && zaddr_in_reg) begin
          // write to register
          dataout_enable <= 0;
          dataout <= 0;
          z_ovr <= 1;
          zaddr_regpart <= zaddr_sync2[15:0];
          zorro_state <= Z2_REGWRITE;
          
        end else if (z2_read && zaddr_in_reg) begin
          // read from registers
          dataout_enable <= 1;
          dataout <= 1;
          data <= default_data; //'hffff;
          slaven <= 1;
          z_ovr <= 1;
          zaddr_regpart <= zaddr_sync2[15:0];
          zorro_state <= Z2_REGREAD;
          
        end else begin
          dataout <= 0;
          dataout_enable <= 0;
          slaven <= 0;
          write_stall <= 0;
        end
          
      end else begin
        dataout <= 0;
        dataout_enable <= 0;
        slaven <= 0;
        write_stall <= 0;
      end
    end
    
    Z2_REGWRITE: begin
      if (datastrobe_synced) begin
        regdata_in <= zdata_in_sync;
        regwrite_addr <= zaddr_regpart;
        zorro_state <= REGWRITE;
      end
    end
    
    // ----------------------------------------------------------------------------------
    WAIT_READ3: begin
      //if (!zorro_ram_read_request) begin
        zorro_ram_read_addr <= last_addr;
        zorro_ram_read_request <= 1;
        zorro_ram_read_done <= 0;
        zorro_state <= WAIT_READ2;
      //end
    end
    
    WAIT_READ2: begin
      if (zorro_ram_read_done) begin
        read_counter <= read_counter + 1;
        data <= zorro_ram_read_data;
        
        if (read_counter >= dataout_time) begin
          zorro_state <= Z2_ENDCYCLE;
        end
      end
    end
  
    WAIT_WRITE: begin
      if (!zorro_ram_write_request) begin
        if (datastrobe_synced) begin
          zorro_write_capture_bytes <= {~znUDS_sync[1],~znLDS_sync[1]};
          zorro_write_capture_data <= data_in; //_sync;
          zorro_state <= WAIT_WRITE2;
        end
      end
    end
    
    WAIT_WRITE2: begin
      zorro_ram_write_addr <= last_addr;
      zorro_ram_write_bytes <= zorro_write_capture_bytes;
      zorro_ram_write_data <= zorro_write_capture_data;
      zorro_ram_write_request <= 1;
      zorro_state <= Z2_WRITE_FINALIZE;
    end
    
    Z2_WRITE_FINALIZE: begin
      if (!zorro_ram_write_request) begin
        zorro_state <= Z2_ENDCYCLE;
      end
    end
    
    Z2_ENDCYCLE: begin
      if (!z2_addr_valid) begin
        dtack <= 0;
        slaven <= 0;
        dataout_enable <= 0;
        dataout <= 0;
        z_ovr <= 0;
        zorro_state <= Z2_IDLE;
      end else
        dtack <= 1;
    end
    
    // ----------------------------------------------------------------------------------
    
    RESET_DVID: begin
      if (dvid_reset_counter==0) begin
        dvid_reset <= 0;
        if (ZORRO3)
          zorro_state <= Z3_IDLE;
        else
          zorro_state <= Z2_IDLE;
      end else
        dvid_reset_counter <= dvid_reset_counter - 1'b1;
    end
    
    // ----------------------------------------------------------------------------------
    // ----------------------------------------------------------------------------------
    Z3_IDLE: begin
      if (dvid_reset) begin
        dvid_reset_counter <= 2;
        zorro_state <= RESET_DVID;
      end else
      if (z3_fcs_state==0) begin
        // falling edge of /FCS
        
        `ifdef ANALYZER
          if (!rec_enable && z3addr_in_ram) begin 
            rec_enable <= 1;
            rec_idx <= 0;
          end
        `endif
         
        if (z3addr_in_ram && zorro_write) begin
          slaven <= 1;
          dataout_enable <= 0;
          dataout_z3 <= 0;
          read_counter <= 0;
          
          if ((znUDS_sync[2]==0) || (znLDS_sync[2]==0) || (znDS1_sync[2]==0) || (znDS0_sync[2]==0)) begin
            zorro_state <= Z3_WRITE_PRE;
          end
        end else if (z3addr_in_ram && zorro_read) begin
          // read from memory
          slaven <= 1;
          data_z3_hi16 <= default_data;
          data_z3_low16 <= default_data;
          dataout_z3 <= 1;
      
          zorro_state <= Z3_READ_UPPER;
        end else if (zorro_write && z3addr_in_reg) begin
          // FIXME doesn't support 32 bit access
          // write to register
          slaven <= 1;
          if (znDS1_sync[2]==0) begin
            regdata_in <= data_in_z3_low16;
            z3addr_regpart <= (z3addr[15:0])|16'h2;
            zorro_state <= Z3_REGWRITE;
          end else if (znUDS_sync[2]==0) begin
            regdata_in <= zdata_in_sync;
            z3addr_regpart <= z3addr[15:0];
            zorro_state <= Z3_REGWRITE;
          end
        end else if (zorro_read && z3addr_in_reg) begin
          // read registers
          slaven <= 1;
          dataout_z3 <= 1;
          data_z3_hi16 <= default_data;
          data_z3_low16 <= default_data;
          
          if (znDS1_sync[2]==0 || znDS0_sync[2]==0 || znUDS_sync[2]==0 || znLDS_sync[2]==0) begin
            z3addr_regpart <= z3addr[15:0]; //|16'h2;
            zorro_state <= Z3_REGREAD;
          end
        end else begin
          // address not recognized
          slaven <= 0;
          dtack <= 0;
          dataout_enable <= 0;
          dataout_z3 <= 0;
        end
        
      end else begin
        // not in a cycle
        slaven <= 0;
        dtack <= 0;
        dataout_enable <= 0;
        dataout_z3 <= 0;
      end
    end
    
    Z3_READ_UPPER: begin
      dataout_enable <= 1;
      
      if (!zorro_ram_read_request) begin
        z3_read_addr <= z3_mapped_addr;
        zorro_state <= Z3_READ_LOWER;
        zorro_ram_read_addr <= z3_mapped_addr[23:0];
        zorro_ram_read_bytes <= 2'b11;
        zorro_ram_read_request <= 1;
        zorro_ram_read_done <= 0;
      end
    end
    
    Z3_READ_LOWER: begin
      if (!zorro_ram_read_request) begin
        zorro_ram_read_addr <= {z3_read_addr[23:1],1'b1};
        zorro_ram_read_bytes <= 2'b11;
        zorro_ram_read_request <= 1;
        zorro_ram_read_done <= 0;
        z3_read_data <= zorro_ram_read_data;
        zorro_state <= Z3_READ_DELAY1;
      end
    end
    
    Z3_READ_DELAY1: begin
      if (!zorro_ram_read_request) begin
        data_z3_hi16 <= z3_read_data;
        data_z3_low16 <= zorro_ram_read_data;
        read_counter <= 0;
        zorro_state <= Z3_READ_DELAY2; // CHECK DELAY
      end
    end
    
    Z3_READ_DELAY2: begin
      if (read_counter >= dataout_time)
        zorro_state <= Z3_ENDCYCLE;
      else
        read_counter <= read_counter+1'b1;
    end
    
    Z3_WRITE_PRE: begin
      z3_ds0<=~znDS0_sync[2];
      z3_ds1<=~znDS1_sync[2];
      z3_ds2<=~znLDS_sync[2];
      z3_ds3<=~znUDS_sync[2];
      zorro_state<=Z3_WRITE_UPPER;
    end
    
    Z3_WRITE_UPPER: begin
      // wait for free memory bus
      if (z3_ds3 || z3_ds2) begin
        if (!zorro_ram_write_request) begin
          zorro_ram_write_addr <= z3_mapped_addr[23:0];
          zorro_ram_write_bytes <= {z3_ds3,z3_ds2};
          zorro_ram_write_data <= z3_din_high_s2;
          zorro_ram_write_request <= 1;
          
          zorro_state <= Z3_WRITE_LOWER;
        end
      end else begin
        // only lower bytes shall be written
        zorro_state <= Z3_WRITE_LOWER;
      end
    end
    
    Z3_WRITE_LOWER: begin
      if (z3_ds1 || z3_ds0) begin
        if (!zorro_ram_write_request) begin
          zorro_ram_write_addr <= (z3_mapped_addr[23:0])|1'b1;
          zorro_ram_write_bytes <= {z3_ds1,z3_ds0};
          zorro_ram_write_data <= z3_din_low_s2;
          zorro_ram_write_request <= 1;
      
`ifdef TRACE    
          trace_1 <= trace_1 + 1'b1;
          trace_2 <= (z3_mapped_addr[23:0])|1'b1;
          trace_3 <= z3_din_low_s2;
          trace_4 <= {z3_ds1,z3_ds0};
`endif

          zorro_state <= Z3_WRITE_FINALIZE;
        end
      end else begin
        
        zorro_state <= Z3_WRITE_FINALIZE;
      end
    end
    
    Z3_WRITE_FINALIZE: begin
      if (!zorro_ram_write_request) begin
        zorro_state <= Z3_ENDCYCLE;
        dtack <= 1;
      end
    end
    
    Z3_ENDCYCLE: begin
      if (z3_end_cycle) begin
        dtack <= 0;
        slaven <= 0;
        dataout_enable <= 0;
        dataout_z3 <= 0;
        zorro_state <= Z3_IDLE;
      end else
        dtack <= 1;
    end
    
    // 32bit reg read
    Z3_REGREAD_POST: begin
      data_z3_hi16  <= rr_data[31:16];
      data_z3_low16 <= rr_data[15:0];
      dataout_enable <= 1;
      zorro_state <= Z3_READ_DELAY2;
      read_counter <= 0;
    end
    
    // 16bit reg read
    Z2_REGREAD_POST: begin
      if (zaddr_regpart[1]==1'b1)
        data <= rr_data[15:0];
      else
        data <= rr_data[31:16];
      zorro_state <= Z2_ENDCYCLE;
    end
    
    // relaxing the data pipeline a bit
    Z2_REGREAD: begin
      regread_addr <= zaddr_regpart;
      zorro_state <= REGREAD;
    end

    Z3_REGREAD: begin
      regread_addr <= z3addr_regpart;
      zorro_state <= REGREAD;
    end

    // FIXME why is there no dataout time on REGREAD? (see memory reads)
    // now fixed for Z3, still pending for Z2
    REGREAD: begin
      if (ZORRO3) begin
        zorro_state <= Z3_REGREAD_POST;
      end else begin
        zorro_state <= Z2_REGREAD_POST;
      end
      case (regread_addr&'hffc)
        // burden on timing
        /*'h4c: begin
              rr_data[31:16] <= 16'h0000;
              rr_data[15:0]  <= videocap_mode; end // 'h4e */
        'h28: begin
              rr_data[31:16] <= 16'h0000;
              rr_data[15:0]  <= blitter_enable; end // 'h2a
        'h54: begin 
              rr_data[31:16] <= videocap_default_w;
              rr_data[15:0]  <= videocap_default_h; end // 'h56
        'h58: begin
              rr_data[31:16] <= videocap_ymax;
              rr_data[15:0] <= 16'h0000; end
        'h60: begin 
              rr_data[31:16] <= {sd_busy_sync,8'h00};
              rr_data[15:0]  <= sd_read; end // 'h62
        'h64: begin 
              rr_data[31:16] <= sd_write;
              rr_data[15:0]  <= {sd_handshake_out_sync,8'h00}; end // 'h66
        'h68: begin 
              rr_data[31:16] <= sd_addr_in[31:16];
              rr_data[15:0]  <= sd_addr_in[15:0]; end // 'h6a
        'h6c: begin 
              rr_data[31:16] <= 16'h0000;
              rr_data[15:0]  <= {sd_data_out_sync,8'h00}; end // 'h6e
        'h70: begin 
              rr_data[31:16] <= sd_error_sync; 
              rr_data[15:0]  <= sd_state; end
              
        // Autoboot ROM
        // See http://amigadev.elowar.com/read/ADCD_2.1/Libraries_Manual_guide/node041C.html
        'h80: rr_data <= 'h9000_00d8; // WORDWIDE+CONFIGTIME  DAsize
        'h84: rr_data <= 'h0036_00b8; // DiagPt: 0xb6         BootPt
        'h88: rr_data <= 'h0028_0000; // DevName pointer      Res
        'h8c: rr_data <= 'h0000_4afc; // Res, ROMTAG
        'h90: rr_data <= 'h0000_000e; // Backptr
        'h94: rr_data <= 'h0000_0088; // 
        'h98: rr_data <= 'h0101_0314; // Coldstart, Version      NT_DEVICE, Priority $14
        'h9c: rr_data <= 'h0000_0028; // DevName pointer
        'ha0: rr_data <= 'h0000_0028; // IDString pointer
        'ha4: rr_data <= 'h0000_0116; // InitEntry pointer (???)
        'ha8: rr_data <= 'h6d6e_7473; // DevName mntsd.device
        'hac: rr_data <= 'h642e_6465; // -- DevName
        'hb0: rr_data <= 'h7669_6365; // -- DevName
        
        'hb4: rr_data <= 'h0000_4a68; // DiagEntry@b6
        'hb8: rr_data <= 'h0060_6700; // tstw $60(a0)  beq start
        'hbc: rr_data <= 'h0014_7000; // fail
        'hc0: rr_data <= 'h317c_0001; // enable videocap
        'hc4: rr_data <= 'h004e_317c; // reset SD ctrl
        'hc8: rr_data <= 'h0001_0060;
        'hcc: rr_data <= 'h4e71_4e75; // nop, rts
        'hd0: rr_data <= 'h7000_2848; // start, moveq #0,d0
        'hd4: rr_data <= 'hd9fc_0001;
        'hd8: rr_data <= 'h0000_317c;
        'hdc: rr_data <= 'h0000_0068;
        'he0: rr_data <= 'h223c_0000;
        'he4: rr_data <= 'h0201_3140; // read
        'he8: rr_data <= 'h006a_317c;
        'hec: rr_data <= 'hffff_0062;
        'hf0: rr_data <= 'h4a68_0060; // blockloop
        'hf4: rr_data <= 'h6700_fffa;
        'hf8: rr_data <= 'h4a68_0066; // shakea
        'hfc: rr_data <= 'h6700_fffa;
        'h100: rr_data <= 'h1428_006e;
        'h104: rr_data <= 'h18c2_317c;
        'h108: rr_data <= 'hffff_0066;
        'h10c: rr_data <= 'h4a68_0066; // shakeb
        'h110: rr_data <= 'h6600_fffa;
        'h114: rr_data <= 'h317c_0000;
        'h118: rr_data <= 'h0066_51c9;
        'h11c: rr_data <= 'hffd4_2848; // moveal %a0,%a4
        'h120: rr_data <= 'hd9fc_0001; // addal #0x10020,%a4
        'h124: rr_data <= 'h0020_0c54; // check for jump op
        'h128: rr_data <= 'h4efa_6600; // bne bail
        'h12c: rr_data <= 'h0004_4ed4; // jmp %a4@
        'h130: rr_data <= 'h317c_0001; // enable videocap
        'h134: rr_data <= 'h004e_4e75; // rts
        
        // BootEntry, init dos.library
        'h138: rr_data <= 'h43fa_0010;
        'h13c: rr_data <= 'h4eae_ffa0;
        'h140: rr_data <= 'h2040_2068;
        'h144: rr_data <= 'h0016_4e90;
        'h148: rr_data <= 'h4e75_646f; // rts, "dos.library\0"
        'h14c: rr_data <= 'h732e_6c69;
        'h150: rr_data <= 'h6272_6172;
        'h154: rr_data <= 'h7900_0000;
        
        default: begin
          rr_data[31:16] <= REVISION;
          rr_data[15:0]  <= REVISION;
        end
      endcase
    end
    
    Z3_REGWRITE: begin
      regwrite_addr <= z3addr_regpart;
      zorro_state <= REGWRITE;
    end

    REGWRITE: begin
      if (ZORRO3) begin
        zorro_state <= Z3_ENDCYCLE;
      end else
        zorro_state <= Z2_ENDCYCLE;
      
      if (regwrite_addr>='h600) begin
        palette_r[regwrite_addr[8:1]] <= regdata_in[7:0];
      end else if (regwrite_addr>='h400) begin
        palette_g[regwrite_addr[8:1]] <= regdata_in[7:0];
      end else if (regwrite_addr>='h200) begin
        palette_b[regwrite_addr[8:1]] <= regdata_in[7:0];
      end else
      case (regwrite_addr)
        'h02: screen_w <= regdata_in[11:0];
        'h04: begin
          scalemode_h <= regdata_in[1:0];
          scalemode_v <= regdata_in[3:2];
        end
        'h06: begin
          screen_w <= regdata_in[11:0];
          h_rez    <= regdata_in[11:0];
        end
        'h08: begin
          screen_h <= regdata_in[11:0];
          v_rez    <= regdata_in[11:0];
        end
        
        'h0a: begin
          refresh_max[23:8] <= regdata_in[15:0];
          refresh_counter <= 0;
        end
        
        'h0c: margin_x <= regdata_in[9:0];
        'h0e: colormode <= regdata_in[2:0];
        
        'h10: safe_x1 <= regdata_in[10:0];
        //'h12: fetch_w <= regdata_in[15:0];
        'h14: safe_x2 <= regdata_in[10:0];
        'h1a: fetch_preroll <= regdata_in[15:0];
        
        // blitter regs
        'h1c: blitter_row_pitch <= regdata_in;
        'h1e: blitter_colormode <= regdata_in[2:0];
        
        'h20: blitter_x1 <= regdata_in[15:0];
        'h22: blitter_y1 <= regdata_in[15:0];
        'h24: blitter_x2 <= regdata_in[15:0];
        'h26: blitter_y2 <= regdata_in[15:0];
        'h28: blitter_rgb <= regdata_in[15:0];
        'h2a: begin
          blitter_enable <= regdata_in[3:0];
          
          blitter_curx <= blitter_x1;
          blitter_cury <= blitter_y1;
          blitter_curx2 <= blitter_x3;
          blitter_cury2 <= blitter_y3;
          
          blitter_dirx <= (blitter_x3>blitter_x4)?1'b1:1'b0;
          blitter_diry <= (blitter_y3>blitter_y4)?1'b1:1'b0;
          
          blitter_ptr  <= blitter_base;
          blitter_ptr2 <= blitter_base2;
          //blitter_ptr  <= blitter_base + (blitter_y1 * blitter_row_pitch);
          //blitter_ptr2 <= blitter_base + (blitter_y3 * blitter_row_pitch);
          blitter_rgb32_t <= 0;
        end
        'h2c: blitter_x3 <= regdata_in[11:0];
        'h2e: blitter_y3 <= regdata_in[11:0];
        'h30: blitter_x4 <= regdata_in[11:0];
        'h32: blitter_y4 <= regdata_in[11:0];
        'h34: blitter_rgb32[0] <= regdata_in[15:0];
        'h36: blitter_rgb32[1] <= regdata_in[15:0];
        
        'h38: pan_ptr[23:16] <= regdata_in[7:0];
        'h3a: pan_ptr[15:0]  <= regdata_in;
        
        'h3c: videocap_prex <= regdata_in[9:0];
        'h3e: videocap_voffset <= regdata_in[9:0];
        
        'h40: blitter_base[23:16] <= regdata_in[7:0];
        'h42: blitter_base[15:0]  <= regdata_in;
        'h44: blitter_base2[23:16] <= regdata_in[7:0];
        'h46: blitter_base2[15:0] <= regdata_in;
        
        'h4a: begin
          dcm7_psincdec <= regdata_in[0];
          dcm7_psen <= 1'b1;
        end
        'h4c: dcm7_rst <= 1'b1;
        
        'h4e: begin
          videocap_mode <= regdata_in[0];
          aligned_row_mode <= regdata_in[0];
        end
        //'h50: videocap_width <= regdata_in[9:0];
        //'h52: videocap_height <= regdata_in[9:0];
        //'h54: videocap_default_w <= regdata_in[9:0];
        //'h56: videocap_default_h <= regdata_in[9:0];
        
        
        'h58: row_pitch <= regdata_in;
        'h5c: row_pitch_shift <= regdata_in[4:0];
        
        
        // sd card regs
        'h60: sd_reset <= regdata_in[8];
        'h62: sd_read <= regdata_in[8];
        'h64: sd_write <= regdata_in[8];
        'h66: sd_handshake_in <= regdata_in[8];
        'h68: sd_addr_in[31:16] <= regdata_in[15:0];
        'h6a: sd_addr_in[15:0] <= regdata_in[15:0];
        'h6c: sd_data_in <= regdata_in[15:8];
        
        'h70: h_sync_start <= regdata_in[11:0];
        'h72: h_sync_end <= regdata_in[11:0];
        'h74: h_max <= regdata_in[11:0];
        'h76: v_sync_start <= regdata_in[11:0];
        'h78: v_sync_end <= regdata_in[11:0];
        'h7a: v_max <= regdata_in[11:0];
        'h7c: begin
          vga_clk_sel <= regdata_in[1:0];
          dvid_reset <= 1;
        end
      
      endcase
    end
    
    default:
      // shouldn't happen
      zorro_state <= CONFIGURED;

  endcase

// =================================================================================
// RAM ARBITER

  if (videocap_y2>=videocap_voffset2)
    videocap_y3 <= videocap_y2-videocap_voffset2;
  else
    videocap_y3 <= 0;
  
  x_safe_area_sync <= {x_safe_area_sync[0], x_safe_area};

  if (videocap_mode /*&& blitter_enable==0*/) begin
    if (videocap_y3<videocap_height 
        && videocap_line_saved_y!=videocap_y3 
        && videocap_line_saved==1) begin
      videocap_line_saved <= 0;
      videocap_line_saved_y <= videocap_y3;
      videocap_save_base <= 'h00f80000 + ((videocap_y2-videocap_voffset2)<<10);
      //videocap_save_base <= 'h00f80000 + ((videocap_y2-videocap_voffset2)*640);
      videocap_save_x <= 0;
      videocap_save_x2 <= 0;
    end
  end
  
  case (ram_arbiter_state)
    RAM_READY: begin
      ram_enable <= 0;
      ram_arbiter_state <= RAM_READY2;
      fetch_y <= pan_ptr + (fetch_line_y*fetch_w); // 512
      //fetch_y <= pan_ptr + (fetch_line_y * row_pitch);
    end
    
    RAM_READY2: begin
      if (row_fetched) begin
        ram_enable <= 0;
        ram_burst <= 0;
        // 2-word burst for faster videocap
        ram_write_burst <= videocap_mode && (blitter_enable==0);
        if (data_out_queue_empty)
          ram_arbiter_state <= RAM_BURST_OFF;
      end else begin
        // start fetching a row
        ram_enable <= 0;
        ram_burst <= 1;
        ram_arbiter_state <= RAM_BURST_ON;
        
        fetch_x <= 0;
      end
    end
    
    RAM_BURST_ON: begin
      if (cmd_ready) begin
        ram_arbiter_state <= RAM_FETCHING_ROW8;
        
        ram_addr  <= fetch_y+glitchx2_reg;
        ram_write <= 0;
        ram_byte_enable <= 'b11;
        // move src
      end
    end
    
    RAM_FETCHING_ROW8: begin
      if ((fetch_x >= (fetch_w+margin_x))              /* 654 */
          || (aligned_row_mode==1 && fetch_x >= (screen_w+margin_x))) begin
        row_fetched <= 1; // row completely fetched
        ram_enable <= 0;
        ram_arbiter_state <= RAM_READY;
        
      end else if (data_out_ready) begin
        ram_addr  <= ram_addr + 1'b1; // burst incremented
        fetch_x <= fetch_x + 1'b1;
        fetch_buffer[fetch_x-margin_x] <= ram_data_out;
        ram_enable <= 1; // move dst
      end else
        ram_enable <= 1; // move dst
    end
    
    RAM_BURST_OFF: begin
      // this solves the problem of first write/read lost
      // after burst disable
      if (cmd_ready) begin
        ram_enable <= 1;
        ram_write <= 0;
        // homebrew ram refresh
        ram_addr <= refresh_addr;
        refresh_addr <= refresh_addr + 512;
        
        ram_arbiter_state <= RAM_BURST_OFF2;
      end
    end
    
    RAM_BURST_OFF2: begin
      ram_enable <= 0;
      if (data_out_ready) begin
        ram_arbiter_state <= RAM_ROW_FETCHED;
      end
    end
    
    RAM_ROW_FETCHED: begin
      if (refresh_counter<refresh_max)
        refresh_counter<=refresh_counter+1'b1;
    
      if ((need_row_fetch_y_latched!=fetch_line_y) && x_safe_area_sync[1] && cmd_ready) begin
        row_fetched <= 0;
        fetch_x <= 0;
        fetch_line_y <= need_row_fetch_y_latched;
        ram_arbiter_state <= RAM_READY;
        
      end else if (x_safe_area_sync[1]) begin
        // do nothing if in safe area
        
      end else if (refresh_counter==refresh_max && cmd_ready) begin
        // refresh ram
        ram_arbiter_state <= RAM_REFRESH_PRE;
        
      // BLITTER ----------------------------------------------------------------
      end else if (blitter_enable==1 && cmd_ready) begin
        if (blitter_colormode==2) begin
          blitter_rgb <= blitter_rgb32[blitter_rgb32_t];
        end
        
        // rect fill blitter
        if (blitter_curx <= blitter_x2) begin
          ram_arbiter_state <= RAM_BLIT_WRITE;
        end else if (blitter_cury<blitter_y2) begin
          blitter_cury <= blitter_cury + 1'b1;
          blitter_curx <= blitter_x1;
          blitter_ptr <= blitter_ptr + blitter_row_pitch;
          blitter_rgb32_t <= 0;
        end else begin
          blitter_curx <= 0;
          blitter_cury <= 0;
          blitter_enable <= 0;
          //ram_enable <= 0; // CHECKME this was commented out: creates regular missing dots when not commented out
          // NOPE, this doesn't make a difference actually.
        end
      
      end else if (blitter_enable==2 && cmd_ready) begin
        // block copy read
        if (data_out_queue_empty) begin
          ram_byte_enable <= 'b11;
          ram_addr    <= blitter_ptr2+blitter_curx2;
          ram_write   <= 0;
          ram_enable  <= 1;
          ram_arbiter_state <= RAM_BLIT_COPY_READ;
        end else 
          ram_enable <= 0;
        
      end else if (blitter_enable==4 && cmd_ready) begin
        // block copy write
        ram_addr    <= blitter_ptr+blitter_curx;
        ram_data_in <= blitter_copy_rgb;
        ram_write   <= 1;
        ram_enable  <= 1;
        ram_byte_enable <= 'b11;
        
        ram_arbiter_state <= RAM_BLIT_COPY_WRITE;
        blitter_enable <= 2;
        
      // ZORRO READ/WRITE ----------------------------------------------
      end else if (videocap_mode && zorro_ram_write_request) begin
        zorro_ram_write_request <= 0;
      end else if (blitter_enable==0 && zorro_ram_write_request && cmd_ready) begin
        // process write request
        ram_arbiter_state <= RAM_WRITING_ZORRO_PRE;
      end else if (blitter_enable==0 && zorro_ram_read_request && cmd_ready) begin
        // process read request
        zorro_ram_read_done <= 0;
        ram_enable <= 0;
        ram_arbiter_state <= RAM_READING_ZORRO_PRE;
      end else if (!videocap_line_saved && videocap_mode && cmd_ready) begin
        // CAPTURE
        ram_enable <= 1;
        ram_write <= 1;
        ram_byte_enable <= 'b11;
        ram_addr <= videocap_save_base + videocap_save_x2;
        ram_data_in <= videocap_buf2[videocap_save_x+videocap_prex2];
        ram_data_in_next <= videocap_buf[videocap_save_x+videocap_prex2];
        
        if (videocap_save_x<videocap_width) begin
          videocap_save_x  <= videocap_save_x  + 1'b1;
          videocap_save_x2 <= videocap_save_x2  + 2'b10;
        end else begin
          videocap_line_saved <= 1;
        end
      end
    end
    
    RAM_REFRESH_PRE: begin
      refresh_counter <= 0;
      ram_enable <= 1;
      ram_write <= 0;
      ram_byte_enable <= 'b11;
      ram_addr <= refresh_addr;
      refresh_addr <= refresh_addr + 512;
      ram_arbiter_state <= RAM_REFRESH;
    end
    
    RAM_REFRESH: begin
      if (data_out_ready) begin
        ram_enable <= 0;
        ram_arbiter_state <= RAM_ROW_FETCHED;
      end
    end
    
    RAM_BLIT_WRITE: begin
      if (cmd_ready) begin
        blitter_curx <= blitter_curx + 1'b1;
        ram_byte_enable <= 'b11;
        ram_addr    <= blitter_ptr + blitter_curx;
        ram_data_in <= blitter_rgb;
        ram_write   <= 1;
        ram_enable  <= 1;
        
        blitter_rgb32_t <= ~blitter_rgb32_t;
        
        ram_arbiter_state <= RAM_WRITE_END1;
      end
    end
    
    RAM_WRITE_END1: begin
      if (!cmd_ready) begin
        ram_arbiter_state <= RAM_WRITE_END;
      end
    end
    
    RAM_WRITE_END: begin
      if (cmd_ready) begin
        ram_enable <= 0;
        ram_arbiter_state <= RAM_ROW_FETCHED;
      end
    end
    
    RAM_BLIT_COPY_READ: begin
      if (data_out_ready) begin
        ram_enable <= 0;
        blitter_copy_rgb <= ram_data_out;
        blitter_enable <= 4;
        ram_arbiter_state <= RAM_ROW_FETCHED;
      end
    end
    
    RAM_BLIT_COPY_WRITE: begin
      if (blitter_curx2 != blitter_x4) begin
        if (blitter_dirx==1) begin
          blitter_curx2 <= blitter_curx2 - 1'b1;
          blitter_curx  <= blitter_curx - 1'b1;
        end else begin
          blitter_curx2 <= blitter_curx2 + 1'b1;
          blitter_curx  <= blitter_curx + 1'b1;
        end
      end else if (blitter_cury2 == blitter_y4) begin
        // done
        blitter_enable <= 0;
      end else if (blitter_diry == 0) begin
        blitter_curx <= blitter_x1;
        blitter_curx2 <= blitter_x3;
        blitter_ptr <= blitter_ptr + blitter_row_pitch;
        blitter_ptr2 <= blitter_ptr2 + blitter_row_pitch;
        blitter_cury <= blitter_cury + 1'b1;
        blitter_cury2 <= blitter_cury2 + 1'b1;
      end else begin
        blitter_curx <= blitter_x1;
        blitter_curx2 <= blitter_x3;
        blitter_ptr <= blitter_ptr - blitter_row_pitch;
        blitter_ptr2 <= blitter_ptr2 - blitter_row_pitch;
        blitter_cury <= blitter_cury - 1'b1;
        blitter_cury2 <= blitter_cury2 - 1'b1;
      end
      
      ram_arbiter_state <= RAM_WRITE_END1;
    end
    
    RAM_READING_ZORRO_PRE: begin
      if (data_out_queue_empty && cmd_ready) begin
        ram_write <= 0;
        ram_addr <= zorro_ram_read_addr;
        ram_byte_enable <= 'b11;
        ram_enable <= 1;
        ram_arbiter_state <= RAM_READING_ZORRO;
      end
    end
    
    RAM_READING_ZORRO: begin
      if (data_out_ready) begin
        ram_enable <= 0;
        zorro_ram_read_data <= ram_data_out;
        zorro_ram_read_done <= 1;
        zorro_ram_read_request <= 0;
        ram_arbiter_state <= RAM_ROW_FETCHED;
      end
    end
    
    RAM_WRITING_ZORRO_PRE: begin
      if (cmd_ready) begin
      
`ifdef TRACE
        trace_5 <= zorro_ram_write_addr;
        trace_6 <= zorro_ram_write_data;
`endif      
      
        ram_byte_enable <= zorro_ram_write_bytes;
        ram_data_in <= zorro_ram_write_data;
        ram_addr    <= zorro_ram_write_addr;
        ram_write   <= 1;
        ram_enable  <= 1;
        
        ram_arbiter_state <= RAM_WRITING_ZORRO;
      end
    end
    
    RAM_WRITING_ZORRO: begin
      //if (cmd_ready) begin
        zorro_ram_write_done <= 1;
        zorro_ram_write_request <= 0;
        ram_enable <= 0;
        ram_write <= 0;
        ram_arbiter_state <= RAM_ROW_FETCHED;
      //end
    end
    
    default:
      ram_arbiter_state <= RAM_READY;
    
  endcase
  
  
  vga_clk_sel0_latch <= {vga_clk_sel0_latch[0],vga_clk_sel[0]};
  dvid_reset_sync <= {dvid_reset_sync[0],dvid_reset};
end

reg[15:0] rgb = 'h0000;
reg[15:0] rgb2 = 'h0000;
reg[11:0] counter_8x = 0;

reg display_sprite = 0;
reg preheat = 0;
reg x_safe_area = 0;
reg [1:0] x_safe_area_sync = 0;
reg display_pixels = 0;

reg vga_scalemode_h = 0;
reg vga_scalemode_v = 0;
reg[1:0] vga_colormode = 0;
reg[4:0] vga_margin_x = 0;

reg[11:0] vga_h_max = 0;
reg[11:0] vga_v_max = 0;
reg[11:0] vga_h_sync_start = 0;
reg[11:0] vga_h_sync_end = 0;
reg[11:0] vga_v_sync_start = 0;
reg[11:0] vga_v_sync_end = 0;
reg[11:0] vga_h_rez = 0;
reg[11:0] vga_v_rez = 0;
reg[11:0] vga_screen_h = 0;

always @(posedge vga_clk) begin
  // clock domain sync
  vga_scalemode_h <= scalemode_h;
  vga_colormode <= colormode;
  vga_margin_x <= margin_x;
  vga_h_max <= h_max;
  vga_v_max <= v_max;
  if (videocap_mode) begin
    if (videocap_ntsc)
      vga_screen_h <= 'h19b;
    else
      vga_screen_h <= 'h1ff;
    vga_scalemode_v <= videocap_interlace?0:1;
  end else begin
    vga_screen_h <= screen_h;
    vga_scalemode_v <= scalemode_v;
  end
  vga_h_rez <= h_rez;
  vga_v_rez <= v_rez;
  vga_h_sync_start <= h_sync_start;
  vga_h_sync_end <= h_sync_end;
  vga_v_sync_start <= v_sync_start;
  vga_v_sync_end <= v_sync_end;
end

reg [9:0] counter_scanout = 0;
reg [9:0] counter_px = 0;
reg [2:0] counter_repeat = 0;
reg [2:0] counter_repeat_delayed = 0;
reg [1:0] counter_scanout_words = 1;
reg [1:0] max_repeat = 0;
reg counter_vscale = 0;
reg aligned_row_mode = 1;

always @(posedge vga_clk) begin
  x_safe_area <= ((counter_scanout > safe_x2) || (counter_scanout < safe_x1));
  
  if (counter_x > vga_h_max) begin
    counter_x <= 0;
    if (counter_y > vga_v_max) begin
      counter_y <= 0;
    end else begin
      counter_y <= counter_y + 1'b1;
    end
  end else begin
    counter_x <= counter_x + 1'b1;
  end
  
  if (counter_x>=vga_h_sync_start && counter_x<vga_h_sync_end)
    dvi_hsync <= 1;
  else
    dvi_hsync <= 0;
    
  if (counter_y>=vga_v_sync_start && counter_y<vga_v_sync_end)
    dvi_vsync <= 1;
  else
    dvi_vsync <= 0;
      
  if (counter_x<vga_h_rez && counter_y<vga_v_rez) begin
    dvi_blank <= 0;
  end else begin
    dvi_blank <= 1;
  end
  
  if (vga_colormode==0)
    if (vga_scalemode_h==1)
      max_repeat <= 3;
    else
      max_repeat <= 1;
  else
    if (vga_scalemode_h==1)
      max_repeat <= 1;
    else
      max_repeat <= 0;
  
  if (vga_colormode==2)
    counter_scanout_words <= 2;
  else
    counter_scanout_words <= 1;

  if ((counter_y < vga_screen_h) || ((counter_x > vga_h_max) && counter_y>vga_v_max)) begin
    if ((counter_x < vga_h_rez-1) || ((counter_x > vga_h_max) && counter_y!=vga_screen_h-1)) begin
      display_pixels <= 1;
    
      if (counter_repeat == max_repeat) begin
        counter_repeat <= 0;
        counter_px <= (counter_px + counter_scanout_words);
        
        if (counter_vscale==0) begin
          counter_scanout <= (counter_scanout + counter_scanout_words);
          if (counter_scanout == fetch_preroll)
            need_row_fetch_y <= need_row_fetch_y+1'b1;
        end
      end else
        counter_repeat <= counter_repeat+1'b1;
      
    end else begin
      counter_px <= 0;
      if (aligned_row_mode)
        counter_scanout <= 0;
      display_pixels <= 0;
    end
    
    if ((counter_x == vga_h_rez) && (vga_scalemode_v==1)) begin
      counter_vscale <= ~counter_vscale;
    end
  end else begin
    need_row_fetch_y <= 0;
    display_pixels <= 0;
    
    counter_scanout <= 0;
    counter_vscale <= 0;
    counter_px <= 0;
    counter_repeat <= 0;
  end

  counter_repeat_delayed <= counter_repeat;
  
  if (vga_scalemode_v == 0 || counter_vscale == 0) begin
    rgb  <= fetch_buffer[counter_scanout];
    rgb2 <= fetch_buffer[counter_scanout+1'b1];
    
    if (counter_x<=vga_h_rez)
      scale_buffer[counter_x] <= {rgb2[15:8],rgb};
      //scale_buffer[counter_px] <= rgb2;
    if (counter_x==0)
      sb0 <= rgb;
  end else begin
    if (counter_x<vga_h_rez) begin
      rgb  <= scale_buffer[counter_px][15:0];
      rgb2 <= {scale_buffer[counter_px][23:16],8'b00000000};
    end else
      rgb <= sb0;
  end
  
  if (!display_pixels) begin
    red_p   <= 0;
    green_p <= 0;
    blue_p  <= 0;
  end else if (vga_colormode==0) begin
    // 8 bit palette indexed
    // 0: +0a +0b +1a
    // 1: +0b +1a +1b
    
    /*if (preheat) begin
      red_p <= 0;
      green_p <= 0;
      blue_p <= 0;
      preheat <= 0;
    end else*/ 
    if (counter_repeat_delayed[vga_scalemode_h]==1) begin
      red_p   <= palette_r[rgb[7:0]];
      green_p <= palette_g[rgb[7:0]];
      blue_p  <= palette_b[rgb[7:0]];
    end else begin
      red_p   <= palette_r[rgb[15:8]];
      green_p <= palette_g[rgb[15:8]];
      blue_p  <= palette_b[rgb[15:8]];
    end
  end else if (vga_colormode==1) begin
    // decode 16 to 24 bit color
    red_p   <= {rgb[4:0],  rgb[4:2]};
    green_p <= {rgb[10:5], rgb[10:9]};
    blue_p  <= {rgb[15:11],rgb[15:13]};
    
  end else if (vga_colormode==2) begin
    // true color
    blue_p   <= rgb2[15:8];
    green_p <= rgb[7:0];
    red_p  <= rgb[15:8];
  end else begin
    red_p   <= 0;
    green_p <= 0;
    blue_p  <= 0;
  end
end

endmodule
