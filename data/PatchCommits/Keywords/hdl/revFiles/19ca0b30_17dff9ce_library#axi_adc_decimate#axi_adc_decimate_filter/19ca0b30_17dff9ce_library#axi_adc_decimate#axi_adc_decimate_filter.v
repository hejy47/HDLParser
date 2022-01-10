// ***************************************************************************
// ***************************************************************************
// Copyright 2017(c) Analog Devices, Inc.
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


module axi_adc_decimate_filter (
  input                 adc_clk,
  input                 adc_rst,

  input       [31:0]    decimation_ratio,
  input       [ 2:0]    filter_mask,

  input                 adc_valid_a,
  input                 adc_valid_b,
  input       [11:0]    adc_data_a,
  input       [11:0]    adc_data_b,

  output reg  [15:0]    adc_dec_data_a,
  output reg  [15:0]    adc_dec_data_b,
  output reg            adc_dec_valid_a,
  output reg            adc_dec_valid_b
);

  // internal signals

  reg     [31:0]    decimation_counter;

  reg               adc_dec_valid_a_filter;
  reg               adc_dec_valid_b_filter;

  reg     [4:0]     filter_enable = 5'h00;

  wire    [25:0]    adc_fir_data_a;
  wire              adc_fir_valid_a;
  wire    [25:0]    adc_fir_data_b;
  wire              adc_fir_valid_b;

  wire    [11:0]    adc_cic_data_a;
  wire              adc_cic_valid_a;
  wire    [11:0]    adc_cic_data_b;
  wire              adc_cic_valid_b;

  cic_decim cic_decimation_a (
    .clk(adc_clk),
    .clk_enable(adc_valid_a),
    .filter_enable(filter_enable),
    .reset(adc_rst),
    .filter_in(adc_data_a[11:0]),
    .rate_sel(filter_mask),
    .filter_out(adc_cic_data_a),
    .ce_out(adc_cic_valid_a));

  cic_decim cic_decimation_b (
    .clk(adc_clk),
    .clk_enable(adc_valid_b),
    .filter_enable(filter_enable),
    .reset(adc_rst),
    .filter_in(adc_data_b[11:0]),
    .rate_sel(filter_mask),
    .filter_out(adc_cic_data_b),
    .ce_out(adc_cic_valid_b));

  fir_decim fir_decimation_a (
    .clk(adc_clk),
    .clk_enable(adc_cic_valid_a),
    .reset(adc_rst),
    .filter_in(adc_cic_data_a),
    .filter_out(adc_fir_data_a),
    .ce_out(adc_fir_valid_a));

  fir_decim fir_decimation_b (
    .clk(adc_clk),
    .clk_enable(adc_cic_valid_b),
    .reset(adc_rst),
    .filter_in(adc_cic_data_b),
    .filter_out(adc_fir_data_b),
    .ce_out(adc_fir_valid_b));

  always @(posedge adc_clk) begin
    case (filter_mask)
      3'h1: filter_enable <= 5'b00001;
      3'h2: filter_enable <= 5'b00011;
      3'h3: filter_enable <= 5'b00111;
      3'h6: filter_enable <= 5'b01111;
      3'h7: filter_enable <= 5'b11111;
      default: filter_enable <= 5'b00000;
    endcase
  end

  always @(*) begin
    case (filter_enable[0])
      1'b0: adc_dec_data_a = adc_data_a;
      default: adc_dec_data_a = {adc_fir_data_a[25], adc_fir_data_a[25:11]};
    endcase

    case (filter_enable[0])
      1'b0: adc_dec_valid_a_filter = adc_valid_a;
      default: adc_dec_valid_a_filter = adc_fir_valid_a;
    endcase

     case (filter_enable[0])
      1'b0: adc_dec_data_b = adc_data_b;
      default adc_dec_data_b = {adc_fir_data_b[25], adc_fir_data_b[25:11]};
    endcase

    case (filter_enable[0])
      1'b0: adc_dec_valid_b_filter = adc_valid_b;
      default: adc_dec_valid_b_filter = adc_fir_valid_b;
    endcase
  end

  always @(posedge adc_clk) begin
    if (adc_rst == 1'b1) begin
      decimation_counter <= 32'b0;
      adc_dec_valid_a <= 1'b0;
      adc_dec_valid_b <= 1'b0;
    end else begin
      if (adc_dec_valid_a_filter == 1'b1) begin
        if (decimation_counter < decimation_ratio) begin
          decimation_counter <= decimation_counter + 1;
          adc_dec_valid_a <= 1'b0;
          adc_dec_valid_b <= 1'b0;
        end else begin
          decimation_counter <= 0;
          adc_dec_valid_a <= 1'b1;
          adc_dec_valid_b <= 1'b1;
        end
      end else begin
          adc_dec_valid_a <= 1'b0;
          adc_dec_valid_b <= 1'b0;
      end
    end
  end


endmodule
