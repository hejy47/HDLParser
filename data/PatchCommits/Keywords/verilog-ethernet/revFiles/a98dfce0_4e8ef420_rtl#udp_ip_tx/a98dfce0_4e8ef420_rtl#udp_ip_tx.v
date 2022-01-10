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
 * UDP ethernet frame transmitter (UDP frame in, IP frame out)
 */
module udp_ip_tx
(
    input  wire        clk,
    input  wire        rst,

    /*
     * UDP frame input
     */
    input  wire        input_udp_hdr_valid,
    output wire        input_udp_hdr_ready,
    input  wire [47:0] input_eth_dest_mac,
    input  wire [47:0] input_eth_src_mac,
    input  wire [15:0] input_eth_type,
    input  wire [3:0]  input_ip_version,
    input  wire [3:0]  input_ip_ihl,
    input  wire [5:0]  input_ip_dscp,
    input  wire [1:0]  input_ip_ecn,
    input  wire [15:0] input_ip_identification,
    input  wire [2:0]  input_ip_flags,
    input  wire [12:0] input_ip_fragment_offset,
    input  wire [7:0]  input_ip_ttl,
    input  wire [7:0]  input_ip_protocol,
    input  wire [15:0] input_ip_header_checksum,
    input  wire [31:0] input_ip_source_ip,
    input  wire [31:0] input_ip_dest_ip,
    input  wire [15:0] input_udp_source_port,
    input  wire [15:0] input_udp_dest_port,
    input  wire [15:0] input_udp_length,
    input  wire [15:0] input_udp_checksum,
    input  wire [7:0]  input_udp_payload_tdata,
    input  wire        input_udp_payload_tvalid,
    output wire        input_udp_payload_tready,
    input  wire        input_udp_payload_tlast,
    input  wire        input_udp_payload_tuser,

    /*
     * IP frame output
     */
    output wire        output_ip_hdr_valid,
    input  wire        output_ip_hdr_ready,
    output wire [47:0] output_eth_dest_mac,
    output wire [47:0] output_eth_src_mac,
    output wire [15:0] output_eth_type,
    output wire [3:0]  output_ip_version,
    output wire [3:0]  output_ip_ihl,
    output wire [5:0]  output_ip_dscp,
    output wire [1:0]  output_ip_ecn,
    output wire [15:0] output_ip_length,
    output wire [15:0] output_ip_identification,
    output wire [2:0]  output_ip_flags,
    output wire [12:0] output_ip_fragment_offset,
    output wire [7:0]  output_ip_ttl,
    output wire [7:0]  output_ip_protocol,
    output wire [15:0] output_ip_header_checksum,
    output wire [31:0] output_ip_source_ip,
    output wire [31:0] output_ip_dest_ip,
    output wire [7:0]  output_ip_payload_tdata,
    output wire        output_ip_payload_tvalid,
    input  wire        output_ip_payload_tready,
    output wire        output_ip_payload_tlast,
    output wire        output_ip_payload_tuser,

    /*
     * Status signals
     */
    output wire        busy,
    output wire        error_payload_early_termination
);

/*

UDP Frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0800)          2 octets
 Version (4)                 4 bits
 IHL (5-15)                  4 bits
 DSCP (0)                    6 bits
 ECN (0)                     2 bits
 length                      2 octets
 identification (0?)         2 octets
 flags (010)                 3 bits
 fragment offset (0)         13 bits
 time to live (64?)          1 octet
 protocol                    1 octet
 header checksum             2 octets
 source IP                   4 octets
 destination IP              4 octets
 options                     (IHL-5)*4 octets

 source port                 2 octets
 desination port             2 octets
 length                      2 octets
 checksum                    2 octets

 payload                     length octets

This module receives a UDP frame with header fields in parallel along with the
payload in an AXI stream, combines the header with the payload, passes through
the IP headers, and transmits the complete IP payload on an AXI interface.

*/

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_WRITE_HEADER = 3'd1,
    STATE_WRITE_PAYLOAD = 3'd2,
    STATE_WRITE_PAYLOAD_LAST = 3'd3,
    STATE_WAIT_LAST = 3'd4;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg store_udp_hdr;
reg store_last_word;

reg [15:0] frame_ptr_reg = 16'd0, frame_ptr_next;

reg [7:0] last_word_data_reg = 8'd0;

reg [15:0] udp_source_port_reg = 16'd0;
reg [15:0] udp_dest_port_reg = 16'd0;
reg [15:0] udp_length_reg = 16'd0;
reg [15:0] udp_checksum_reg = 16'd0;

reg input_udp_hdr_ready_reg = 1'b0, input_udp_hdr_ready_next;
reg input_udp_payload_tready_reg = 1'b0, input_udp_payload_tready_next;

