// ***************************************************************************
// ***************************************************************************
// Copyright 2015(c) Analog Devices, Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
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
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT,
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, INTELLECTUAL PROPERTY RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ***************************************************************************
// ***************************************************************************
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module axi_ad9684 (

  // device interface ports

  adc_clk_in_p,
  adc_clk_in_n,
  adc_data_in_p,
  adc_data_in_n,
  adc_data_or_p,
  adc_data_or_n,

  // dma interface ports

  adc_clk,
  adc_rst,
  adc_valid_0,
  adc_enable_0,
  adc_data_0,
  adc_valid_1,
  adc_enable_1,
  adc_data_1,
  adc_dovf,
  adc_dunf,

  // delay clock ports

  delay_clk,

  // axi slave interface ports

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
  s_axi_rresp,
  s_axi_rdata,
  s_axi_rready
);

  // parameters

  parameter ID = 0;
  parameter DEVICE_TYPE = 0;
  parameter IO_DELAY_GROUP = "dev_if_delay_group";
  parameter OR_STATUS = 1;

  // IO definitions

  input           adc_clk_in_p;
  input           adc_clk_in_n;
  input   [13:0]  adc_data_in_p;
  input   [13:0]  adc_data_in_n;
  input           adc_data_or_p;
  input           adc_data_or_n;

  output          adc_clk;
  output          adc_rst;
  output          adc_valid_0;
  output          adc_enable_0;
  output  [31:0]  adc_data_0;
  output          adc_valid_1;
  output          adc_enable_1;
  output  [31:0]  adc_data_1;
  input           adc_dovf;
  input           adc_dunf;

  input           delay_clk;

  input           s_axi_aclk;
  input           s_axi_aresetn;
  input           s_axi_awvalid;
  input   [31:0]  s_axi_awaddr;
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
  output          s_axi_arready;
  output          s_axi_rvalid;
  output  [ 1:0]  s_axi_rresp;
  output  [31:0]  s_axi_rdata;
  input           s_axi_rready;
  input   [ 2:0]  s_axi_awprot;
  input   [ 2:0]  s_axi_arprot;


  // internal registers

  reg             up_wack = 1'b0;
  reg     [31:0]  up_rdata = 32'b0;
  reg             up_rack = 1'b0;

  // internal clocks & resets

  wire            up_clk;
  wire            up_rstn;
  wire            delay_rst;

  // internal signals

  wire    [55:0]  adc_rawdata_s;
  wire    [27:0]  adc_rawdata_0_s;
  wire    [27:0]  adc_rawdata_1_s;
  wire            adc_or_0_s;
  wire            adc_or_1_s;
  wire            adc_status_s;
  wire            adc_or_s;
  wire    [14:0]  up_dld_s;
  wire    [74:0]  up_dwdata_s;
  wire    [74:0]  up_drdata_s;
  wire            delay_locked_s;
  wire            up_status_pn_err_s;
  wire            up_status_pn_oos_s;
  wire            up_status_or_s;
  wire    [ 1:0]  up_adc_pn_err_s;
  wire    [ 1:0]  up_adc_pn_oos_s;
  wire    [ 1:0]  up_adc_or_s;
  wire            up_rreq_s;
  wire    [13:0]  up_raddr_s;
  wire    [31:0]  up_rdata_s[0:3];
  wire            up_rack_s[0:3];
  wire            up_wack_s[0:3];
  wire            up_wreq_s;
  wire    [13:0]  up_waddr_s;
  wire    [31:0]  up_wdata_s;
  wire            up_drp_sel_s;
  wire            up_drp_wr_s;
  wire    [11:0]  up_drp_addr_s;
  wire    [15:0]  up_drp_wdata_s;
  wire    [15:0]  up_drp_rdata_s;
  wire            up_drp_ready_s;
  wire            up_drp_locked_s;
  wire            mmcm_rst_s;

  //defaults

  assign up_clk = s_axi_aclk;
  assign up_rstn = s_axi_aresetn;
  assign adc_valid = 1'b1;

  // processor read interface

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_rdata <= 32'd0;
      up_rack <= 1'd0;
      up_wack <= 1'd0;
    end else begin
      up_rdata <= up_rdata_s[0] | up_rdata_s[1] | up_rdata_s[2] | up_rdata_s[3];
      up_rack <= up_rack_s[0] | up_rack_s[1] | up_rack_s[2] | up_rack_s[3];
      up_wack <= up_wack_s[0] | up_wack_s[1] | up_wack_s[2] | up_wack_s[3];
    end
  end

  // device interface instance

  axi_ad9684_if #(
    .DEVICE_TYPE(DEVICE_TYPE),
    .IO_DELAY_GROUP(IO_DELAY_GROUP),
    .OR_STATUS (OR_STATUS))
  i_ad9684_if (
    .adc_clk_in_p (adc_clk_in_p),
    .adc_clk_in_n (adc_clk_in_n),
    .adc_data_in_p (adc_data_in_p),
    .adc_data_in_n (adc_data_in_n),
    .adc_data_or_p (adc_data_or_p),
    .adc_data_or_n (adc_data_or_n),
    .adc_clk (adc_clk),
    .adc_rst (adc_rst),
    .adc_data_a (adc_rawdata_0_s),
    .adc_or_a (adc_or_0_s),
    .adc_data_b (adc_rawdata_1_s),
    .adc_or_b (adc_or_1_s),
    .adc_status (adc_status_s),
    .delay_clk (delay_clk),
    .delay_rst (delay_rst),
    .delay_dload (up_dld_s),
    .delay_wdata (up_dwdata_s),
    .delay_rdata (up_drdata_s),
    .delay_locked (delay_locked_s),
    .mmcm_rst (mmcm_rst_s),
    .up_clk (up_clk),
    .up_rstn (up_rstn),
    .up_drp_sel (up_drp_sel_s),
    .up_drp_wr (up_drp_wr_s),
    .up_drp_addr (up_drp_addr_s),
    .up_drp_wdata (up_drp_wdata_s),
    .up_drp_rdata (up_drp_rdata_s),
    .up_drp_ready (up_drp_ready_s),
    .up_drp_locked (up_drp_locked_s));

  // common processor control instance

  assign up_status_pn_err_s = up_adc_pn_err_s[0] | up_adc_pn_err_s[1];
  assign up_status_pn_oos_s = up_adc_pn_oos_s[0] | up_adc_pn_oos_s[1];
  assign up_status_or_s = up_adc_or_s[0] | up_adc_or_s[1];

  up_adc_common #(
    .ID(ID))
  i_up_adc_common (
    .mmcm_rst (mmcm_rst_s),
    .adc_clk (adc_clk),
    .adc_rst (adc_rst),
    .adc_r1_mode (),
    .adc_ddr_edgesel (),
    .adc_pin_mode (),
    .adc_status (adc_status_s),
    .adc_sync_status (1'd0),
    .adc_status_ovf (adc_dovf),
    .adc_status_unf (adc_dunf),
    .adc_clk_ratio (32'b1),
    .adc_start_code (),
    .adc_sync (),
    .up_status_pn_err (up_status_pn_err_s),
    .up_status_pn_oos (up_status_pn_oos_s),
    .up_status_or (up_status_or_s),
    .up_drp_sel (up_drp_sel_s),
    .up_drp_wr (up_drp_wr_s),
    .up_drp_addr (up_drp_addr_s),
    .up_drp_wdata (up_drp_wdata_s),
    .up_drp_rdata (up_drp_rdata_s),
    .up_drp_ready (up_drp_ready_s),
    .up_drp_locked (up_drp_locked_s),
    .up_usr_chanmax (),
    .adc_usr_chanmax (8'd1),
    .up_adc_gpio_in (32'd0),
    .up_adc_gpio_out (),
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s[0]),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_s[0]),
    .up_rack (up_rack_s[0]));

  // adc channel 0 instance

  axi_ad9684_channel #(
    .CHANNEL_ID (0),
    .Q_OR_I_N (0))
  i_channel_0 (
    .adc_clk (adc_clk),
    .adc_rst (adc_rst),
    .adc_data (adc_rawdata_0_s),
    .adc_data_q (adc_rawdata_1_s),
    .adc_or (adc_or_0_s),
    .adc_dfmt_data (adc_data_0),
    .adc_valid (adc_valid_0),
    .adc_enable (adc_enable_0),
    .up_adc_pn_err (up_adc_pn_err_s[0]),
    .up_adc_pn_oos (up_adc_pn_oos_s[0]),
    .up_adc_or (up_adc_or_s[0]),
    .up_clk (up_clk),
    .up_rstn (up_rstn),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s[1]),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_s[1]),
    .up_rack (up_rack_s[1]));

  // adc channel 1 instance

  axi_ad9684_channel #(
    .CHANNEL_ID (1),
    .Q_OR_I_N (1))
  i_channel_1 (
    .adc_clk (adc_clk),
    .adc_rst (adc_rst),
    .adc_data (adc_rawdata_1_s),
    .adc_data_q (adc_rawdata_0_s),
    .adc_or (adc_or_1_s),
    .adc_dfmt_data (adc_data_1),
    .adc_valid (adc_valid_1),
    .adc_enable (adc_enable_1),
    .up_adc_pn_err (up_adc_pn_err_s[1]),
    .up_adc_pn_oos (up_adc_pn_oos_s[1]),
    .up_adc_or (up_adc_or_s[1] ),
    .up_clk (up_clk),
    .up_rstn (up_rstn),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s[2]),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_s[2]),
    .up_rack (up_rack_s[2]));

  // adc delay control instance

  up_delay_cntrl #(
    .DATA_WIDTH(15))
  i_delay_cntrl (
    .delay_clk (delay_clk),
    .delay_rst (delay_rst),
    .delay_locked (delay_locked_s),
    .up_dld (up_dld_s),
    .up_dwdata (up_dwdata_s),
    .up_drdata (up_drdata_s),
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s[3]),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_s[3]),
    .up_rack (up_rack_s[3]));

  // uP bus interface instance

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
