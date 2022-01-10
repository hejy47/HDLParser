// ***************************************************************************
// ***************************************************************************
// Copyright 2015(c) Analog Devices, Inc.
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
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/1ps

module axi_ad9361_tdd (

  // clock

  clk,
  rst,

  // control signals from the tdd control

  tdd_enable,
  tdd_tx_dp_en,
  tdd_rx_vco_en,
  tdd_tx_vco_en,
  tdd_rx_rf_en,
  tdd_tx_rf_en,

  // status signal

  tdd_status,

  // bus interface

  up_rstn,
  up_clk,
  up_wreq,
  up_waddr,
  up_wdata,
  up_wack,
  up_rreq,
  up_raddr,
  up_rdata,
  up_rack,

  tdd_dbg
);

  input             clk;
  input             rst;

  // control signals from the tdd control

  output            tdd_enable;
  output            tdd_tx_dp_en;
  output            tdd_rx_vco_en;
  output            tdd_tx_vco_en;
  output            tdd_rx_rf_en;
  output            tdd_tx_rf_en;

  input   [ 7:0]    tdd_status;

  // bus interface

  input             up_rstn;
  input             up_clk;
  input             up_wreq;
  input   [13:0]    up_waddr;
  input   [31:0]    up_wdata;
  output            up_wack;
  input             up_rreq;
  input   [13:0]    up_raddr;
  output  [31:0]    up_rdata;
  output            up_rack;

  output  [34:0]    tdd_dbg;

  // internal signals

  wire              rst;
  wire              tdd_enable_s;
  wire              tdd_secondary_s;
  wire   [ 7:0]     tdd_burst_count_s;
  wire              tdd_txnrx_only_en_s;
  wire              tdd_txnrx_only_s;
  wire   [23:0]     tdd_counter_init_s;
  wire   [23:0]     tdd_frame_length_s;
  wire   [23:0]     tdd_vco_rx_on_1_s;
  wire   [23:0]     tdd_vco_rx_off_1_s;
  wire   [23:0]     tdd_vco_tx_on_1_s;
  wire   [23:0]     tdd_vco_tx_off_1_s;
  wire   [23:0]     tdd_rx_on_1_s;
  wire   [23:0]     tdd_rx_off_1_s;
  wire   [23:0]     tdd_tx_on_1_s;
  wire   [23:0]     tdd_tx_off_1_s;
  wire   [23:0]     tdd_tx_dp_on_1_s;
  wire   [23:0]     tdd_tx_dp_off_1_s;
  wire   [23:0]     tdd_vco_rx_on_2_s;
  wire   [23:0]     tdd_vco_rx_off_2_s;
  wire   [23:0]     tdd_vco_tx_on_2_s;
  wire   [23:0]     tdd_vco_tx_off_2_s;
  wire   [23:0]     tdd_rx_on_2_s;
  wire   [23:0]     tdd_rx_off_2_s;
  wire   [23:0]     tdd_tx_on_2_s;
  wire   [23:0]     tdd_tx_off_2_s;
  wire   [23:0]     tdd_tx_dp_on_2_s;
  wire   [23:0]     tdd_tx_dp_off_2_s;

  wire   [23:0]     tdd_counter_status;

  assign tdd_dbg = {tdd_counter_status, tdd_enable, tdd_tx_dp_en,
                    tdd_rx_vco_en, tdd_tx_vco_en, tdd_rx_rf_en, tdd_tx_rf_en};

  assign tdd_enable = tdd_enable_s;

  // instantiations

  up_tdd_cntrl i_up_tdd_cntrl(
    .clk(clk),
    .rst(rst),
    .tdd_enable(tdd_enable_s),
    .tdd_secondary(tdd_secondary_s),
    .tdd_burst_count(tdd_burst_count_s),
    .tdd_txnrx_only_en(tdd_txnrx_only_en_s),
    .tdd_txnrx_only(tdd_txnrx_only_s),
    .tdd_counter_init(tdd_counter_init_s),
    .tdd_frame_length(tdd_frame_length_s),
    .tdd_vco_rx_on_1(tdd_vco_rx_on_1_s),
    .tdd_vco_rx_off_1(tdd_vco_rx_off_1_s),
    .tdd_vco_tx_on_1(tdd_vco_tx_on_1_s),
    .tdd_vco_tx_off_1(tdd_vco_tx_off_1_s),
    .tdd_rx_on_1(tdd_rx_on_1_s),
    .tdd_rx_off_1(tdd_rx_off_1_s),
    .tdd_tx_on_1(tdd_tx_on_1_s),
    .tdd_tx_off_1(tdd_tx_off_1_s),
    .tdd_tx_dp_on_1(tdd_tx_dp_on_1_s),
    .tdd_tx_dp_off_1(tdd_tx_dp_off_1_s),
    .tdd_vco_rx_on_2(tdd_vco_rx_on_2_s),
    .tdd_vco_rx_off_2(tdd_vco_rx_off_2_s),
    .tdd_vco_tx_on_2(tdd_vco_tx_on_2_s),
    .tdd_vco_tx_off_2(tdd_vco_tx_off_2_s),
    .tdd_rx_on_2(tdd_rx_on_2_s),
    .tdd_rx_off_2(tdd_rx_off_2_s),
    .tdd_tx_on_2(tdd_tx_on_2_s),
    .tdd_tx_off_2(tdd_tx_off_2_s),
    .tdd_tx_dp_on_2(tdd_tx_dp_on_2_s),
    .tdd_tx_dp_off_2(tdd_tx_dp_off_2_s),
    .tdd_status(tdd_status),
    .up_rstn(up_rstn),
    .up_clk(up_clk),
    .up_wreq(up_wreq),
    .up_waddr(up_waddr),
    .up_wdata(up_wdata),
    .up_wack(up_wack),
    .up_rreq(up_rreq),
    .up_raddr(up_raddr),
    .up_rdata(up_rdata),
    .up_rack(up_rack));

  ad_tdd_control i_tdd_control(
    .clk(clk),
    .rst(rst),
    .tdd_enable(tdd_enable_s),
    .tdd_secondary(tdd_secondary_s),
    .tdd_counter_init(tdd_counter_init_s),
    .tdd_frame_length(tdd_frame_length_s),
    .tdd_burst_count(tdd_burst_count_s),
    .tdd_txnrx_only_en(tdd_txnrx_only_en_s),
    .tdd_txnrx_only(tdd_txnrx_only_s),
    .tdd_vco_rx_on_1(tdd_vco_rx_on_1_s),
    .tdd_vco_rx_off_1(tdd_vco_rx_off_1_s),
    .tdd_vco_tx_on_1(tdd_vco_tx_on_1_s),
    .tdd_vco_tx_off_1(tdd_vco_tx_off_1_s),
    .tdd_rx_on_1(tdd_rx_on_1_s),
    .tdd_rx_off_1(tdd_rx_off_1_s),
    .tdd_tx_on_1(tdd_tx_on_1_s),
    .tdd_tx_off_1(tdd_tx_off_1_s),
    .tdd_tx_dp_on_1(tdd_tx_dp_on_1_s),
    .tdd_tx_dp_off_1(tdd_tx_dp_off_1_s),
    .tdd_vco_rx_on_2(tdd_vco_rx_on_2_s),
    .tdd_vco_rx_off_2(tdd_vco_rx_off_2_s),
    .tdd_vco_tx_on_2(tdd_vco_tx_on_2_s),
    .tdd_vco_tx_off_2(tdd_vco_tx_off_2_s),
    .tdd_rx_on_2(tdd_rx_on_2_s),
    .tdd_rx_off_2(tdd_rx_off_2_s),
    .tdd_tx_on_2(tdd_tx_on_2_s),
    .tdd_tx_off_2(tdd_tx_off_2_s),
    .tdd_tx_dp_on_2(tdd_tx_dp_on_2_s),
    .tdd_tx_dp_off_2(tdd_tx_dp_off_2_s),
    .tdd_tx_dp_en(tdd_tx_dp_en),
    .tdd_rx_vco_en(tdd_rx_vco_en),
    .tdd_tx_vco_en(tdd_tx_vco_en),
    .tdd_rx_rf_en(tdd_rx_rf_en),
    .tdd_tx_rf_en(tdd_tx_rf_en),
    .tdd_counter_status(tdd_counter_status));

endmodule
