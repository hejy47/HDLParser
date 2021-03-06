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
 * AXI4-Stream ethernet frame receiver (AXI in, Ethernet frame out, 64 bit datapath)
 */
module eth_axis_rx_64
(
    input  wire        clk,
    input  wire        rst,

    /*
     * AXI input
     */
    input  wire [63:0] input_axis_tdata,
    input  wire [7:0]  input_axis_tkeep,
    input  wire        input_axis_tvalid,
    output wire        input_axis_tready,
    input  wire        input_axis_tlast,
    input  wire        input_axis_tuser,

    /*
     * Ethernet frame output
     */
    output wire        output_eth_hdr_valid,
    input  wire        output_eth_hdr_ready,
    output wire [47:0] output_eth_dest_mac,
    output wire [47:0] output_eth_src_mac,
    output wire [15:0] output_eth_type,
    output wire [63:0] output_eth_payload_tdata,
    output wire [7:0]  output_eth_payload_tkeep,
    output wire        output_eth_payload_tvalid,
    input  wire        output_eth_payload_tready,
    output wire        output_eth_payload_tlast,
    output wire        output_eth_payload_tuser,

    /*
     * Status signals
     */
    output wire        busy,
    output wire        error_header_early_termination
);

/*

Ethernet frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype                   2 octets

This module receives an Ethernet frame on an AXI stream interface, decodes
and strips the headers, then produces the header fields in parallel along
with the payload in a separate AXI stream.

*/

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_READ_HEADER = 3'd1,
    STATE_READ_PAYLOAD = 3'd2;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg store_hdr_word_0;
reg store_hdr_word_1;

reg flush_save;
reg transfer_in_save;

reg [7:0] frame_ptr_reg = 8'd0, frame_ptr_next;

reg input_axis_tready_reg = 1'b0, input_axis_tready_next;

reg output_eth_hdr_valid_reg = 1'b0, output_eth_hdr_valid_next;
reg [47:0] output_eth_dest_mac_reg = 48'd0;
reg [47:0] output_eth_src_mac_reg = 48'd0;
reg [15:0] output_eth_type_reg = 16'd0;

reg busy_reg = 1'b0;
reg error_header_early_termination_reg = 1'b0, error_header_early_termination_next;

reg [63:0] save_axis_tdata_reg = 64'd0;
reg [7:0] save_axis_tkeep_reg = 8'd0;
reg save_axis_tlast_reg = 1'b0;
reg save_axis_tuser_reg = 1'b0;

reg [63:0] shift_axis_tdata;
reg [7:0] shift_axis_tkeep;
reg shift_axis_tvalid;
reg shift_axis_tlast;
reg shift_axis_tuser;
reg shift_axis_input_tready;
reg shift_axis_extra_cycle;

// internal datapath
reg [63:0] output_eth_payload_tdata_int;
reg [7:0]  output_eth_payload_tkeep_int;
reg        output_eth_payload_tvalid_int;
reg        output_eth_payload_tready_int_reg = 1'b0;
reg        output_eth_payload_tlast_int;
reg        output_eth_payload_tuser_int;
wire       output_eth_payload_tready_int_early;

assign input_axis_tready = input_axis_tready_reg;

assign output_eth_hdr_valid = output_eth_hdr_valid_reg;
assign output_eth_dest_mac = output_eth_dest_mac_reg;
assign output_eth_src_mac = output_eth_src_mac_reg;
assign output_eth_type = output_eth_type_reg;

assign busy = busy_reg;
assign error_header_early_termination = error_header_early_termination_reg;

always @* begin
    shift_axis_tdata[15:0] = save_axis_tdata_reg[63:48];
    shift_axis_tkeep[1:0] = save_axis_tkeep_reg[7:6];
    shift_axis_extra_cycle = save_axis_tlast_reg & (save_axis_tkeep_reg[7:6] != 0);

    if (shift_axis_extra_cycle) begin
        shift_axis_tdata[63:16] = 48'd0;
        shift_axis_tkeep[7:2] = 6'd0;
        shift_axis_tvalid = 1'b1;
        shift_axis_tlast = save_axis_tlast_reg;
        shift_axis_tuser = save_axis_tuser_reg;
        shift_axis_input_tready = flush_save;
    end else begin
        shift_axis_tdata[63:16] = input_axis_tdata[47:0];
        shift_axis_tkeep[7:2] = input_axis_tkeep[5:0];
        shift_axis_tvalid = input_axis_tvalid;
        shift_axis_tlast = (input_axis_tlast & (input_axis_tkeep[7:6] == 0));
        shift_axis_tuser = (input_axis_tuser & (input_axis_tkeep[7:6] == 0));
        shift_axis_input_tready = ~(input_axis_tlast & input_axis_tvalid & transfer_in_save);
    end
end

