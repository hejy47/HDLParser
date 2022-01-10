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
 * 1G Ethernet MAC
 */
module eth_mac_1g_rx
(
    input  wire        clk,
    input  wire        rst,

    /*
     * GMII input
     */
    input  wire [7:0]  gmii_rxd,
    input  wire        gmii_rx_dv,
    input  wire        gmii_rx_er,

    /*
     * AXI output
     */
    output wire [7:0]  output_axis_tdata,
    output wire        output_axis_tvalid,
    output wire        output_axis_tlast,
    output wire        output_axis_tuser,

    /*
     * Status
     */
    output wire        error_bad_frame,
    output wire        error_bad_fcs
);

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_PAYLOAD = 3'd1;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg reset_crc;
reg update_crc;

reg [7:0] gmii_rxd_d0 = 0;
reg [7:0] gmii_rxd_d1 = 0;
reg [7:0] gmii_rxd_d2 = 0;
reg [7:0] gmii_rxd_d3 = 0;
reg [7:0] gmii_rxd_d4 = 0;

reg gmii_rx_dv_d0 = 0;
reg gmii_rx_dv_d1 = 0;
reg gmii_rx_dv_d2 = 0;
reg gmii_rx_dv_d3 = 0;
reg gmii_rx_dv_d4 = 0;

reg gmii_rx_er_d0 = 0;
reg gmii_rx_er_d1 = 0;
reg gmii_rx_er_d2 = 0;
reg gmii_rx_er_d3 = 0;
reg gmii_rx_er_d4 = 0;

reg [7:0] output_axis_tdata_reg = 0, output_axis_tdata_next;
reg output_axis_tvalid_reg = 0, output_axis_tvalid_next;
reg output_axis_tlast_reg = 0, output_axis_tlast_next;
reg output_axis_tuser_reg = 0, output_axis_tuser_next;

reg error_bad_frame_reg = 0, error_bad_frame_next;
reg error_bad_fcs_reg = 0, error_bad_fcs_next;

reg [31:0] crc_state = 32'hFFFFFFFF;
wire [31:0] crc_next;

assign output_axis_tdata = output_axis_tdata_reg;
assign output_axis_tvalid = output_axis_tvalid_reg;
assign output_axis_tlast = output_axis_tlast_reg;
assign output_axis_tuser = output_axis_tuser_reg;

assign error_bad_frame = error_bad_frame_reg;
assign error_bad_fcs = error_bad_fcs_reg;

eth_crc_8
eth_crc_8_inst (
    .data_in(gmii_rxd_d4),
    .crc_state(crc_state),
    .crc_next(crc_next)
);

always @* begin
    state_next = STATE_IDLE;

    reset_crc = 0;
    update_crc = 0;

    output_axis_tdata_next = 0;
    output_axis_tvalid_next = 0;
    output_axis_tlast_next = 0;
    output_axis_tuser_next = 0;

    error_bad_frame_next = 0;
    error_bad_fcs_next = 0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for packet
            reset_crc = 1;

            if (gmii_rx_dv_d4 && ~gmii_rx_er_d4 && gmii_rxd_d4 == 8'hD5) begin
                state_next = STATE_PAYLOAD;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_PAYLOAD: begin
            // read payload
            update_crc = 1;

            output_axis_tdata_next = gmii_rxd_d4;
            output_axis_tvalid_next = 1;

            if (gmii_rx_er) begin
                // error
                output_axis_tlast_next = 1;
                output_axis_tuser_next = 1;
                error_bad_frame_next = 1;
                state_next = STATE_IDLE;
            end if (~gmii_rx_dv) begin
                // end of packet
                output_axis_tlast_next = 1;
                if ({gmii_rxd_d0, gmii_rxd_d1, gmii_rxd_d2, gmii_rxd_d3} == ~crc_next) begin
                    // FCS good
                    output_axis_tuser_next = 0;
                end else begin
                    // FCS bad
                    output_axis_tuser_next = 1;
                    error_bad_frame_next = 1;
                    error_bad_fcs_next = 1;
                end
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_PAYLOAD;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;

        output_axis_tdata_reg <= 0;
        output_axis_tvalid_reg <= 0;
        output_axis_tlast_reg <= 0;
        output_axis_tuser_reg <= 0;

        error_bad_frame_reg <= 0;
        error_bad_fcs_reg <= 0;

        crc_state <= 32'hFFFFFFFF;
    end else begin
        state_reg <= state_next;

        output_axis_tdata_reg <= output_axis_tdata_next;
        output_axis_tvalid_reg <= output_axis_tvalid_next;
        output_axis_tlast_reg <= output_axis_tlast_next;
        output_axis_tuser_reg <= output_axis_tuser_next;

        error_bad_frame_reg <= error_bad_frame_next;
        error_bad_fcs_reg <= error_bad_fcs_next;

        // datapath
        if (reset_crc) begin
            crc_state <= 32'hFFFFFFFF;
        end else if (update_crc) begin
            crc_state <= crc_next;
        end
    end

    // delay input
    gmii_rxd_d0 <= gmii_rxd;
    gmii_rxd_d1 <= gmii_rxd_d0;
    gmii_rxd_d2 <= gmii_rxd_d1;
    gmii_rxd_d3 <= gmii_rxd_d2;
    gmii_rxd_d4 <= gmii_rxd_d3;

    gmii_rx_dv_d0 <= gmii_rx_dv;
    gmii_rx_dv_d1 <= gmii_rx_dv_d0;
    gmii_rx_dv_d2 <= gmii_rx_dv_d1;
    gmii_rx_dv_d3 <= gmii_rx_dv_d2;
    gmii_rx_dv_d4 <= gmii_rx_dv_d3;

    gmii_rx_er_d0 <= gmii_rx_er;
    gmii_rx_er_d1 <= gmii_rx_er_d0;
    gmii_rx_er_d2 <= gmii_rx_er_d1;
    gmii_rx_er_d3 <= gmii_rx_er_d2;
    gmii_rx_er_d4 <= gmii_rx_er_d3;
end

endmodule
