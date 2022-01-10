/*

Copyright (c) 2015 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * AXI4-Stream Ethernet FCS Generator
 */
module axis_eth_fcs
(
    input  wire        clk,
    input  wire        rst,
    
    /*
     * AXI input
     */
    input  wire [7:0]  input_axis_tdata,
    input  wire        input_axis_tvalid,
    output wire        input_axis_tready,
    input  wire        input_axis_tlast,
    input  wire        input_axis_tuser,
    
    /*
     * FCS output
     */
    output wire [31:0] output_fcs,
    output wire        output_fcs_valid
);

reg [31:0] crc_state = 32'hFFFFFFFF;
reg [31:0] fcs_reg = 0;
reg fcs_valid_reg = 0;

wire [31:0] crc_next;

assign input_axis_tready = 1;
assign output_fcs = fcs_reg;
assign output_fcs_valid = fcs_valid_reg;

eth_crc_8
eth_crc_8_inst (
    .data_in(input_axis_tdata),
    .crc_state(crc_state),
    .crc_next(crc_next)
);

always @(posedge clk) begin
    if (rst) begin
        crc_state <= 32'hFFFFFFFF;
        fcs_reg <= 0;
        fcs_valid_reg <= 0;
    end else begin
        fcs_valid_reg <= 0;
        if (input_axis_tvalid) begin
            if (input_axis_tlast) begin
                crc_state <= 32'hFFFFFFFF;
                fcs_reg <= ~crc_next;
                fcs_valid_reg <= 1;
            end else begin
                crc_state <= crc_next;
            end
        end
    end
end

endmodule