reg output_ip_hdr_valid_reg = 1'b0, output_ip_hdr_valid_next;
reg [47:0] output_eth_dest_mac_reg = 48'd0;
reg [47:0] output_eth_src_mac_reg = 48'd0;
reg [15:0] output_eth_type_reg = 16'd0;
reg [3:0] output_ip_version_reg = 4'd0;
reg [3:0] output_ip_ihl_reg = 4'd0;
reg [5:0] output_ip_dscp_reg = 6'd0;
reg [1:0] output_ip_ecn_reg = 2'd0;
reg [15:0] output_ip_length_reg = 16'd0;
reg [15:0] output_ip_identification_reg = 16'd0;
reg [2:0] output_ip_flags_reg = 3'd0;
reg [12:0] output_ip_fragment_offset_reg = 13'd0;
reg [7:0] output_ip_ttl_reg = 8'd0;
reg [7:0] output_ip_protocol_reg = 8'd0;
reg [15:0] output_ip_header_checksum_reg = 16'd0;
reg [31:0] output_ip_source_ip_reg = 32'd0;
reg [31:0] output_ip_dest_ip_reg = 32'd0;

reg busy_reg = 1'b0;
reg error_payload_early_termination_reg = 1'b0, error_payload_early_termination_next;

// internal datapath
reg [7:0] output_ip_payload_tdata_int;
reg       output_ip_payload_tvalid_int;
reg       output_ip_payload_tready_int_reg = 1'b0;
reg       output_ip_payload_tlast_int;
reg       output_ip_payload_tuser_int;
wire      output_ip_payload_tready_int_early;

assign input_udp_hdr_ready = input_udp_hdr_ready_reg;
assign input_udp_payload_tready = input_udp_payload_tready_reg;

assign output_ip_hdr_valid = output_ip_hdr_valid_reg;
assign output_eth_dest_mac = output_eth_dest_mac_reg;
assign output_eth_src_mac = output_eth_src_mac_reg;
assign output_eth_type = output_eth_type_reg;
assign output_ip_version = output_ip_version_reg;
assign output_ip_ihl = output_ip_ihl_reg;
assign output_ip_dscp = output_ip_dscp_reg;
assign output_ip_ecn = output_ip_ecn_reg;
assign output_ip_length = output_ip_length_reg;
assign output_ip_identification = output_ip_identification_reg;
assign output_ip_flags = output_ip_flags_reg;
assign output_ip_fragment_offset = output_ip_fragment_offset_reg;
assign output_ip_ttl = output_ip_ttl_reg;
assign output_ip_protocol = output_ip_protocol_reg;
assign output_ip_header_checksum = output_ip_header_checksum_reg;
assign output_ip_source_ip = output_ip_source_ip_reg;
assign output_ip_dest_ip = output_ip_dest_ip_reg;

assign busy = busy_reg;
assign error_payload_early_termination = error_payload_early_termination_reg;

