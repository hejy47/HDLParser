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
 * 1G Ethernet MAC with TX and RX FIFOs
 */
module eth_mac_1g_fifo #
(
    parameter ENABLE_PADDING = 1,
    parameter MIN_FRAME_LENGTH = 64,
    parameter TX_FIFO_ADDR_WIDTH = 9,
    parameter RX_FIFO_ADDR_WIDTH = 9
)
(
    input  wire        rx_clk,
    input  wire        rx_rst,
    input  wire        tx_clk,
    input  wire        tx_rst,
    input  wire        logic_clk,
    input  wire        logic_rst,

    /*
     * AXI input
     */
    input  wire [7:0]  tx_axis_tdata,
    input  wire        tx_axis_tvalid,
    output wire        tx_axis_tready,
    input  wire        tx_axis_tlast,
    input  wire        tx_axis_tuser,

    /*
     * AXI output
     */
    output wire [7:0]  rx_axis_tdata,
    output wire        rx_axis_tvalid,
    input  wire        rx_axis_tready,
    output wire        rx_axis_tlast,
    output wire        rx_axis_tuser,

    /*
     * GMII interface
     */
    input  wire [7:0]  gmii_rxd,
    input  wire        gmii_rx_dv,
    input  wire        gmii_rx_er,
    output wire [7:0]  gmii_txd,
    output wire        gmii_tx_en,
    output wire        gmii_tx_er,

    /*
     * Status
     */
    output wire        rx_error_bad_frame,
    output wire        rx_error_bad_fcs,

    /*
     * Configuration
     */
    input  wire [7:0]  ifg_delay
);

wire [7:0]  tx_fifo_axis_tdata;
wire        tx_fifo_axis_tvalid;
wire        tx_fifo_axis_tready;
wire        tx_fifo_axis_tlast;
wire        tx_fifo_axis_tuser;

wire [7:0]  rx_fifo_axis_tdata;
wire        rx_fifo_axis_tvalid;
wire        rx_fifo_axis_tlast;
wire        rx_fifo_axis_tuser;

eth_mac_1g #(
    .ENABLE_PADDING(ENABLE_PADDING),
    .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH)
)
eth_mac_1g_inst (
    .tx_clk(tx_clk),
    .tx_rst(tx_rst),
    .rx_clk(rx_clk),
    .rx_rst(rx_rst),
    .tx_axis_tdata(tx_fifo_axis_tdata),
    .tx_axis_tvalid(tx_fifo_axis_tvalid),
    .tx_axis_tready(tx_fifo_axis_tready),
    .tx_axis_tlast(tx_fifo_axis_tlast),
    .tx_axis_tuser(tx_fifo_axis_tuser),
    .rx_axis_tdata(rx_fifo_axis_tdata),
    .rx_axis_tvalid(rx_fifo_axis_tvalid),
    .rx_axis_tlast(rx_fifo_axis_tlast),
    .rx_axis_tuser(rx_fifo_axis_tuser),
    .gmii_rxd(gmii_rxd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(gmii_tx_er),
    .rx_error_bad_frame(rx_error_bad_frame),
    .rx_error_bad_fcs(rx_error_bad_fcs),
    .ifg_delay(ifg_delay)
);

axis_async_frame_fifo #(
    .ADDR_WIDTH(TX_FIFO_ADDR_WIDTH),
    .DATA_WIDTH(8),
    .DROP_WHEN_FULL(0)
)
tx_fifo (
    // AXI input
    .input_clk(logic_clk),
    .input_rst(logic_rst),
    .input_axis_tdata(tx_axis_tdata),
    .input_axis_tvalid(tx_axis_tvalid),
    .input_axis_tready(tx_axis_tready),
    .input_axis_tlast(tx_axis_tlast),
    .input_axis_tuser(tx_axis_tuser),
    // AXI output
    .output_clk(tx_clk),
    .output_rst(tx_rst),
    .output_axis_tdata(tx_fifo_axis_tdata),
    .output_axis_tvalid(tx_fifo_axis_tvalid),
    .output_axis_tready(tx_fifo_axis_tready),
    .output_axis_tlast(tx_fifo_axis_tlast)
);

assign tx_fifo_axis_tuser = 1'b0;

axis_async_frame_fifo #(
    .ADDR_WIDTH(RX_FIFO_ADDR_WIDTH),
    .DATA_WIDTH(8),
    .DROP_WHEN_FULL(1)
)
rx_fifo (
    // AXI input
    .input_clk(rx_clk),
    .input_rst(rx_rst),
    .input_axis_tdata(rx_fifo_axis_tdata),
    .input_axis_tvalid(rx_fifo_axis_tvalid),
    .input_axis_tready(),
    .input_axis_tlast(rx_fifo_axis_tlast),
    .input_axis_tuser(rx_fifo_axis_tuser),
    // AXI output
    .output_clk(logic_clk),
    .output_rst(logic_rst),
    .output_axis_tdata(rx_axis_tdata),
    .output_axis_tvalid(rx_axis_tvalid),
    .output_axis_tready(rx_axis_tready),
    .output_axis_tlast(rx_axis_tlast)
);

assign rx_axis_tuser = 1'b0;

endmodule
