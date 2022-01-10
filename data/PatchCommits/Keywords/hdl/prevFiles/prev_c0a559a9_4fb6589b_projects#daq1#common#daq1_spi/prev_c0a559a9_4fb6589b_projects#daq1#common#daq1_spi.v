// ***************************************************************************
// ***************************************************************************
// Copyright 2016(c) Analog Devices, Inc.
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

module daq1_spi (

  spi_csn,
  spi_clk,
  spi_mosi,
  spi_miso,

  spi_sdio);

  // 4 wire

  input           spi_csn;
  input           spi_clk;
  input           spi_mosi;
  output          spi_miso;

  // 3 wire

  inout           spi_sdio;

  // device address

  localparam  [ 7:0]  SPI_SEL_AD9684  = 8'h80;
  localparam  [ 7:0]  SPI_SEL_AD9122  = 8'h81;
  localparam  [ 7:0]  SPI_SEL_AD9523  = 8'h82;
  localparam  [ 7:0]  SPI_SEL_CPLD    = 8'h83;

  // internal registers

  reg     [ 5:0]  spi_count = 6'b0;
  reg             spi_rd_wr_n = 1'b0;
  reg             spi_enable = 1'b0;
  reg     [ 7:0]  spi_device_addr = 8'b0;

  // internal signals

  wire            spi_enable_s;

  // check on rising edge and change on falling edge

  assign spi_enable_s = spi_enable & ~spi_csn;

  always @(posedge spi_clk or posedge spi_csn_s) begin
    if (spi_csn_s == 1'b1) begin
      spi_count <= 6'b0000000;
      spi_rd_wr_n <= 1'b0;
      spi_device_addr <= 8'b00000000;
    end else begin
      spi_count <= spi_count + 1'b1;
      if (spi_count <= 6'd7) begin
        spi_device_addr <= {spi_device_addr[6:0], spi_mosi};
      end
      if (spi_count == 6'd8) begin
        spi_rd_wr_n <= spi_mosi;
      end
    end
  end

  always @(negedge spi_clk or posedge spi_csn_s) begin
    if (spi_csn_s == 1'b1) begin
      spi_enable <= 1'b0;
    end else begin
      if (((spi_device_addr == SPI_SEL_AD9684) && (spi_count == 6'd24)) ||
          ((spi_device_addr == SPI_SEL_AD9122) && (spi_count == 6'd16)) ||
          ((spi_device_addr == SPI_SEL_AD9523) && (spi_count == 6'd24)) ||
          ((spi_device_addr == SPI_SEL_CPLD)   && (spi_count == 6'd16))) begin
        spi_enable <= spi_rd_wr_n;
      end
    end
  end

  // io butter

  IOBUF i_iobuf_sdio (
    .T (spi_enable_s),
    .I (spi_mosi),
    .O (spi_miso),
    .IO (spi_sdio));

endmodule

// ***************************************************************************
// ***************************************************************************