always @* begin
    state_next = STATE_IDLE;

    input_udp_hdr_ready_next = 1'b0;
    input_udp_payload_tready_next = 1'b0;

    store_udp_hdr = 1'b0;

    store_last_word = 1'b0;

    frame_ptr_next = frame_ptr_reg;

    output_ip_hdr_valid_next = output_ip_hdr_valid_reg & ~output_ip_hdr_ready;

    error_payload_early_termination_next = 1'b0;

    output_ip_payload_tdata_int = 8'd0;
    output_ip_payload_tvalid_int = 1'b0;
    output_ip_payload_tlast_int = 1'b0;
    output_ip_payload_tuser_int = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for data
            frame_ptr_next = 16'd0;
            input_udp_hdr_ready_next = ~output_ip_hdr_valid_reg;

            if (input_udp_hdr_ready & input_udp_hdr_valid) begin
                store_udp_hdr = 1'b1;
                input_udp_hdr_ready_next = 1'b0;
                output_ip_hdr_valid_next = 1'b1;
                if (output_ip_payload_tready_int_reg) begin
                    output_ip_payload_tvalid_int = 1'b1;
                    output_ip_payload_tdata_int = input_udp_source_port[15: 8];
                    frame_ptr_next = 1'b1;
                end
                state_next = STATE_WRITE_HEADER;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_WRITE_HEADER: begin
            // write header state
            if (output_ip_payload_tready_int_reg) begin
                // word transfer out
                frame_ptr_next = frame_ptr_reg + 16'd1;
                output_ip_payload_tvalid_int = 1'b1;
                state_next = STATE_WRITE_HEADER;
                case (frame_ptr_reg)
                    8'h00: output_ip_payload_tdata_int = input_udp_source_port[15: 8];
                    8'h01: output_ip_payload_tdata_int = udp_source_port_reg[ 7: 0];
                    8'h02: output_ip_payload_tdata_int = udp_dest_port_reg[15: 8];
                    8'h03: output_ip_payload_tdata_int = udp_dest_port_reg[ 7: 0];
                    8'h04: output_ip_payload_tdata_int = udp_length_reg[15: 8];
                    8'h05: output_ip_payload_tdata_int = udp_length_reg[ 7: 0];
                    8'h06: output_ip_payload_tdata_int = udp_checksum_reg[15: 8];
                    8'h07: begin
                        output_ip_payload_tdata_int = udp_checksum_reg[ 7: 0];
                        input_udp_payload_tready_next = output_ip_payload_tready_int_early;
                        state_next = STATE_WRITE_PAYLOAD;
                    end
                endcase
            end else begin
                state_next = STATE_WRITE_HEADER;
            end
        end
        STATE_WRITE_PAYLOAD: begin
            // write payload
            input_udp_payload_tready_next = output_ip_payload_tready_int_early;

            output_ip_payload_tdata_int = input_udp_payload_tdata;
            output_ip_payload_tvalid_int = input_udp_payload_tvalid;
            output_ip_payload_tlast_int = input_udp_payload_tlast;
            output_ip_payload_tuser_int = input_udp_payload_tuser;

            if (input_udp_payload_tready & input_udp_payload_tvalid) begin
                // word transfer through
                frame_ptr_next = frame_ptr_reg + 16'd1;
                if (input_udp_payload_tlast) begin
                    if (frame_ptr_next != udp_length_reg) begin
                        // end of frame, but length does not match
                        output_ip_payload_tuser_int = 1'b1;
                        error_payload_early_termination_next = 1'b1;
                    end
                    input_udp_hdr_ready_next = ~output_ip_hdr_valid_reg;
                    input_udp_payload_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    if (frame_ptr_next == udp_length_reg) begin
                        store_last_word = 1'b1;
                        output_ip_payload_tvalid_int = 1'b0;
                        state_next = STATE_WRITE_PAYLOAD_LAST;
                    end else begin
                        state_next = STATE_WRITE_PAYLOAD;
                    end
                end
            end else begin
                state_next = STATE_WRITE_PAYLOAD;
            end
        end
        STATE_WRITE_PAYLOAD_LAST: begin
            // read and discard until end of frame
            input_udp_payload_tready_next = output_ip_payload_tready_int_early;

            output_ip_payload_tdata_int = last_word_data_reg;
            output_ip_payload_tvalid_int = input_udp_payload_tvalid & input_udp_payload_tlast;
            output_ip_payload_tlast_int = input_udp_payload_tlast;
            output_ip_payload_tuser_int = input_udp_payload_tuser;

            if (input_udp_payload_tready & input_udp_payload_tvalid) begin
                if (input_udp_payload_tlast) begin
                    input_udp_hdr_ready_next = ~output_ip_hdr_valid_reg;
                    input_udp_payload_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WRITE_PAYLOAD_LAST;
                end
            end else begin
                state_next = STATE_WRITE_PAYLOAD_LAST;
            end
        end
        STATE_WAIT_LAST: begin
            // wait for end of frame; read and discard
            input_udp_payload_tready_next = 1'b1;

            if (input_udp_payload_tvalid) begin
                if (input_udp_payload_tlast) begin
                    input_udp_hdr_ready_next = ~output_ip_hdr_valid_reg;
                    input_udp_payload_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WAIT_LAST;
                end
            end else begin
                state_next = STATE_WAIT_LAST;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        frame_ptr_reg <= 16'd0;
        input_udp_hdr_ready_reg <= 1'b0;
        input_udp_payload_tready_reg <= 1'b0;
        output_ip_hdr_valid_reg <= 1'b0;
        busy_reg <= 1'b0;
        error_payload_early_termination_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        frame_ptr_reg <= frame_ptr_next;

        input_udp_hdr_ready_reg <= input_udp_hdr_ready_next;
        input_udp_payload_tready_reg <= input_udp_payload_tready_next;

        output_ip_hdr_valid_reg <= output_ip_hdr_valid_next;

        busy_reg <= state_next != STATE_IDLE;

        error_payload_early_termination_reg <= error_payload_early_termination_next;
    end

    // datapath
    if (store_udp_hdr) begin
        output_eth_dest_mac_reg <= input_eth_dest_mac;
        output_eth_src_mac_reg <= input_eth_src_mac;
        output_eth_type_reg <= input_eth_type;
        output_ip_version_reg <= input_ip_version;
        output_ip_ihl_reg <= input_ip_ihl;
        output_ip_dscp_reg <= input_ip_dscp;
        output_ip_ecn_reg <= input_ip_ecn;
        output_ip_length_reg <= input_udp_length + 20;
        output_ip_identification_reg <= input_ip_identification;
        output_ip_flags_reg <= input_ip_flags;
        output_ip_fragment_offset_reg <= input_ip_fragment_offset;
        output_ip_ttl_reg <= input_ip_ttl;
        output_ip_protocol_reg <= input_ip_protocol;
        output_ip_header_checksum_reg <= input_ip_header_checksum;
        output_ip_source_ip_reg <= input_ip_source_ip;
        output_ip_dest_ip_reg <= input_ip_dest_ip;
        udp_source_port_reg <= input_udp_source_port;
        udp_dest_port_reg <= input_udp_dest_port;
        udp_length_reg <= input_udp_length;
        udp_checksum_reg <= input_udp_checksum;
    end

    if (store_last_word) begin
        last_word_data_reg <= output_ip_payload_tdata_int;
    end
