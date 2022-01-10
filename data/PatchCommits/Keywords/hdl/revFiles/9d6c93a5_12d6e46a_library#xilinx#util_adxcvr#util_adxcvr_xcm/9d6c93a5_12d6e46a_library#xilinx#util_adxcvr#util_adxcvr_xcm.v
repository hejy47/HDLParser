// ***************************************************************************
// ***************************************************************************
// Copyright 2011(c) Analog Devices, Inc.
// 
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//     - Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     - Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in
//       the documentation and/or other materials provided with the
//       distribution.
//     - Neither the name of Analog Devices, Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//     - The use of this software may or may not infringe the patent rights
//       of one or more patent holders.  This license does not release you
//       from the requirement that you obtain separate licenses from these
//       patent holders to use this software.
//     - Use of the software either in source or binary form, must be run
//       on or directly connected to an Analog Devices Inc. component.
//    
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED.
//
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, INTELLECTUAL PROPERTY
// RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/1ps

module util_adxcvr_xcm #(

  // parameters

  parameter   integer XCVR_ID = 0,
  parameter   integer XCVR_TYPE = 0,
  parameter   integer QPLL_REFCLK_DIV = 1,
  parameter   integer QPLL_FBDIV_RATIO = 1,
  parameter   [26:0]  QPLL_CFG = 27'h0680181,
  parameter   [ 9:0]  QPLL_FBDIV =  10'b0000110000) (

  // reset and clocks

  input           qpll_ref_clk,
  output          qpll2ch_clk,
  output          qpll2ch_ref_clk,
  output          qpll2ch_locked,
  
  // drp interface

  input           up_rstn,
  input           up_clk,
  input           up_qpll_rst,
  input   [ 7:0]  up_cm_sel,
  input           up_cm_enb,
  input   [11:0]  up_cm_addr,
  input           up_cm_wr,
  input   [15:0]  up_cm_wdata,
  output  [15:0]  up_cm_rdata,
  output          up_cm_ready);

  // internal registers

  reg             up_enb_int = 'd0;
  reg     [11:0]  up_addr_int = 'd0;
  reg             up_wr_int = 'd0;
  reg     [15:0]  up_wdata_int = 'd0;
  reg     [15:0]  up_rdata_int = 'd0;
  reg             up_ready_int = 'd0;

  // internal signals

  wire    [15:0]  up_rdata_s;
  wire            up_ready_s;

  // drp access

  assign up_cm_rdata = up_rdata_int;
  assign up_cm_ready = up_ready_int;

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 1'b0) begin
      up_enb_int <= 1'd0;
      up_addr_int <= 12'd0;
      up_wr_int <= 1'd0;
      up_wdata_int <= 16'd0;
      up_rdata_int <= 16'd0;
      up_ready_int <= 1'd0;
    end else begin
      if ((up_cm_sel == XCVR_ID) || (up_cm_sel == 8'hff)) begin
        up_enb_int <= up_cm_enb;
        up_addr_int <= up_cm_addr;
        up_wr_int <= up_cm_wr;
        up_wdata_int <= up_cm_wdata;
        up_rdata_int <= up_rdata_s;
        up_ready_int <= up_ready_s;
      end else begin
        up_enb_int <= 1'd0;
        up_addr_int <= 12'd0;
        up_wr_int <= 1'd0;
        up_wdata_int <= 16'd0;
        up_rdata_int <= 16'd0;
        up_ready_int <= 1'd0;
      end
    end
  end

  // instantiations

  generate
  if (XCVR_TYPE == 0) begin
  GTXE2_COMMON #(
    .BIAS_CFG (64'h0000040000001000),
    .COMMON_CFG (32'h00000000),
    .IS_DRPCLK_INVERTED (1'b0),
    .IS_GTGREFCLK_INVERTED (1'b0),
    .IS_QPLLLOCKDETCLK_INVERTED (1'b0),
    .QPLL_CFG (QPLL_CFG),
    .QPLL_CLKOUT_CFG (4'b0000),
    .QPLL_COARSE_FREQ_OVRD (6'b010000),
    .QPLL_COARSE_FREQ_OVRD_EN (1'b0),
    .QPLL_CP (10'b0000011111),
    .QPLL_CP_MONITOR_EN (1'b0),
    .QPLL_DMONITOR_SEL (1'b0),
    .QPLL_FBDIV (QPLL_FBDIV),
    .QPLL_FBDIV_MONITOR_EN (1'b0),
    .QPLL_FBDIV_RATIO (QPLL_FBDIV_RATIO),
    .QPLL_INIT_CFG (24'h000006),
    .QPLL_LOCK_CFG (16'h21E8),
    .QPLL_LPF (4'b1111),
    .QPLL_REFCLK_DIV (QPLL_REFCLK_DIV),
    .SIM_QPLLREFCLK_SEL (3'b001),
    .SIM_RESET_SPEEDUP ("TRUE"),
    .SIM_VERSION ("4.0"))
  i_gtxe2_common (
    .QPLLDMONITOR (),
    .QPLLFBCLKLOST (),
    .REFCLKOUTMONITOR (),
    .BGBYPASSB (1'h1),
    .BGMONITORENB (1'h1),
    .BGPDB (1'h1),
    .BGRCALOVRD (5'h1f),
    .DRPADDR (up_addr_int[7:0]),
    .DRPCLK (up_clk),
    .DRPDI (up_wdata_int),
    .DRPDO (up_rdata_s),
    .DRPEN (up_enb_int),
    .DRPRDY (up_ready_s),
    .DRPWE (up_wr_int),
    .GTGREFCLK (1'h0),
    .GTNORTHREFCLK0 (1'h0),
    .GTNORTHREFCLK1 (1'h0),
    .GTREFCLK0 (qpll_ref_clk),
    .GTREFCLK1 (1'h0),
    .GTSOUTHREFCLK0 (1'h0),
    .GTSOUTHREFCLK1 (1'h0),
    .PMARSVD (8'h0),
    .QPLLLOCK (qpll2ch_locked),
    .QPLLLOCKDETCLK (up_clk),
    .QPLLLOCKEN (1'h1),
    .QPLLOUTCLK (qpll2ch_clk),
    .QPLLOUTREFCLK (qpll2ch_ref_clk),
    .QPLLOUTRESET (1'h0),
    .QPLLPD (1'h0),
    .QPLLREFCLKLOST (),
    .QPLLREFCLKSEL (3'h1),
    .QPLLRESET (up_qpll_rst),
    .QPLLRSVD1 (16'h0),
    .QPLLRSVD2 (5'h1f),
    .RCALENB (1'h1));
  end
  endgenerate

  generate
  if (XCVR_TYPE == 1) begin
  GTHE3_COMMON #(
    .BIAS_CFG0 (16'h0000),
    .BIAS_CFG1 (16'h0000),
    .BIAS_CFG2 (16'h0000),
    .BIAS_CFG3 (16'h0040),
    .BIAS_CFG4 (16'h0000),
    .BIAS_CFG_RSVD (10'b0000000000),
    .COMMON_CFG0 (16'h0000),
    .COMMON_CFG1 (16'h0000),
    .POR_CFG (16'h0004),
    .QPLL0_CFG0 (16'h321c),
    .QPLL0_CFG1 (16'h1018),
    .QPLL0_CFG1_G3 (16'h1018),
    .QPLL0_CFG2 (16'h0048),
    .QPLL0_CFG2_G3 (16'h0048),
    .QPLL0_CFG3 (16'h0120),
    .QPLL0_CFG4 (16'h0000),
    .QPLL0_CP (10'b0000011111),
    .QPLL0_CP_G3 (10'b1111111111),
    .QPLL0_FBDIV (QPLL_FBDIV),
    .QPLL0_FBDIV_G3 (80),
    .QPLL0_INIT_CFG0 (16'h02b2),
    .QPLL0_INIT_CFG1 (8'h00),
    .QPLL0_LOCK_CFG (16'h21e8),
    .QPLL0_LOCK_CFG_G3 (16'h21e8),
    .QPLL0_LPF (10'b1111111111),
    .QPLL0_LPF_G3 (10'b0000010101),
    .QPLL0_REFCLK_DIV (QPLL_REFCLK_DIV),
    .QPLL0_SDM_CFG0 (16'b0000000000000000),
    .QPLL0_SDM_CFG1 (16'b0000000000000000),
    .QPLL0_SDM_CFG2 (16'b0000000000000000),
    .QPLL1_CFG0 (16'h321c),
    .QPLL1_CFG1 (16'h1018),
    .QPLL1_CFG1_G3 (16'h1018),
    .QPLL1_CFG2 (16'h0040),
    .QPLL1_CFG2_G3 (16'h0040),
    .QPLL1_CFG3 (16'h0120),
    .QPLL1_CFG4 (16'h0000),
    .QPLL1_CP (10'b0000011111),
    .QPLL1_CP_G3 (10'b1111111111),
    .QPLL1_FBDIV (QPLL_FBDIV),
    .QPLL1_FBDIV_G3 (80),
    .QPLL1_INIT_CFG0 (16'h02b2),
    .QPLL1_INIT_CFG1 (8'h00),
    .QPLL1_LOCK_CFG (16'h21e8),
    .QPLL1_LOCK_CFG_G3 (16'h21e8),
    .QPLL1_LPF (10'b1111111111),
    .QPLL1_LPF_G3 (10'b0000010101),
    .QPLL1_REFCLK_DIV (QPLL_REFCLK_DIV),
    .QPLL1_SDM_CFG0 (16'b0000000000000000),
    .QPLL1_SDM_CFG1 (16'b0000000000000000),
    .QPLL1_SDM_CFG2 (16'b0000000000000000),
    .RSVD_ATTR0 (16'h0000),
    .RSVD_ATTR1 (16'h0000),
    .RSVD_ATTR2 (16'h0000),
    .RSVD_ATTR3 (16'h0000),
    .RXRECCLKOUT0_SEL (2'b00),
    .RXRECCLKOUT1_SEL (2'b00),
    .SARC_EN (1'b1),
    .SARC_SEL (1'b0),
    .SDM0DATA1_0 (16'b0000000000000000),
    .SDM0DATA1_1 (9'b000000000),
    .SDM0INITSEED0_0 (16'b0000000000000000),
    .SDM0INITSEED0_1 (9'b000000000),
    .SDM0_DATA_PIN_SEL (1'b0),
    .SDM0_WIDTH_PIN_SEL (1'b0),
    .SDM1DATA1_0 (16'b0000000000000000),
    .SDM1DATA1_1 (9'b000000000),
    .SDM1INITSEED0_0 (16'b0000000000000000),
    .SDM1INITSEED0_1 (9'b000000000),
    .SDM1_DATA_PIN_SEL (1'b0),
    .SDM1_WIDTH_PIN_SEL (1'b0),
    .SIM_MODE ("FAST"),
    .SIM_RESET_SPEEDUP ("TRUE"),
    .SIM_VERSION (2))
  i_gthe3_common (
    .BGBYPASSB (1'h1),
    .BGMONITORENB (1'h1),
    .BGPDB (1'h1),
    .BGRCALOVRD (5'h1f),
    .BGRCALOVRDENB (1'h1),
    .DRPADDR (up_addr_int[8:0]),
    .DRPCLK (up_clk),
    .DRPDI (up_wdata_int),
    .DRPDO (up_rdata_s),
    .DRPEN (up_enb_int),
    .DRPRDY (up_ready_s),
    .DRPWE (up_wr_int),
    .GTGREFCLK0 (1'h0),
    .GTGREFCLK1 (1'h0),
    .GTNORTHREFCLK00 (1'h0),
    .GTNORTHREFCLK01 (1'h0),
    .GTNORTHREFCLK10 (1'h0),
    .GTNORTHREFCLK11 (1'h0),
    .GTREFCLK00 (qpll_ref_clk),
    .GTREFCLK01 (1'h0),
    .GTREFCLK10 (1'h0),
    .GTREFCLK11 (1'h0),
    .GTSOUTHREFCLK00 (1'h0),
    .GTSOUTHREFCLK01 (1'h0),
    .GTSOUTHREFCLK10 (1'h0),
    .GTSOUTHREFCLK11 (1'h0),
    .PMARSVD0 (8'h0),
    .PMARSVD1 (8'h0),
    .PMARSVDOUT0 (),
    .PMARSVDOUT1 (),
    .QPLL0CLKRSVD0 (1'h0),
    .QPLL0CLKRSVD1 (1'h0),
    .QPLL0FBCLKLOST (),
    .QPLL0LOCK (qpll2ch_locked),
    .QPLL0LOCKDETCLK (up_clk),
    .QPLL0LOCKEN (1'h1),
    .QPLL0OUTCLK (qpll2ch_clk),
    .QPLL0OUTREFCLK (qpll2ch_ref_clk),
    .QPLL0PD (1'h0),
    .QPLL0REFCLKLOST (),
    .QPLL0REFCLKSEL (3'h1),
    .QPLL0RESET (up_qpll_rst),
    .QPLL1CLKRSVD0 (1'h0),
    .QPLL1CLKRSVD1 (1'h0),
    .QPLL1FBCLKLOST (),
    .QPLL1LOCK (),
    .QPLL1LOCKDETCLK (1'h0),
    .QPLL1LOCKEN (1'h0),
    .QPLL1OUTCLK (),
    .QPLL1OUTREFCLK (),
    .QPLL1PD (1'h0),
    .QPLL1REFCLKLOST (),
    .QPLL1REFCLKSEL (3'h1),
    .QPLL1RESET (1'h1),
    .QPLLDMONITOR0 (),
    .QPLLDMONITOR1 (),
    .QPLLRSVD1 (8'h0),
    .QPLLRSVD2 (5'h0),
    .QPLLRSVD3 (5'h0),
    .QPLLRSVD4 (8'h0),
    .RCALENB (1'h1),
    .REFCLKOUTMONITOR0 (),
    .REFCLKOUTMONITOR1 (),
    .RXRECCLK0_SEL (),
    .RXRECCLK1_SEL ());
  end
  endgenerate

  generate
  if (XCVR_TYPE == 2) begin
  GTHE4_COMMON #(
    .AEN_QPLL0_FBDIV (1'b1),
    .AEN_QPLL1_FBDIV (1'b1),
    .AEN_SDM0TOGGLE (1'b0),
    .AEN_SDM1TOGGLE (1'b0),
    .A_SDM0TOGGLE (1'b0),
    .A_SDM1DATA_HIGH (9'b000000000),
    .A_SDM1DATA_LOW (16'b0000000000000000),
    .A_SDM1TOGGLE (1'b0),
    .BIAS_CFG0 (16'h0000),
    .BIAS_CFG1 (16'h0000),
    .BIAS_CFG2 (16'h0124),
    .BIAS_CFG3 (16'h0041),
    .BIAS_CFG4 (16'h0010),
    .BIAS_CFG_RSVD (16'h0000),
    .COMMON_CFG0 (16'h0000),
    .COMMON_CFG1 (16'h0000),
    .POR_CFG (16'h0006),
    .PPF0_CFG (16'h0600),
    .PPF1_CFG (16'h0600),
    .QPLL0CLKOUT_RATE ("HALF"),
    .QPLL0_CFG0 (16'h331c),
    .QPLL0_CFG1 (16'hd038),
    .QPLL0_CFG1_G3 (16'hd038),
    .QPLL0_CFG2 (16'h0fc0),
    .QPLL0_CFG2_G3 (16'h0fc0),
    .QPLL0_CFG3 (16'h0120),
    .QPLL0_CFG4 (16'h0003),
    .QPLL0_CP (10'b0001111111),
    .QPLL0_CP_G3 (10'b0000011111),
    .QPLL0_FBDIV (QPLL_FBDIV),
    .QPLL0_FBDIV_G3 (160),
    .QPLL0_INIT_CFG0 (16'h02b2),
    .QPLL0_INIT_CFG1 (8'h00),
    .QPLL0_LOCK_CFG (16'h25e8),
    .QPLL0_LOCK_CFG_G3 (16'h25e8),
    .QPLL0_LPF (10'b0100110111),
    .QPLL0_LPF_G3 (10'b0111010101),
    .QPLL0_PCI_EN (1'b0),
    .QPLL0_RATE_SW_USE_DRP (1'b1),
    .QPLL0_REFCLK_DIV (QPLL_REFCLK_DIV),
    .QPLL0_SDM_CFG0 (16'h0080),
    .QPLL0_SDM_CFG1 (16'h0000),
    .QPLL0_SDM_CFG2 (16'h0000),
    .QPLL1CLKOUT_RATE ("HALF"),
    .QPLL1_CFG0 (16'h331c),
    .QPLL1_CFG1 (16'hd038),
    .QPLL1_CFG1_G3 (16'hd038),
    .QPLL1_CFG2 (16'h0fc0),
    .QPLL1_CFG2_G3 (16'h0fc0),
    .QPLL1_CFG3 (16'h0120),
    .QPLL1_CFG4 (16'h0003),
    .QPLL1_CP (10'b1111111111),
    .QPLL1_CP_G3 (10'b0011111111),
    .QPLL1_FBDIV (QPLL_FBDIV),
    .QPLL1_FBDIV_G3 (80),
    .QPLL1_INIT_CFG0 (16'h02b2),
    .QPLL1_INIT_CFG1 (8'h00),
    .QPLL1_LOCK_CFG (16'h25e8),
    .QPLL1_LOCK_CFG_G3 (16'h25e8),
    .QPLL1_LPF (10'b0100110101),
    .QPLL1_LPF_G3 (10'b0111010100),
    .QPLL1_PCI_EN (1'b0),
    .QPLL1_RATE_SW_USE_DRP (1'b1),
    .QPLL1_REFCLK_DIV (QPLL_REFCLK_DIV),
    .QPLL1_SDM_CFG0 (16'h0080),
    .QPLL1_SDM_CFG1 (16'h0000),
    .QPLL1_SDM_CFG2 (16'h0000),
    .RSVD_ATTR0 (16'h0000),
    .RSVD_ATTR1 (16'h0000),
    .RSVD_ATTR2 (16'h0000),
    .RSVD_ATTR3 (16'h0000),
    .RXRECCLKOUT0_SEL (2'b00),
    .RXRECCLKOUT1_SEL (2'b00),
    .SARC_ENB (1'b0),
    .SARC_SEL (1'b0),
    .SDM0INITSEED0_0 (16'b0000000100010001),
    .SDM0INITSEED0_1 (9'b000010001),
    .SDM1INITSEED0_0 (16'b0000000100010001),
    .SDM1INITSEED0_1 (9'b000010001),
    .SIM_MODE ("FAST"),
    .SIM_RESET_SPEEDUP ("TRUE"),
    .SIM_VERSION (1'h1)) 
  i_gthe4_common (
    .BGBYPASSB (1'd1),
    .BGMONITORENB (1'd1),
    .BGPDB (1'd1),
    .BGRCALOVRD (5'b11111),
    .BGRCALOVRDENB (1'd1),
    .DRPADDR ({4'd0, up_addr_int}),
    .DRPCLK (up_clk),
    .DRPDI (up_wdata_int),
    .DRPDO (up_rdata_s),
    .DRPEN (up_enb_int),
    .DRPRDY (up_ready_s),
    .DRPWE (up_wr_int),
    .GTGREFCLK0 (1'd0),
    .GTGREFCLK1 (1'd0),
    .GTNORTHREFCLK00 (1'd0),
    .GTNORTHREFCLK01 (1'd0),
    .GTNORTHREFCLK10 (1'd0),
    .GTNORTHREFCLK11 (1'd0),
    .GTREFCLK00 (qpll_ref_clk),
    .GTREFCLK01 (1'd0),
    .GTREFCLK10 (1'd0),
    .GTREFCLK11 (1'd0),
    .GTSOUTHREFCLK00 (1'd0),
    .GTSOUTHREFCLK01 (1'd0),
    .GTSOUTHREFCLK10 (1'd0),
    .GTSOUTHREFCLK11 (1'd0),
    .PCIERATEQPLL0 (3'd0),
    .PCIERATEQPLL1 (3'd0),
    .PMARSVD0 (8'd0),
    .PMARSVD1 (8'd0),
    .PMARSVDOUT0 (),
    .PMARSVDOUT1 (),
    .QPLL0CLKRSVD0 (1'd0),
    .QPLL0CLKRSVD1 (1'd0),
    .QPLL0FBCLKLOST (),
    .QPLL0FBDIV (8'd0),
    .QPLL0LOCK (qpll2ch_locked),
    .QPLL0LOCKDETCLK (up_clk),
    .QPLL0LOCKEN (1'd1),
    .QPLL0OUTCLK (qpll2ch_clk),
    .QPLL0OUTREFCLK (qpll2ch_ref_clk),
    .QPLL0PD (1'd0),
    .QPLL0REFCLKLOST (),
    .QPLL0REFCLKSEL (3'b001),
    .QPLL0RESET (up_qpll_rst),
    .QPLL1CLKRSVD0 (1'd0),
    .QPLL1CLKRSVD1 (1'd0),
    .QPLL1FBCLKLOST (),
    .QPLL1FBDIV (8'd0),
    .QPLL1LOCK (),
    .QPLL1LOCKDETCLK (1'd0),
    .QPLL1LOCKEN (1'd0),
    .QPLL1OUTCLK (),
    .QPLL1OUTREFCLK (),
    .QPLL1PD (1'd1),
    .QPLL1REFCLKLOST (),
    .QPLL1REFCLKSEL (3'b001),
    .QPLL1RESET (1'd1),
    .QPLLDMONITOR0 (),
    .QPLLDMONITOR1 (),
    .QPLLRSVD1 (8'd0),
    .QPLLRSVD2 (5'd0),
    .QPLLRSVD3 (5'd0),
    .QPLLRSVD4 (8'd0),
    .RCALENB (1'd1),
    .REFCLKOUTMONITOR0 (),
    .REFCLKOUTMONITOR1 (),
    .RXRECCLK0SEL (),
    .RXRECCLK1SEL (),
    .SDM0DATA (25'd0),
    .SDM0FINALOUT (),
    .SDM0RESET (1'd0),
    .SDM0TESTDATA (),
    .SDM0TOGGLE (1'd0),
    .SDM0WIDTH (2'd0),
    .SDM1DATA (25'd0),
    .SDM1FINALOUT (),
    .SDM1RESET (1'd0),
    .SDM1TESTDATA (),
    .SDM1TOGGLE (1'd0),
    .SDM1WIDTH (2'd0),
    .TCONGPI (10'd0),
    .TCONGPO (),
    .TCONPOWERUP (1'd0),
    .TCONRESET (2'd0),
    .TCONRSVDIN1 (2'd0),
    .TCONRSVDOUT0 ());
  end
  endgenerate

endmodule

// ***************************************************************************
// ***************************************************************************

