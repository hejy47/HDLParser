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
 * AXI4-Stream Ethernet FCS inserter
 */
module axis_eth_fcs_insert #
(
    parameter ENABLE_PADDING = 0,
    parameter MIN_FRAME_LENGTH = 64
)
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
     * AXI output
     */
    output wire [7:0]  output_axis_tdata,
    output wire        output_axis_tvalid,
    input  wire        output_axis_tready,
    output wire        output_axis_tlast,
    output wire        output_axis_tuser,

    /*
     * Status
     */
    output wire        busy
);

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_PAYLOAD = 2'd1,
    STATE_PAD = 2'd2,
    STATE_FCS = 2'd3;

reg [1:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg reset_crc;
reg update_crc;

reg [15:0] frame_ptr_reg = 16'd0, frame_ptr_next;

reg busy_reg = 1'b0;

reg input_axis_tready_reg = 1'b0, input_axis_tready_next;

reg [31:0] crc_state = 32'hFFFFFFFF;
wire [31:0] crc_next;

// internal datapath
reg [7:0] output_axis_tdata_int;
reg       output_axis_tvalid_int;
reg       output_axis_tready_int_reg = 1'b0;
reg       output_axis_tlast_int;
reg       output_axis_tuser_int;
wire      output_axis_tready_int_early;

assign input_axis_tready = input_axis_tready_reg;

assign busy = busy_reg;

eth_crc_8
eth_crc_8_inst (
    .data_in(output_axis_tdata_int),
    .crc_state(crc_state),
    .crc_next(crc_next)
);

always @* begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;
    update_crc = 1'b0;

    frame_ptr_next = frame_ptr_reg;

    input_axis_tready_next = 1'b0;

    output_axis_tdata_int = 8'd0;
    output_axis_tvalid_int = 1'b0;
    output_axis_tlast_int = 1'b0;
    output_axis_tuser_int = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for data
            input_axis_tready_next = output_axis_tready_int_early;
            frame_ptr_next = 16'd0;
            reset_crc = 1'b1;

            output_axis_tdata_int = input_axis_tdata;
            output_axis_tvalid_int = input_axis_tvalid;
            output_axis_tlast_int = 1'b0;
            output_axis_tuser_int = 1'b0;

            if (input_axis_tready & input_axis_tvalid) begin
                frame_ptr_next = 16'd1;
                reset_crc = 1'b0;
                update_crc = 1'b1;
                if (input_axis_tlast) begin
                    if (input_axis_tuser) begin
                        output_axis_tlast_int = 1'b1;
                        output_axis_tuser_int = 1'b1;
                        reset_crc = 1'b1;
                        frame_ptr_next = 16'd0;
                        state_next = STATE_IDLE;
                    end else begin
                        input_axis_tready_next = 1'b0;
                        if (ENABLE_PADDING && frame_ptr_reg < MIN_FRAME_LENGTH-5) begin
                            state_next = STATE_PAD;
                        end else begin
                            frame_ptr_next = 16'd0;
                            state_next = STATE_FCS;
                        end
                    end
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_PAYLOAD: begin
            // transfer payload
            input_axis_tready_next = output_axis_tready_int_early;

            output_axis_tdata_int = input_axis_tdata;
            output_axis_tvalid_int = input_axis_tvalid;
            output_axis_tlast_int = 1'b0;
            output_axis_tuser_int = 1'b0;

            if (input_axis_tready & input_axis_tvalid) begin
                frame_ptr_next = frame_ptr_reg + 16'd1;
                update_crc = 1'b1;
                if (input_axis_tlast) begin
                    if (input_axis_tuser) begin
                        output_axis_tlast_int = 1'b1;
                        output_axis_tuser_int = 1'b1;
                        reset_crc = 1'b1;
                        frame_ptr_next = 16'd0;
                        state_next = STATE_IDLE;
                    end else begin
                        input_axis_tready_next = 1'b0;
                        if (ENABLE_PADDING && frame_ptr_reg < MIN_FRAME_LENGTH-5) begin
                            state_next = STATE_PAD;
                        end else begin
                            frame_ptr_next = 16'd0;
                            state_next = STATE_FCS;
                        end
                    end
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end else begin
                state_next = STATE_PAYLOAD;
            end
        end
        STATE_PAD: begin
            // insert padding
            input_axis_tready_next = 1'b0;

            output_axis_tdata_int = 8'd0;
            output_axis_tvalid_int = 1'b1;
            output_axis_tlast_int = 1'b0;
            output_axis_tuser_int = 1'b0;

            if (output_axis_tready_int_reg) begin
                frame_ptr_next = frame_ptr_reg + 16'd1;
                update_crc = 1'b1;
                if (frame_ptr_reg < MIN_FRAME_LENGTH-5) begin
                    state_next = STATE_PAD;
                end else begin
                    frame_ptr_next = 16'd0;
                    state_next = STATE_FCS;
                end
            end else begin
                state_next = STATE_PAD;
            end
        end
        STATE_FCS: begin
            // send FCS
            input_axis_tready_next = 1'b0;

            case (frame_ptr_reg)
                2'd0: output_axis_tdata_int = ~crc_state[7:0];
                2'd1: output_axis_tdata_int = ~crc_state[15:8];
                2'd2: output_axis_tdata_int = ~crc_state[23:16];
                2'd3: output_axis_tdata_int = ~crc_state[31:24];
            endcase
            output_axis_tvalid_int = 1'b1;
            output_axis_tlast_int = 1'b0;
            output_axis_tuser_int = 1'b0;

            if (output_axis_tready_int_reg) begin
                frame_ptr_next = frame_ptr_reg + 16'd1;

                if (frame_ptr_reg < 16'd3) begin
                    state_next = STATE_FCS;
                end else begin
                    reset_crc = 1'b1;
                    frame_ptr_next = 16'd0;
                    output_axis_tlast_int = 1'b1;
                    input_axis_tready_next = output_axis_tready_int_early;
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_FCS;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        
        frame_ptr_reg <= 1'b0;
        
        input_axis_tready_reg <= 1'b0;

        busy_reg <= 1'b0;

        crc_state <= 32'hFFFFFFFF;
    end else begin
        state_reg <= state_next;

        frame_ptr_reg <= frame_ptr_next;

        input_axis_tready_reg <= input_axis_tready_next;

        busy_reg <= state_next != STATE_IDLE;

        // datapath
        if (reset_crc) begin
            crc_state <= 32'hFFFFFFFF;
        end else if (update_crc) begin
            crc_state <= crc_next;
        end
    end
end

// output datapath logic
reg [7:0] output_axis_tdata_reg = 8'd0;
reg       output_axis_tvalid_reg = 1'b0, output_axis_tvalid_next;
reg       output_axis_tlast_reg = 1'b0;
reg       output_axis_tuser_reg = 1'b0;

reg [7:0] temp_axis_tdata_reg = 8'd0;
reg       temp_axis_tvalid_reg = 1'b0, temp_axis_tvalid_next;
reg       temp_axis_tlast_reg = 1'b0;
reg       temp_axis_tuser_reg = 1'b0;

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign output_axis_tdata = output_axis_tdata_reg;
assign output_axis_tvalid = output_axis_tvalid_reg;
assign output_axis_tlast = output_axis_tlast_reg;
assign output_axis_tuser = output_axis_tuser_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign output_axis_tready_int_early = output_axis_tready | (~temp_axis_tvalid_reg & (~output_axis_tvalid_reg | ~output_axis_tvalid_int));

always @* begin
    // transfer sink ready state to source
    output_axis_tvalid_next = output_axis_tvalid_reg;
    temp_axis_tvalid_next = temp_axis_tvalid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;
    
    if (output_axis_tready_int_reg) begin
        // input is ready
        if (output_axis_tready | ~output_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            output_axis_tvalid_next = output_axis_tvalid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_axis_tvalid_next = output_axis_tvalid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (output_axis_tready) begin
        // input is not ready, but output is ready
        output_axis_tvalid_next = temp_axis_tvalid_reg;
        temp_axis_tvalid_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        output_axis_tvalid_reg <= 1'b0;
        output_axis_tready_int_reg <= 1'b0;
        temp_axis_tvalid_reg <= 1'b0;
    end else begin
        output_axis_tvalid_reg <= output_axis_tvalid_next;
        output_axis_tready_int_reg <= output_axis_tready_int_early;
        temp_axis_tvalid_reg <= temp_axis_tvalid_next;
    end

    // datapath
    if (store_axis_int_to_output) begin
        output_axis_tdata_reg <= output_axis_tdata_int;
        output_axis_tlast_reg <= output_axis_tlast_int;
        output_axis_tuser_reg <= output_axis_tuser_int;
    end else if (store_axis_temp_to_output) begin
        output_axis_tdata_reg <= temp_axis_tdata_reg;
        output_axis_tlast_reg <= temp_axis_tlast_reg;
        output_axis_tuser_reg <= temp_axis_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_axis_tdata_reg <= output_axis_tdata_int;
        temp_axis_tlast_reg <= output_axis_tlast_int;
        temp_axis_tuser_reg <= output_axis_tuser_int;
    end
end

endmodule
