// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2017 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsabilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

module dmac_address_generator #(

  parameter ID_WIDTH = 3,
  parameter DMA_DATA_WIDTH = 64,
  parameter DMA_ADDR_WIDTH = 32,
  parameter BEATS_PER_BURST_WIDTH = 4,
  parameter BYTES_PER_BEAT_WIDTH = $clog2(DMA_DATA_WIDTH/8),
  parameter LENGTH_WIDTH = 8)(

  input                        clk,
  input                        resetn,

  input                        req_valid,
  output reg                   req_ready,
  input [DMA_ADDR_WIDTH-1:BYTES_PER_BEAT_WIDTH] req_address,
  input [BEATS_PER_BURST_WIDTH-1:0] req_last_burst_length,

  output reg [ID_WIDTH-1:0]  id,
  input [ID_WIDTH-1:0]       request_id,
  input                        sync_id,

  input                        eot,

  input                        enable,
  input                        pause,
  output reg                   enabled,

  input                        addr_ready,
  output reg                   addr_valid,
  output     [DMA_ADDR_WIDTH-1:0] addr,
  output     [LENGTH_WIDTH-1:0] len,
  output     [ 2:0]            size,
  output     [ 1:0]            burst,
  output     [ 2:0]            prot,
  output     [ 3:0]            cache
);

localparam MAX_BEATS_PER_BURST = 2**(BEATS_PER_BURST_WIDTH);

`include "inc_id.h"

assign burst = 2'b01;
assign prot = 3'b000;
assign cache = 4'b0011;
assign len = length;
assign size = $clog2(DMA_DATA_WIDTH/8);

reg [LENGTH_WIDTH-1:0] length = 'h0;
reg [DMA_ADDR_WIDTH-BYTES_PER_BEAT_WIDTH-1:0] address = 'h00;
reg [BEATS_PER_BURST_WIDTH-1:0] last_burst_len = 'h00;
assign addr = {address, {BYTES_PER_BEAT_WIDTH{1'b0}}};

reg addr_valid_d1;
reg last = 1'b0;

// If we already asserted addr_valid we have to wait until it is accepted before
// we can disable the address generator.
always @(posedge clk) begin
  if (resetn == 1'b0) begin
    enabled <= 1'b0;
  end else begin
    if (enable)
      enabled <= 1'b1;
    else if (~addr_valid)
      enabled <= 1'b0;
  end
end

always @(posedge clk) begin
  if (addr_valid == 1'b0) begin
    if (eot == 1'b1)
      length <= last_burst_len;
    else
      length <= MAX_BEATS_PER_BURST - 1;
  end
end

always @(posedge clk) begin
  if (resetn == 1'b0) begin
    last <= 1'b0;
  end else if (addr_valid == 1'b0) begin
    last <= eot;
  end
end

always @(posedge clk) begin
  if (resetn == 1'b0) begin
    address <= 'h00;
    last_burst_len <= 'h00;
    req_ready <= 1'b1;
    addr_valid <= 1'b0;
  end else begin
    if (~enabled) begin
      req_ready <= 1'b1;
    end else if (req_ready) begin
      if (req_valid && enable) begin
        address <= req_address;
        req_ready <= 1'b0;
        last_burst_len <= req_last_burst_length;
      end
    end else begin
      if (addr_valid && addr_ready) begin
        address <= address + MAX_BEATS_PER_BURST;
        addr_valid <= 1'b0;
        if (last)
          req_ready <= 1'b1;
      end else if (id != request_id && enable) begin
        addr_valid <= 1'b1;
      end
    end
  end
end

always @(posedge clk) begin
  if (resetn == 1'b0) begin
    id <='h0;
    addr_valid_d1 <= 1'b0;
  end else begin
    addr_valid_d1 <= addr_valid;
    if ((addr_valid && ~addr_valid_d1) ||
      (sync_id && id != request_id))
      id <= inc_id(id);

  end
end

endmodule
