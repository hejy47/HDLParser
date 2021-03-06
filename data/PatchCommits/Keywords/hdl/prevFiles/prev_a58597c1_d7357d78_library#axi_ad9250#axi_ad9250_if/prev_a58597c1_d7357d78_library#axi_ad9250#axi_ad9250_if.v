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

module axi_ad9250_if (

  // jesd interface 
  // rx_clk is (line-rate/40)

  rx_clk,
  rx_sof,
  rx_data,

  // adc data output

  adc_clk,
  adc_rst,
  adc_data_a,
  adc_data_b,
  adc_or_a,
  adc_or_b,
  adc_status);

  // parameters

  parameter DEVICE_TYPE = 0;

  // jesd interface 
  // rx_clk is (line-rate/40)

  input           rx_clk;
  input  [  3:0]  rx_sof;
  input   [63:0]  rx_data;

  // adc data output

  output          adc_clk;
  input           adc_rst;
  output  [27:0]  adc_data_a;
  output  [27:0]  adc_data_b;
  output          adc_or_a;
  output          adc_or_b;
  output          adc_status;

  // internal registers

  reg             adc_status = 'd0;

  // internal signals

  wire    [15:0]  adc_data_a_s1_s;
  wire    [15:0]  adc_data_a_s0_s;
  wire    [15:0]  adc_data_b_s1_s;
  wire    [15:0]  adc_data_b_s0_s;

  // adc clock is the reference clock

  assign adc_clk = rx_clk;
  assign adc_or_a = 1'b0;
  assign adc_or_b = 1'b0;

  // adc channels

  assign adc_data_a = {adc_data_a_s1_s[13:0], adc_data_a_s0_s[13:0]};
  assign adc_data_b = {adc_data_b_s1_s[13:0], adc_data_b_s0_s[13:0]};

  // data multiplex

  assign adc_data_a_s1_s = {rx_data_s[25:24], rx_data_s[23:16], rx_data_s[31:26]}; 
  assign adc_data_a_s0_s = {rx_data_s[ 9: 8], rx_data_s[ 7: 0], rx_data_s[15:10]};
  assign adc_data_b_s1_s = {rx_data_s[57:56], rx_data_s[55:48], rx_data_s[63:58]}; 
  assign adc_data_b_s0_s = {rx_data_s[41:40], rx_data_s[39:32], rx_data_s[47:42]};

  // status

  always @(posedge rx_clk) begin
    if (adc_rst == 1'b1) begin
      adc_status <= 1'b0;
    end else begin
      adc_status <= 1'b1;
    end
  end

  // frame-alignment

  genvar n;

  generate
  for (n = 0; n < 4; n = n + 1) begin: g_xcvr_if
  ad_xcvr_rx_if #(.DEVICE_TYPE (DEVICE_TYPE)) i_xcvr_if (
    .rx_clk (rx_clk),
    .rx_ip_sof (rx_sof),
    .rx_ip_data (rx_data[((n*32)+31):(n*32)]),
    .rx_sof (),
    .rx_data (rx_data_s[((n*32)+31):(n*32)]));
  end
  endgenerate

endmodule

// ***************************************************************************
// ***************************************************************************

