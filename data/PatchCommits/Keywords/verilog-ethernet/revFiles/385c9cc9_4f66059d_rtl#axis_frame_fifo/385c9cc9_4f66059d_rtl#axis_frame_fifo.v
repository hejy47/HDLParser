/*

Copyright (c) 2014-2016 Alex Forencich

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
 * AXI4-Stream frame FIFO
 */
module axis_frame_fifo #
(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 8,
    parameter DROP_WHEN_FULL = 0
)
(
    input  wire                   clk,
    input  wire                   rst,
    
    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]  input_axis_tdata,
    input  wire                   input_axis_tvalid,
    output wire                   input_axis_tready,
    input  wire                   input_axis_tlast,
    input  wire                   input_axis_tuser,
    
    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]  output_axis_tdata,
    output wire                   output_axis_tvalid,
    input  wire                   output_axis_tready,
    output wire                   output_axis_tlast,

    /*
     * Status
     */
    output wire                   overflow,
    output wire                   bad_frame,
    output wire                   good_frame
);

reg [ADDR_WIDTH:0] wr_ptr_reg = {ADDR_WIDTH+1{1'b0}}, wr_ptr_next;
reg [ADDR_WIDTH:0] wr_ptr_cur_reg = {ADDR_WIDTH+1{1'b0}}, wr_ptr_cur_next;
reg [ADDR_WIDTH:0] rd_ptr_reg = {ADDR_WIDTH+1{1'b0}}, rd_ptr_next;

reg [DATA_WIDTH+1-1:0] mem[(2**ADDR_WIDTH)-1:0];
reg [DATA_WIDTH+1-1:0] mem_read_data_reg = {DATA_WIDTH+2{1'b0}};
wire [DATA_WIDTH+1-1:0] mem_write_data;

reg output_axis_tvalid_reg = 1'b0, output_axis_tvalid_next;

// full when first MSB different but rest same
wire full = ((wr_ptr_reg[ADDR_WIDTH] != rd_ptr_reg[ADDR_WIDTH]) &&
             (wr_ptr_reg[ADDR_WIDTH-1:0] == rd_ptr_reg[ADDR_WIDTH-1:0]));
// empty when pointers match exactly
wire empty = wr_ptr_reg == rd_ptr_reg;
// overflow within packet
wire full_cur = ((wr_ptr_reg[ADDR_WIDTH] != wr_ptr_cur_reg[ADDR_WIDTH]) &&
                 (wr_ptr_reg[ADDR_WIDTH-1:0] == wr_ptr_cur_reg[ADDR_WIDTH-1:0]));

// control signals
reg write;
reg read;

reg drop_frame_reg = 1'b0, drop_frame_next;
reg overflow_reg = 1'b0, overflow_next;
reg bad_frame_reg = 1'b0, bad_frame_next;
reg good_frame_reg = 1'b0, good_frame_next;

assign input_axis_tready = (~full | DROP_WHEN_FULL);

assign output_axis_tvalid = output_axis_tvalid_reg;

assign mem_write_data = {input_axis_tlast, input_axis_tdata};
assign {output_axis_tlast, output_axis_tdata} = mem_read_data_reg;

assign overflow = overflow_reg;
assign bad_frame = bad_frame_reg;
assign good_frame = good_frame_reg;

// Write logic
always @* begin
    write = 1'b0;

    drop_frame_next = 1'b0;
    overflow_next = 1'b0;
    bad_frame_next = 1'b0;
    good_frame_next = 1'b0;

    wr_ptr_next = wr_ptr_reg;
    wr_ptr_cur_next = wr_ptr_cur_reg;

    if (input_axis_tvalid) begin
        // input data valid
        if (~full | DROP_WHEN_FULL) begin
            // not full, perform write
            if (full | full_cur | drop_frame_reg) begin
                // full, packet overflow, or currently dropping frame
                // drop frame
                drop_frame_next = 1'b1;
                if (input_axis_tlast) begin
                    // end of frame, reset write pointer
                    wr_ptr_cur_next = wr_ptr_reg;
                    drop_frame_next = 1'b0;
                    overflow_next = 1'b1;
                end
            end else begin
                write = 1'b1;
                wr_ptr_cur_next = wr_ptr_cur_reg + 1;
                if (input_axis_tlast) begin
                    // end of frame
                    if (input_axis_tuser) begin
                        // bad packet, reset write pointer
                        wr_ptr_cur_next = wr_ptr_reg;
                        bad_frame_next = 1'b1;
                    end else begin
                        // good packet, update write pointer
                        wr_ptr_next = wr_ptr_cur_reg + 1;
                        good_frame_next = 1'b1;
                    end
                end
            end
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_cur_reg <= {ADDR_WIDTH+1{1'b0}};

        drop_frame_reg <= 1'b0;
        overflow_reg <= 1'b0;
        bad_frame_reg <= 1'b0;
        good_frame_reg <= 1'b0;
    end else begin
        wr_ptr_reg <= wr_ptr_next;
        wr_ptr_cur_reg <= wr_ptr_cur_next;

        drop_frame_reg <= drop_frame_next;
        overflow_reg <= overflow_next;
        bad_frame_reg <= bad_frame_next;
        good_frame_reg <= good_frame_next;
    end

    if (write) begin
        mem[wr_ptr_cur_reg[ADDR_WIDTH-1:0]] <= mem_write_data;
    end
end

// Read logic
always @* begin
    read = 1'b0;

    rd_ptr_next = rd_ptr_reg;

    output_axis_tvalid_next = output_axis_tvalid_reg;

    if (output_axis_tready | ~output_axis_tvalid) begin
        // output data not valid OR currently being transferred
        if (~empty) begin
            // not empty, perform read
            read = 1'b1;
            output_axis_tvalid_next = 1'b1;
            rd_ptr_next = rd_ptr_reg + 1;
        end else begin
            // empty, invalidate
            output_axis_tvalid_next = 1'b0;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        rd_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        output_axis_tvalid_reg <= 1'b0;
    end else begin
        rd_ptr_reg <= rd_ptr_next;
        output_axis_tvalid_reg <= output_axis_tvalid_next;
    end

    if (read) begin
        mem_read_data_reg <= mem[rd_ptr_reg[ADDR_WIDTH-1:0]];
    end
end

endmodule
