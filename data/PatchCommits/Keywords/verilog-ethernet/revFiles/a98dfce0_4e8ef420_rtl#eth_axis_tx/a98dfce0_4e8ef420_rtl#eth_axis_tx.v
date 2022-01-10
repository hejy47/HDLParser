/*

Copyright (c) 2014-2015 Alex Forencich

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
 * AXI4-Stream ethernet frame transmitter (Ethernet frame in, AXI out)
 */
module eth_axis_tx
(
    input  wire        clk,
    input  wire        rst,

    /*
     * Ethernet frame input
     */
    input  wire        input_eth_hdr_valid,
    output wire        input_eth_hdr_ready,
    input  wire [47:0] input_eth_dest_mac,
    input  wire [47:0] input_eth_src_mac,
    input  wire [15:0] input_eth_type,
    input  wire [7:0]  input_eth_payload_tdata,
    input  wire        input_eth_payload_tvalid,
    output wire        input_eth_payload_tready,
    input  wire        input_eth_payload_tlast,
    input  wire        input_eth_payload_tuser,

    /*
     * AXI output
     */
    output wire [7:0]  output_axis_tdata,
    output wire        output_axis_tvalid,
    input  wire        output_axis_tready,
    output wire        output_axis_tlast,
    output wire        output_axis_tuser,

    /*
     * Status signals
     */
    output wire        busy
);

/*

Ethernet frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype                   2 octets

This module receives an Ethernet frame with header fields in parallel along
with the payload in an AXI stream, combines the header with the payload, and
transmits the complete Ethernet frame on the output AXI stream interface.

*/

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_WRITE_HEADER = 2'd1,
    STATE_WRITE_PAYLOAD = 2'd2;

reg [1:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg store_eth_hdr;

reg [7:0] frame_ptr_reg = 8'd0, frame_ptr_next;

reg [47:0] eth_dest_mac_reg = 48'd0;
reg [47:0] eth_src_mac_reg = 48'd0;
reg [15:0] eth_type_reg = 16'd0;

reg input_eth_hdr_ready_reg = 1'b0, input_eth_hdr_ready_next;
reg input_eth_payload_tready_reg = 1'b0, input_eth_payload_tready_next;

reg busy_reg = 1'b0;

// internal datapath
reg [7:0] output_axis_tdata_int;
reg       output_axis_tvalid_int;
reg       output_axis_tready_int_reg = 1'b0;
reg       output_axis_tlast_int;
reg       output_axis_tuser_int;
wire      output_axis_tready_int_early;

assign input_eth_hdr_ready = input_eth_hdr_ready_reg;
assign input_eth_payload_tready = input_eth_payload_tready_reg;

assign busy = busy_reg;

always @* begin
    state_next = STATE_IDLE;

    input_eth_hdr_ready_next = 1'b0;
    input_eth_payload_tready_next = 1'b0;

    store_eth_hdr = 1'b0;

    frame_ptr_next = frame_ptr_reg;

    output_axis_tdata_int = 8'd0;
    output_axis_tvalid_int = 1'b0;
    output_axis_tlast_int = 1'b0;
    output_axis_tuser_int = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for data
            frame_ptr_next = 8'd0;
            input_eth_hdr_ready_next = 1'b1;

            if (input_eth_hdr_ready & input_eth_hdr_valid) begin
                store_eth_hdr = 1'b1;
                input_eth_hdr_ready_next = 1'b0;
                if (output_axis_tready_int_reg) begin
                    output_axis_tvalid_int = 1'b1;
                    output_axis_tdata_int = input_eth_dest_mac[47:40];
                    frame_ptr_next = 1'b1;
                end
                state_next = STATE_WRITE_HEADER;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_WRITE_HEADER: begin
            // write header
            if (output_axis_tready_int_reg) begin
                frame_ptr_next = frame_ptr_reg+1;
                output_axis_tvalid_int = 1'b1;
                state_next = STATE_WRITE_HEADER;
                case (frame_ptr_reg)
                    8'h00: output_axis_tdata_int = eth_dest_mac_reg[47:40];
                    8'h01: output_axis_tdata_int = eth_dest_mac_reg[39:32];
                    8'h02: output_axis_tdata_int = eth_dest_mac_reg[31:24];
                    8'h03: output_axis_tdata_int = eth_dest_mac_reg[23:16];
                    8'h04: output_axis_tdata_int = eth_dest_mac_reg[15: 8];
                    8'h05: output_axis_tdata_int = eth_dest_mac_reg[ 7: 0];
                    8'h06: output_axis_tdata_int = eth_src_mac_reg[47:40];
                    8'h07: output_axis_tdata_int = eth_src_mac_reg[39:32];
                    8'h08: output_axis_tdata_int = eth_src_mac_reg[31:24];
                    8'h09: output_axis_tdata_int = eth_src_mac_reg[23:16];
                    8'h0A: output_axis_tdata_int = eth_src_mac_reg[15: 8];
                    8'h0B: output_axis_tdata_int = eth_src_mac_reg[ 7: 0];
                    8'h0C: output_axis_tdata_int = eth_type_reg[15: 8];
                    8'h0D: begin
                        output_axis_tdata_int = eth_type_reg[ 7: 0];
                        input_eth_payload_tready_next = output_axis_tready_int_early;
                        state_next = STATE_WRITE_PAYLOAD;
                    end
                endcase
            end else begin
                state_next = STATE_WRITE_HEADER;
            end
        end
        STATE_WRITE_PAYLOAD: begin
            // write payload
            input_eth_payload_tready_next = output_axis_tready_int_early;

            output_axis_tdata_int = input_eth_payload_tdata;
            output_axis_tvalid_int = input_eth_payload_tvalid;
            output_axis_tlast_int = input_eth_payload_tlast;
            output_axis_tuser_int = input_eth_payload_tuser;

            if (input_eth_payload_tready & input_eth_payload_tvalid) begin
                // word transfer through
                if (input_eth_payload_tlast) begin
                    input_eth_payload_tready_next = 1'b0;
                    input_eth_hdr_ready_next = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WRITE_PAYLOAD;
                end
            end else begin
                state_next = STATE_WRITE_PAYLOAD;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        frame_ptr_reg <= 8'd0;
        input_eth_hdr_ready_reg <= 1'b0;
        input_eth_payload_tready_reg <= 1'b0;
        busy_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        frame_ptr_reg <= frame_ptr_next;

        input_eth_hdr_ready_reg <= input_eth_hdr_ready_next;

        input_eth_payload_tready_reg <= input_eth_payload_tready_next;

        busy_reg <= state_next != STATE_IDLE;
    end

    // datapath
    if (store_eth_hdr) begin
        eth_dest_mac_reg <= input_eth_dest_mac;
        eth_src_mac_reg <= input_eth_src_mac;
        eth_type_reg <= input_eth_type;
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
