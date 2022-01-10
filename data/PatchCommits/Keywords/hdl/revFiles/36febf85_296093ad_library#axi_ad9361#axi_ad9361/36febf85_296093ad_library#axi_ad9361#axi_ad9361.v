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

`timescale 1ns/100ps

module axi_ad9361 (

  // physical interface (receive)

  rx_clk_in_p,
  rx_clk_in_n,
  rx_frame_in_p,
  rx_frame_in_n,
  rx_data_in_p,
  rx_data_in_n,

  // physical interface (transmit)

  tx_clk_out_p,
  tx_clk_out_n,
  tx_frame_out_p,
  tx_frame_out_n,
  tx_data_out_p,
  tx_data_out_n,

  // ensm control

  enable,
  txnrx,

  // transmit master/slave

  dac_sync_in,
  dac_sync_out,

  // tdd sync (1s pulse)

  tdd_sync,
  tdd_sync_en,
  tdd_terminal_type,

  // delay clock

  delay_clk,

  // master interface

  l_clk,
  clk,
  rst,

  // dma interface

  adc_enable_i0,
  adc_valid_i0,
  adc_data_i0,
  adc_enable_q0,
  adc_valid_q0,
  adc_data_q0,
  adc_enable_i1,
  adc_valid_i1,
  adc_data_i1,
  adc_enable_q1,
  adc_valid_q1,
  adc_data_q1,
  adc_dovf,
  adc_dunf,
  adc_r1_mode,

  dac_enable_i0,
  dac_valid_i0,
  dac_data_i0,
  dac_enable_q0,
  dac_valid_q0,
  dac_data_q0,
  dac_enable_i1,
  dac_valid_i1,
  dac_data_i1,
  dac_enable_q1,
  dac_valid_q1,
  dac_data_q1,
  dac_dovf,
  dac_dunf,
  dac_r1_mode,

  // axi interface

  s_axi_aclk,
  s_axi_aresetn,
  s_axi_awvalid,
  s_axi_awaddr,
  s_axi_awprot,
  s_axi_awready,
  s_axi_wvalid,
  s_axi_wdata,
  s_axi_wstrb,
  s_axi_wready,
  s_axi_bvalid,
  s_axi_bresp,
  s_axi_bready,
  s_axi_arvalid,
  s_axi_araddr,
  s_axi_arprot,
  s_axi_arready,
  s_axi_rvalid,
  s_axi_rdata,
  s_axi_rresp,
  s_axi_rready,

  // gpio

  up_enable,
  up_txnrx,
  up_dac_gpio_in,
  up_dac_gpio_out,
  up_adc_gpio_in,
  up_adc_gpio_out,

  // chipscope signals

  tdd_dbg);

  // parameters

  parameter   ID = 0;
  parameter   DEVICE_TYPE = 0;
  parameter   DAC_IODELAY_ENABLE = 0;
  parameter   IO_DELAY_GROUP = "dev_if_delay_group";
  parameter   DAC_DATAPATH_DISABLE = 0;
  parameter   ADC_DATAPATH_DISABLE = 0;

  // physical interface (receive)

  input           rx_clk_in_p;
  input           rx_clk_in_n;
  input           rx_frame_in_p;
  input           rx_frame_in_n;
  input   [ 5:0]  rx_data_in_p;
  input   [ 5:0]  rx_data_in_n;

  // physical interface (transmit)

  output          tx_clk_out_p;
  output          tx_clk_out_n;
  output          tx_frame_out_p;
  output          tx_frame_out_n;
  output  [ 5:0]  tx_data_out_p;
  output  [ 5:0]  tx_data_out_n;

  // ensm control

  output          enable;
  output          txnrx;

  // transmit master/slave

  input           dac_sync_in;
  output          dac_sync_out;

  // tdd sync

  input           tdd_sync;
  output          tdd_sync_en;
  output          tdd_terminal_type;

  // delay clock

  input           delay_clk;

  // master interface

  output          l_clk;
  input           clk;
  output          rst;

  // dma interface

  output          adc_enable_i0;
  output          adc_valid_i0;
  output  [15:0]  adc_data_i0;
  output          adc_enable_q0;
  output          adc_valid_q0;
  output  [15:0]  adc_data_q0;
  output          adc_enable_i1;
  output          adc_valid_i1;
  output  [15:0]  adc_data_i1;
  output          adc_enable_q1;
  output          adc_valid_q1;
  output  [15:0]  adc_data_q1;
  input           adc_dovf;
  input           adc_dunf;
  output          adc_r1_mode;

  output          dac_enable_i0;
  output          dac_valid_i0;
  input   [15:0]  dac_data_i0;
  output          dac_enable_q0;
  output          dac_valid_q0;
  input   [15:0]  dac_data_q0;
  output          dac_enable_i1;
  output          dac_valid_i1;
  input   [15:0]  dac_data_i1;
  output          dac_enable_q1;
  output          dac_valid_q1;
  input   [15:0]  dac_data_q1;
  input           dac_dovf;
  input           dac_dunf;
  output          dac_r1_mode;

  // axi interface

  input           s_axi_aclk;
  input           s_axi_aresetn;
  input           s_axi_awvalid;
  input   [31:0]  s_axi_awaddr;
  input   [ 2:0]  s_axi_awprot;
  output          s_axi_awready;
  input           s_axi_wvalid;
  input   [31:0]  s_axi_wdata;
  input   [ 3:0]  s_axi_wstrb;
  output          s_axi_wready;
  output          s_axi_bvalid;
  output  [ 1:0]  s_axi_bresp;
  input           s_axi_bready;
  input           s_axi_arvalid;
  input   [31:0]  s_axi_araddr;
  input   [ 2:0]  s_axi_arprot;
  output          s_axi_arready;
  output          s_axi_rvalid;
  output  [31:0]  s_axi_rdata;
  output  [ 1:0]  s_axi_rresp;
  input           s_axi_rready;

  // gpio

  input           up_enable;
  input           up_txnrx;
  input   [31:0]  up_dac_gpio_in;
  output  [31:0]  up_dac_gpio_out;
  input   [31:0]  up_adc_gpio_in;
  output  [31:0]  up_adc_gpio_out;

  // chipscope signals

  output  [41:0]  tdd_dbg;

  // internal registers

  reg             up_wack = 'd0;
  reg             up_rack = 'd0;
  reg     [31:0]  up_rdata = 'd0;

  // internal clocks and resets

  wire            up_clk;
  wire            up_rstn;
  wire            delay_rst;

  // internal signals

  wire            adc_ddr_edgesel;
  wire            adc_valid_s;
  wire    [47:0]  adc_data_s;
  wire            adc_status_s;
  wire            dac_valid_s;
  wire    [47:0]  dac_data_s;
  wire            dac_valid_i0_s;
  wire            dac_valid_q0_s;
  wire            dac_valid_i1_s;
  wire            dac_valid_q1_s;
  wire    [ 6:0]  up_adc_dld_s;
  wire    [34:0]  up_adc_dwdata_s;
  wire    [34:0]  up_adc_drdata_s;
  wire    [ 9:0]  up_dac_dld_s;
  wire    [49:0]  up_dac_dwdata_s;
  wire    [49:0]  up_dac_drdata_s;
  wire            delay_locked_s;
  wire            up_wreq_s;
  wire    [13:0]  up_waddr_s;
  wire    [31:0]  up_wdata_s;
  wire            up_wack_rx_s;
  wire            up_wack_tx_s;
  wire            up_rreq_s;
  wire    [13:0]  up_raddr_s;
  wire    [31:0]  up_rdata_rx_s;
  wire            up_rack_rx_s;
  wire    [31:0]  up_rdata_tx_s;
  wire            up_rack_tx_s;
  wire            up_wack_tdd_s;
  wire            up_rack_tdd_s;
  wire    [31:0]  up_rdata_tdd_s;
  wire            tdd_tx_dp_en_s;
  wire            tdd_rx_vco_en_s;
  wire            tdd_tx_vco_en_s;
  wire            tdd_rx_rf_en_s;
  wire            tdd_tx_rf_en_s;
  wire    [ 7:0]  tdd_status_s;
  wire            tdd_enable_s;
  wire            tdd_txnrx_s;
  wire            tdd_mode_s;


  // signal name changes

  assign up_clk = s_axi_aclk;
  assign up_rstn = s_axi_aresetn;

  // processor read interface

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_wack <= 'd0;
      up_rack <= 'd0;
      up_rdata <= 'd0;
    end else begin
      up_wack <= up_wack_rx_s | up_wack_tx_s | up_wack_tdd_s;
      up_rack <= up_rack_rx_s | up_rack_tx_s | up_rack_tdd_s;
      up_rdata <= up_rdata_rx_s | up_rdata_tx_s | up_rdata_tdd_s;
    end
  end

  // device interface

  axi_ad9361_dev_if #(
    .DEVICE_TYPE (DEVICE_TYPE),
    .DAC_IODELAY_ENABLE (DAC_IODELAY_ENABLE),
    .IO_DELAY_GROUP (IO_DELAY_GROUP))
  i_dev_if (
    .rx_clk_in_p (rx_clk_in_p),
    .rx_clk_in_n (rx_clk_in_n),
    .rx_frame_in_p (rx_frame_in_p),
    .rx_frame_in_n (rx_frame_in_n),
    .rx_data_in_p (rx_data_in_p),
    .rx_data_in_n (rx_data_in_n),
    .tx_clk_out_p (tx_clk_out_p),
    .tx_clk_out_n (tx_clk_out_n),
    .tx_frame_out_p (tx_frame_out_p),
    .tx_frame_out_n (tx_frame_out_n),
    .tx_data_out_p (tx_data_out_p),
    .tx_data_out_n (tx_data_out_n),
    .enable (enable),
    .txnrx (txnrx),
    .rst (rst),
    .clk (clk),
    .l_clk (l_clk),
    .adc_valid (adc_valid_s),
    .adc_data (adc_data_s),
    .adc_status (adc_status_s),
    .adc_r1_mode (adc_r1_mode),
    .adc_ddr_edgesel (adc_ddr_edgesel),
    .dac_valid (dac_valid_s),
    .dac_data (dac_data_s),
    .dac_r1_mode (dac_r1_mode),
    .tdd_enable (tdd_enable_s),
    .tdd_txnrx (tdd_txnrx_s),
    .tdd_mode (tdd_mode_s),
    .up_clk (up_clk),
    .up_enable (up_enable),
    .up_txnrx (up_txnrx),
    .up_adc_dld (up_adc_dld_s),
    .up_adc_dwdata (up_adc_dwdata_s),
    .up_adc_drdata (up_adc_drdata_s),
    .up_dac_dld (up_dac_dld_s),
    .up_dac_dwdata (up_dac_dwdata_s),
    .up_dac_drdata (up_dac_drdata_s),
    .delay_clk (delay_clk),
    .delay_rst (delay_rst),
    .delay_locked (delay_locked_s));

  // TDD interface

  axi_ad9361_tdd_if #(.LEVEL_OR_PULSE_N(1)) i_tdd_if (
    .clk (clk),
    .rst (rst),
    .tdd_rx_vco_en (tdd_rx_vco_en_s),
    .tdd_tx_vco_en (tdd_tx_vco_en_s),
    .tdd_rx_rf_en (tdd_rx_rf_en_s),
    .tdd_tx_rf_en (tdd_tx_rf_en_s),
    .ad9361_txnrx (tdd_txnrx_s),
    .ad9361_enable (tdd_enable_s),
    .ad9361_tdd_status (tdd_status_s));

  // TDD control

  axi_ad9361_tdd i_tdd (
    .clk (clk),
    .rst (rst),
    .tdd_rx_vco_en (tdd_rx_vco_en_s),
    .tdd_tx_vco_en (tdd_tx_vco_en_s),
    .tdd_rx_rf_en (tdd_rx_rf_en_s),
    .tdd_tx_rf_en (tdd_tx_rf_en_s),
    .tdd_enabled (tdd_mode_s),
    .tdd_status (tdd_status_s),
    .tdd_sync (tdd_sync),
    .tdd_sync_en (tdd_sync_en),
    .tdd_terminal_type (tdd_terminal_type),
    .tx_valid_i0 (dac_valid_i0_s),
    .tx_valid_q0 (dac_valid_q0_s),
    .tx_valid_i1 (dac_valid_i1_s),
    .tx_valid_q1 (dac_valid_q1_s),
    .tdd_tx_valid_i0 (dac_valid_i0),
    .tdd_tx_valid_q0 (dac_valid_q0),
    .tdd_tx_valid_i1 (dac_valid_i1),
    .tdd_tx_valid_q1 (dac_valid_q1),
    .rx_valid_i0 (adc_valid_i0_s),
    .rx_valid_q0 (adc_valid_q0_s),
    .rx_valid_i1 (adc_valid_i1_s),
    .rx_valid_q1 (adc_valid_q1_s),
    .tdd_rx_valid_i0 (adc_valid_i0),
    .tdd_rx_valid_q0 (adc_valid_q0),
    .tdd_rx_valid_i1 (adc_valid_i1),
    .tdd_rx_valid_q1 (adc_valid_q1),
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_tdd_s),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_tdd_s),
    .up_rack (up_rack_tdd_s),
    .tdd_dbg (tdd_dbg));

  // receive

  axi_ad9361_rx #(
    .ID (ID),
    .DATAPATH_DISABLE (ADC_DATAPATH_DISABLE))
  i_rx (
    .adc_rst (rst),
    .adc_clk (clk),
    .adc_valid (adc_valid_s),
    .adc_data (adc_data_s),
    .adc_status (adc_status_s),
    .adc_r1_mode (adc_r1_mode),
    .adc_ddr_edgesel (adc_ddr_edgesel),
    .dac_data (dac_data_s),
    .up_dld (up_adc_dld_s),
    .up_dwdata (up_adc_dwdata_s),
    .up_drdata (up_adc_drdata_s),
    .delay_clk (delay_clk),
    .delay_rst (delay_rst),
    .delay_locked (delay_locked_s),
    .adc_enable_i0 (adc_enable_i0),
    .adc_valid_i0 (adc_valid_i0_s),
    .adc_data_i0 (adc_data_i0),
    .adc_enable_q0 (adc_enable_q0),
    .adc_valid_q0 (adc_valid_q0_s),
    .adc_data_q0 (adc_data_q0),
    .adc_enable_i1 (adc_enable_i1),
    .adc_valid_i1 (adc_valid_i1_s),
    .adc_data_i1 (adc_data_i1),
    .adc_enable_q1 (adc_enable_q1),
    .adc_valid_q1 (adc_valid_q1_s),
    .adc_data_q1 (adc_data_q1),
    .adc_dovf (adc_dovf),
    .adc_dunf (adc_dunf),
    .up_adc_gpio_in (up_adc_gpio_in),
    .up_adc_gpio_out (up_adc_gpio_out),
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_rx_s),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_rx_s),
    .up_rack (up_rack_rx_s));

  // transmit

  axi_ad9361_tx #(
    .ID (ID),
    .DATAPATH_DISABLE (DAC_DATAPATH_DISABLE))
  i_tx (
    .dac_clk (clk),
    .dac_valid (dac_valid_s),
    .dac_data (dac_data_s),
    .dac_r1_mode (dac_r1_mode),
    .adc_data (adc_data_s),
    .up_dld (up_dac_dld_s),
    .up_dwdata (up_dac_dwdata_s),
    .up_drdata (up_dac_drdata_s),
    .delay_clk (delay_clk),
    .delay_rst (),
    .delay_locked (delay_locked_s),
    .dac_sync_in (dac_sync_in),
    .dac_sync_out (dac_sync_out),
    .dac_enable_i0 (dac_enable_i0),
    .dac_valid_i0 (dac_valid_i0_s),
    .dac_data_i0 (dac_data_i0),
    .dac_enable_q0 (dac_enable_q0),
    .dac_valid_q0 (dac_valid_q0_s),
    .dac_data_q0 (dac_data_q0),
    .dac_enable_i1 (dac_enable_i1),
    .dac_valid_i1 (dac_valid_i1_s),
    .dac_data_i1 (dac_data_i1),
    .dac_enable_q1 (dac_enable_q1),
    .dac_valid_q1 (dac_valid_q1_s),
    .dac_data_q1 (dac_data_q1),
    .dac_dovf(dac_dovf),
    .dac_dunf(dac_dunf),
    .up_dac_gpio_in (up_dac_gpio_in),
    .up_dac_gpio_out (up_dac_gpio_out),
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_tx_s),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_tx_s),
    .up_rack (up_rack_tx_s));

  // axi interface

  up_axi i_up_axi (
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_axi_awvalid (s_axi_awvalid),
    .up_axi_awaddr (s_axi_awaddr),
    .up_axi_awready (s_axi_awready),
    .up_axi_wvalid (s_axi_wvalid),
    .up_axi_wdata (s_axi_wdata),
    .up_axi_wstrb (s_axi_wstrb),
    .up_axi_wready (s_axi_wready),
    .up_axi_bvalid (s_axi_bvalid),
    .up_axi_bresp (s_axi_bresp),
    .up_axi_bready (s_axi_bready),
    .up_axi_arvalid (s_axi_arvalid),
    .up_axi_araddr (s_axi_araddr),
    .up_axi_arready (s_axi_arready),
    .up_axi_rvalid (s_axi_rvalid),
    .up_axi_rresp (s_axi_rresp),
    .up_axi_rdata (s_axi_rdata),
    .up_axi_rready (s_axi_rready),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata),
    .up_rack (up_rack));

endmodule

// ***************************************************************************
// ***************************************************************************