always @* begin
    state_next = STATE_IDLE;

    input_axis_tready_next = 1'b0;

    flush_save = 1'b0;
    transfer_in_save = 1'b0;

    store_hdr_word_0 = 1'b0;
    store_hdr_word_1 = 1'b0;

    frame_ptr_next = frame_ptr_reg;

    output_eth_hdr_valid_next = output_eth_hdr_valid_reg & ~output_eth_hdr_ready;

    error_header_early_termination_next = 1'b0;

    output_eth_payload_tdata_int = 64'd0;
    output_eth_payload_tkeep_int = 8'd0;
    output_eth_payload_tvalid_int = 1'b0;
    output_eth_payload_tlast_int = 1'b0;
    output_eth_payload_tuser_int = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for data
            frame_ptr_next = 8'd0;
            flush_save = 1'b1;
            input_axis_tready_next = ~output_eth_hdr_valid_reg;

            if (input_axis_tready & input_axis_tvalid) begin
                // got first word of packet
                if (input_axis_tlast) begin
                    // tlast asserted on first word
                    error_header_early_termination_next = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    // move to read header state
                    frame_ptr_next = 8'd8;
                    store_hdr_word_0 = 1'b1;
                    transfer_in_save = 1'b1;
                    state_next = STATE_READ_HEADER;
                end
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_READ_HEADER: begin
            // read header state
            input_axis_tready_next = 1'b1;

            if (input_axis_tready & input_axis_tvalid) begin
                // word transfer in - store it
                frame_ptr_next = frame_ptr_reg + 8'd8;
                transfer_in_save = 1'b1;
                state_next = STATE_READ_HEADER;
                case (frame_ptr_reg)
                    8'h00: store_hdr_word_0 = 1'b1;
                    8'h08: begin
                        store_hdr_word_1 = 1'b1;
                        output_eth_hdr_valid_next = 1'b1;
                        input_axis_tready_next = output_eth_payload_tready_int_early;
                        state_next = STATE_READ_PAYLOAD;
                    end
                endcase
                if (input_axis_tlast) begin
                    if (input_axis_tkeep[7:6] != 2'd0) begin
                        input_axis_tready_next = 1'b0;
                        state_next = STATE_READ_PAYLOAD;
                    end else begin
                        flush_save = 1'b1;
                        output_eth_hdr_valid_next = 1'b0;
                        error_header_early_termination_next = 1'b1;
                        input_axis_tready_next = ~output_eth_hdr_valid_reg;
                        state_next = STATE_IDLE;
                    end
                end
            end else begin
                state_next = STATE_READ_HEADER;
            end
        end
        STATE_READ_PAYLOAD: begin
            // read payload
            input_axis_tready_next = output_eth_payload_tready_int_early & shift_axis_input_tready;

            output_eth_payload_tdata_int = shift_axis_tdata;
            output_eth_payload_tkeep_int = shift_axis_tkeep;
            output_eth_payload_tvalid_int = shift_axis_tvalid;
            output_eth_payload_tlast_int = shift_axis_tlast;
            output_eth_payload_tuser_int = shift_axis_tuser;

            if (output_eth_payload_tready_int_reg & shift_axis_tvalid) begin
                // word transfer through
                transfer_in_save = 1'b1;
                if (shift_axis_tlast) begin
                    flush_save = 1'b1;
                    input_axis_tready_next = ~output_eth_hdr_valid_reg;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_READ_PAYLOAD;
                end
            end else begin
                state_next = STATE_READ_PAYLOAD;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        frame_ptr_reg <= 8'd0;
        input_axis_tready_reg <= 1'b0;
        output_eth_hdr_valid_reg <= 1'b0;
        save_axis_tlast_reg <= 1'b0;
        busy_reg <= 1'b0;
        error_header_early_termination_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        frame_ptr_reg <= frame_ptr_next;

        input_axis_tready_reg <= input_axis_tready_next;

        output_eth_hdr_valid_reg <= output_eth_hdr_valid_next;

        error_header_early_termination_reg <= error_header_early_termination_next;

        busy_reg <= state_next != STATE_IDLE;

        if (flush_save) begin
            save_axis_tlast_reg <= 1'b0;
        end else if (transfer_in_save) begin
            save_axis_tlast_reg <= input_axis_tlast;
        end
    end

    // datapath
    if (store_hdr_word_0) begin
        output_eth_dest_mac_reg[47:40] <= input_axis_tdata[ 7: 0];
        output_eth_dest_mac_reg[39:32] <= input_axis_tdata[15: 8];
        output_eth_dest_mac_reg[31:24] <= input_axis_tdata[23:16];
        output_eth_dest_mac_reg[23:16] <= input_axis_tdata[31:24];
        output_eth_dest_mac_reg[15: 8] <= input_axis_tdata[39:32];
        output_eth_dest_mac_reg[ 7: 0] <= input_axis_tdata[47:40];
        output_eth_src_mac_reg[47:40] <= input_axis_tdata[55:48];
        output_eth_src_mac_reg[39:32] <= input_axis_tdata[63:56];
    end
    if (store_hdr_word_1) begin
        output_eth_src_mac_reg[31:24] <= input_axis_tdata[ 7: 0];
        output_eth_src_mac_reg[23:16] <= input_axis_tdata[15: 8];
        output_eth_src_mac_reg[15: 8] <= input_axis_tdata[23:16];
        output_eth_src_mac_reg[ 7: 0] <= input_axis_tdata[31:24];
        output_eth_type_reg[15:8] <= input_axis_tdata[39:32];
        output_eth_type_reg[ 7:0] <= input_axis_tdata[47:40];
    end

    if (transfer_in_save) begin
        save_axis_tdata_reg <= input_axis_tdata;
        save_axis_tkeep_reg <= input_axis_tkeep;
        save_axis_tuser_reg <= input_axis_tuser;
    end
end

// output datapath logic
reg [64:0] output_eth_payload_tdata_reg = 64'd0;
reg [7:0]  output_eth_payload_tkeep_reg = 8'd0;
reg        output_eth_payload_tvalid_reg = 1'b0, output_eth_payload_tvalid_next;
reg        output_eth_payload_tlast_reg = 1'b0;
reg        output_eth_payload_tuser_reg = 1'b0;

reg [64:0] temp_eth_payload_tdata_reg = 64'd0;
reg [7:0]  temp_eth_payload_tkeep_reg = 8'd0;
reg        temp_eth_payload_tvalid_reg = 1'b0, temp_eth_payload_tvalid_next;
reg        temp_eth_payload_tlast_reg = 1'b0;
reg        temp_eth_payload_tuser_reg = 1'b0;

// datapath control
reg store_eth_payload_int_to_output;
reg store_eth_payload_int_to_temp;
reg store_eth_payload_temp_to_output;

assign output_eth_payload_tdata = output_eth_payload_tdata_reg;
assign output_eth_payload_tkeep = output_eth_payload_tkeep_reg;
assign output_eth_payload_tvalid = output_eth_payload_tvalid_reg;
assign output_eth_payload_tlast = output_eth_payload_tlast_reg;
assign output_eth_payload_tuser = output_eth_payload_tuser_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign output_eth_payload_tready_int_early = output_eth_payload_tready | (~temp_eth_payload_tvalid_reg & (~output_eth_payload_tvalid_reg | ~output_eth_payload_tvalid_int));

always @* begin
    // transfer sink ready state to source
    output_eth_payload_tvalid_next = output_eth_payload_tvalid_reg;
    temp_eth_payload_tvalid_next = temp_eth_payload_tvalid_reg;

    store_eth_payload_int_to_output = 1'b0;
    store_eth_payload_int_to_temp = 1'b0;
    store_eth_payload_temp_to_output = 1'b0;
    
    if (output_eth_payload_tready_int_reg) begin
        // input is ready
        if (output_eth_payload_tready | ~output_eth_payload_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            output_eth_payload_tvalid_next = output_eth_payload_tvalid_int;
            store_eth_payload_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_eth_payload_tvalid_next = output_eth_payload_tvalid_int;
            store_eth_payload_int_to_temp = 1'b1;
        end
    end else if (output_eth_payload_tready) begin
        // input is not ready, but output is ready
        output_eth_payload_tvalid_next = temp_eth_payload_tvalid_reg;
        temp_eth_payload_tvalid_next = 1'b0;
        store_eth_payload_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        output_eth_payload_tvalid_reg <= 1'b0;
        output_eth_payload_tready_int_reg <= 1'b0;
        temp_eth_payload_tvalid_reg <= 1'b0;
    end else begin
        output_eth_payload_tvalid_reg <= output_eth_payload_tvalid_next;
        output_eth_payload_tready_int_reg <= output_eth_payload_tready_int_early;
        temp_eth_payload_tvalid_reg <= temp_eth_payload_tvalid_next;
    end

    // datapath
    if (store_eth_payload_int_to_output) begin
        output_eth_payload_tdata_reg <= output_eth_payload_tdata_int;
        output_eth_payload_tkeep_reg <= output_eth_payload_tkeep_int;
        output_eth_payload_tlast_reg <= output_eth_payload_tlast_int;
        output_eth_payload_tuser_reg <= output_eth_payload_tuser_int;
    end else if (store_eth_payload_temp_to_output) begin
        output_eth_payload_tdata_reg <= temp_eth_payload_tdata_reg;
        output_eth_payload_tkeep_reg <= temp_eth_payload_tkeep_reg;
        output_eth_payload_tlast_reg <= temp_eth_payload_tlast_reg;
        output_eth_payload_tuser_reg <= temp_eth_payload_tuser_reg;
    end

    if (store_eth_payload_int_to_temp) begin
        temp_eth_payload_tdata_reg <= output_eth_payload_tdata_int;
        temp_eth_payload_tkeep_reg <= output_eth_payload_tkeep_int;
        temp_eth_payload_tlast_reg <= output_eth_payload_tlast_int;
        temp_eth_payload_tuser_reg <= output_eth_payload_tuser_int;
    end
end

endmodule
