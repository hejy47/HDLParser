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

`timescale 1ns/100ps

module ad_mem #(

  parameter       DATA_WIDTH = 16,
  parameter       ADDRESS_WIDTH =  5) (

  input                   clka,
  input                   wea,
  input       [AW:0]      addra,
  input       [DW:0]      dina,

  input                   clkb,
  input       [AW:0]      addrb,
  output  reg [DW:0]      doutb);

  localparam      DW = DATA_WIDTH - 1;
  localparam      AW = ADDRESS_WIDTH - 1;

  (* ram_style = "block" *)
  reg     [DW:0]  m_ram[0:((2**ADDRESS_WIDTH)-1)];

  always @(posedge clka) begin
    if (wea == 1'b1) begin
      m_ram[addra] <= dina;
    end
  end

  always @(posedge clkb) begin
    doutb <= m_ram[addrb];
  end

endmodule

// ***************************************************************************
// ***************************************************************************
