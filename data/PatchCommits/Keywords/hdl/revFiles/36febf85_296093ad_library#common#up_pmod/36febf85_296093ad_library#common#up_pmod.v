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
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module up_pmod (

  pmod_clk,
  pmod_rst,
  pmod_signal_freq,

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
  up_rack);

  // parameters

  localparam      PCORE_VERSION = 32'h00010001;
  parameter       ID = 0;

  input           pmod_clk;
  output          pmod_rst;
  input   [31:0]  pmod_signal_freq;

  // bus interface

  input           up_rstn;
  input           up_clk;
  input           up_wreq;
  input   [13:0]  up_waddr;
  input   [31:0]  up_wdata;
  output          up_wack;
  input           up_rreq;
  input   [13:0]  up_raddr;
  output  [31:0]  up_rdata;
  output          up_rack;

  // internal registers

  reg             up_wack = 'd0;
  reg     [31:0]  up_scratch = 'd0;
  reg             up_resetn = 'd0;
  reg             up_rack = 'd0;
  reg     [31:0]  up_rdata = 'd0;

  // internal signals

  wire    [31:0]  up_pmod_signal_freq_s;
  wire            up_wreq_s;
  wire            up_rreq_s;

  // decode block select

  assign up_wreq_s   = (up_waddr[13:8] == 6'h00) ? up_wreq : 1'b0;
  assign up_rreq_s   = (up_raddr[13:8] == 6'h00) ? up_rreq : 1'b0;
  assign up_preset_s = ~up_resetn;

  // processor write interface

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_wack <= 'd0;
      up_scratch <= 'd0;
      up_resetn <= 'd0;
    end else begin
      up_wack <= up_wreq_s;
      if ((up_wreq_s == 1'b1) && (up_waddr[7:0] == 8'h02)) begin
        up_scratch <= up_wdata;
      end
      if ((up_wreq_s == 1'b1) && (up_waddr[7:0] == 8'h10)) begin
        up_resetn <= up_wdata[0];
      end
    end
  end

  // processor read interface

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_rack <= 'd0;
      up_rdata <= 'd0;
    end else begin
      up_rack <= up_rreq_s;
      if (up_rreq_s == 1'b1) begin
        case (up_raddr[7:0])
          8'h00:  up_rdata <= PCORE_VERSION;
          8'h01:  up_rdata <= ID;
          8'h02:  up_rdata <= up_scratch;
          8'h03:  up_rdata <= up_pmod_signal_freq_s;
          8'h10:  up_rdata <= up_resetn;
          default: up_rdata <= 0;
        endcase
      end else begin
        up_rdata <= 32'd0;
      end
    end
  end

  // resets

  ad_rst i_adc_rst_reg    (.preset(up_preset_s),      .clk(pmod_clk),    .rst(pmod_rst));

  // adc control & status

  up_xfer_status #(.DATA_WIDTH(32)) i_pmod_xfer_status (
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_data_status (up_pmod_signal_freq_s),
    .d_rst (pmod_rst),
    .d_clk (pmod_clk),
    .d_data_status (pmod_signal_freq));

endmodule

// ***************************************************************************
// ***************************************************************************