end

// output datapath logic
reg [7:0] output_ip_payload_tdata_reg = 8'd0;
reg       output_ip_payload_tvalid_reg = 1'b0, output_ip_payload_tvalid_next;
reg       output_ip_payload_tlast_reg = 1'b0;
reg       output_ip_payload_tuser_reg = 1'b0;

reg [7:0] temp_ip_payload_tdata_reg = 8'd0;
reg       temp_ip_payload_tvalid_reg = 1'b0, temp_ip_payload_tvalid_next;
reg       temp_ip_payload_tlast_reg = 1'b0;
reg       temp_ip_payload_tuser_reg = 1'b0;

// datapath control
reg store_ip_payload_int_to_output;
reg store_ip_payload_int_to_temp;
reg store_ip_payload_temp_to_output;

assign output_ip_payload_tdata = output_ip_payload_tdata_reg;
assign output_ip_payload_tvalid = output_ip_payload_tvalid_reg;
assign output_ip_payload_tlast = output_ip_payload_tlast_reg;
assign output_ip_payload_tuser = output_ip_payload_tuser_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign output_ip_payload_tready_int_early = output_ip_payload_tready | (~temp_ip_payload_tvalid_reg & (~output_ip_payload_tvalid_reg | ~output_ip_payload_tvalid_int));

always @* begin
    // transfer sink ready state to source
    output_ip_payload_tvalid_next = output_ip_payload_tvalid_reg;
    temp_ip_payload_tvalid_next = temp_ip_payload_tvalid_reg;

    store_ip_payload_int_to_output = 1'b0;
    store_ip_payload_int_to_temp = 1'b0;
    store_ip_payload_temp_to_output = 1'b0;
    
    if (output_ip_payload_tready_int_reg) begin
        // input is ready
        if (output_ip_payload_tready | ~output_ip_payload_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            output_ip_payload_tvalid_next = output_ip_payload_tvalid_int;
            store_ip_payload_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_ip_payload_tvalid_next = output_ip_payload_tvalid_int;
            store_ip_payload_int_to_temp = 1'b1;
        end
    end else if (output_ip_payload_tready) begin
        // input is not ready, but output is ready
        output_ip_payload_tvalid_next = temp_ip_payload_tvalid_reg;
        temp_ip_payload_tvalid_next = 1'b0;
        store_ip_payload_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        output_ip_payload_tvalid_reg <= 1'b0;
        output_ip_payload_tready_int_reg <= 1'b0;
        temp_ip_payload_tvalid_reg <= 1'b0;
    end else begin
        output_ip_payload_tvalid_reg <= output_ip_payload_tvalid_next;
        output_ip_payload_tready_int_reg <= output_ip_payload_tready_int_early;
        temp_ip_payload_tvalid_reg <= temp_ip_payload_tvalid_next;
    end

    // datapath
    if (store_ip_payload_int_to_output) begin
        output_ip_payload_tdata_reg <= output_ip_payload_tdata_int;
        output_ip_payload_tlast_reg <= output_ip_payload_tlast_int;
        output_ip_payload_tuser_reg <= output_ip_payload_tuser_int;
    end else if (store_ip_payload_temp_to_output) begin
        output_ip_payload_tdata_reg <= temp_ip_payload_tdata_reg;
        output_ip_payload_tlast_reg <= temp_ip_payload_tlast_reg;
        output_ip_payload_tuser_reg <= temp_ip_payload_tuser_reg;
    end

    if (store_ip_payload_int_to_temp) begin
        temp_ip_payload_tdata_reg <= output_ip_payload_tdata_int;
        temp_ip_payload_tlast_reg <= output_ip_payload_tlast_int;
        temp_ip_payload_tuser_reg <= output_ip_payload_tuser_int;
    end
end

endmodule
