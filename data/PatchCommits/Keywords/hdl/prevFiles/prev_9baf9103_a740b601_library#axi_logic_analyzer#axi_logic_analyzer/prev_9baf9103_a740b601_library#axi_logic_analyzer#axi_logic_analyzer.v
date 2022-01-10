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

module axi_logic_analyzer (

  input                 clk,
  output                clk_out,

  input       [15:0]    data_i,
  output reg  [15:0]    data_o,
  output      [15:0]    data_t,
  input       [ 1:0]    trigger_i,

  output reg            adc_valid,
  output      [15:0]    adc_data,

  input       [15:0]    dac_data,
  input                 dac_valid,
  output reg            dac_read,

  output                trigger_out,
  output      [31:0]    fifo_depth,

  // axi interface

  input                 s_axi_aclk,
  input                 s_axi_aresetn,
  input                 s_axi_awvalid,
  input       [ 6:0]    s_axi_awaddr,
  input       [ 2:0]    s_axi_awprot,
  output                s_axi_awready,
  input                 s_axi_wvalid,
  input       [31:0]    s_axi_wdata,
  input       [ 3:0]    s_axi_wstrb,
  output                s_axi_wready,
  output                s_axi_bvalid,
  output      [ 1:0]    s_axi_bresp,
  input                 s_axi_bready,
  input                 s_axi_arvalid,
  input       [ 6:0]    s_axi_araddr,
  input       [ 2:0]    s_axi_arprot,
  output                s_axi_arready,
  output                s_axi_rvalid,
  output      [31:0]    s_axi_rdata,
  output      [ 1:0]    s_axi_rresp,
  input                 s_axi_rready);

  // internal registers

  reg     [15:0]    data_m1 = 'd0;
  reg     [15:0]    data_r = 'd0;
  reg     [ 1:0]    trigger_m1 = 'd0;
  reg     [ 1:0]    trigger_m2 = 'd0;
  reg     [31:0]    downsampler_counter_la = 'd0;
  reg     [31:0]    upsampler_counter_pg = 'd0;

  reg               sample_valid_la = 'd0;

  reg     [15:0]    io_selection; // 1 - input, 0 - output

  reg     [31:0]    delay_counter = 'd0;
  reg               triggered = 'd0;

  reg               up_triggered;
  reg               up_triggered_d1;
  reg               up_triggered_d2;

  reg               up_triggered_set;
  reg               up_triggered_reset;
  reg               up_triggered_reset_d1;
  reg               up_triggered_reset_d2;

  reg               streaming_on;

  reg     [15:0]    adc_data_m2 = 'd0;

  // internal signals

  wire              up_clk;
  wire              up_rstn;
  wire    [ 4:0]    up_waddr;
  wire    [31:0]    up_wdata;
  wire              up_wack;
  wire              up_wreq;
  wire              up_rack;
  wire    [31:0]    up_rdata;
  wire              up_rreq;
  wire    [ 4:0]    up_raddr;

  wire              reset;

  wire    [31:0]    divider_counter_la;
  wire    [31:0]    divider_counter_pg;

  wire    [17:0]    edge_detect_enable;
  wire    [17:0]    rise_edge_enable;
  wire    [17:0]    fall_edge_enable;
  wire    [17:0]    low_level_enable;
  wire    [17:0]    high_level_enable;
  wire              trigger_logic; // 0-OR,1-AND,2-XOR,3-NOR,4-NAND,5-NXOR
  wire              clock_select;
  wire    [15:0]    overwrite_enable;
  wire    [15:0]    overwrite_data;

  wire    [15:0]    io_selection_s; // 1 - input, 0 - output
  wire    [15:0]    od_pp_n; // 0 - push/pull, 1 - open drain

  wire              trigger_out_s;
  wire    [31:0]    trigger_delay;
  wire              trigger_out_delayed;

  wire              streaming;

  genvar i;

  // signal name changes

  assign up_clk = s_axi_aclk;
  assign up_rstn = s_axi_aresetn;

  assign trigger_out = trigger_delay == 32'h0 ? trigger_out_s | streaming_on : trigger_out_delayed | streaming_on;
  assign trigger_out_delayed = delay_counter == 32'h0 ? 1 : 0;

  assign adc_data = adc_data_m2;

 always @(posedge clk_out) begin
    if (trigger_delay == 0) begin
      if (streaming == 1'b1 && sample_valid_la == 1'b1 && trigger_out_s == 1'b1) begin
        streaming_on <= 1'b1;
      end else if (streaming == 1'b0) begin
        streaming_on <= 1'b0;
      end
    end else begin
      if (streaming == 1'b1 && sample_valid_la == 1'b1 && trigger_out_delayed == 1'b1) begin
        streaming_on <= 1'b1;
      end else if (streaming == 1'b0) begin
        streaming_on <= 1'b0;
      end
    end
  end

 always @(posedge clk_out) begin
    if (sample_valid_la == 1'b1 && trigger_out_s == 1'b1) begin
      up_triggered_set <= 1'b1;
    end else if (up_triggered_reset == 1'b1) begin
      up_triggered_set <= 1'b0;
    end
    up_triggered_reset_d1 <= up_triggered;
    up_triggered_reset_d2 <= up_triggered_reset_d1;
    up_triggered_reset    <= up_triggered_reset_d2;
  end

  always @(posedge up_clk) begin
    up_triggered_d1 <= up_triggered_set;
    up_triggered_d2 <= up_triggered_d1;
    up_triggered    <= up_triggered_d2;
  end

  generate
  for (i = 0 ; i < 16; i = i + 1) begin
    assign data_t[i] = od_pp_n[i] ? io_selection[i] & !data_o[i] : io_selection[i];
    always @(posedge clk_out) begin
      data_o[i] <= overwrite_enable[i] ? overwrite_data[i] : data_r[i];
    end
    always @(posedge clk_out) begin
      if(dac_valid == 1'b1) begin
        data_r[i] <= dac_data[i];
      end
      if (io_selection_s[i] == 1'b1) begin
        io_selection[i] <= 1'b1;
      end else begin
        if(dac_valid == 1'b1 || overwrite_enable[i] == 1'b1) begin
          io_selection[i] <= 1'b0;
        end
      end
    end
  end
  endgenerate

  BUFGMUX_CTRL BUFGMUX_CTRL_inst (
    .O (clk_out),
    .I0 (clk),
    .I1 (data_i[0]),
    .S (clock_select));

  // synchronization

  always @(posedge clk_out) begin
    if (sample_valid_la == 1'b1) begin
      data_m1 <= data_i;
      trigger_m1 <= trigger_i;
      trigger_m2 <= trigger_m1;
    end
  end

  // transfer data at clock frequency
  // if capture is enabled

  always @(posedge clk_out) begin
    if (sample_valid_la == 1'b1) begin
      adc_data_m2  <= data_m1;
      adc_valid <= 1'b1;
    end else begin
      adc_valid <= 1'b0;
    end
  end

  // downsampler logic analyzer

  always @(posedge clk_out) begin
    if (reset == 1'b1) begin
      sample_valid_la <= 1'b0;
      downsampler_counter_la <= 32'h0;
    end else begin
      if (downsampler_counter_la < divider_counter_la ) begin
        downsampler_counter_la <= downsampler_counter_la + 1;
        sample_valid_la <= 1'b0;
      end else begin
        downsampler_counter_la <= 32'h0;
        sample_valid_la <= 1'b1;
      end
    end
  end

  // upsampler pattern generator

  always @(posedge clk_out) begin
    if (reset == 1'b1) begin
      upsampler_counter_pg <= 32'h0;
      dac_read <= 1'b0;
    end else begin
      dac_read <= 1'b0;
        if (upsampler_counter_pg < divider_counter_pg) begin
          upsampler_counter_pg <= upsampler_counter_pg + 1;
        end else begin
          upsampler_counter_pg <= 32'h0;
          dac_read <= 1'b1;
        end
    end
  end

  always @(posedge clk_out) begin
    if(trigger_delay == 32'h0) begin
      delay_counter <= 32'h0;
    end else begin
      if (adc_valid == 1'b1) begin
        triggered <= trigger_out_s | triggered;
        if (delay_counter == 32'h0) begin
          delay_counter <= trigger_delay;
          triggered <= 1'b0;
        end else begin
          if(triggered == 1'b1 || trigger_out_s == 1'b1) begin
            delay_counter <= delay_counter - 1;
          end
        end
      end
    end
  end

  axi_logic_analyzer_trigger i_trigger (
    .clk (clk_out),
    .reset (reset),

    .data (adc_data_m2),
    .data_valid(sample_valid_la),
    .trigger (trigger_m2),

    .edge_detect_enable (edge_detect_enable),
    .rise_edge_enable (rise_edge_enable),
    .fall_edge_enable (fall_edge_enable),
    .low_level_enable (low_level_enable),
    .high_level_enable (high_level_enable),
    .trigger_logic (trigger_logic),
    .trigger_out (trigger_out_s));

   axi_logic_analyzer_reg i_registers (

    .clk (clk_out),
    .reset (reset),

    .divider_counter_la (divider_counter_la),
    .divider_counter_pg (divider_counter_pg),
    .io_selection (io_selection_s),

    .edge_detect_enable (edge_detect_enable),
    .rise_edge_enable (rise_edge_enable),
    .fall_edge_enable (fall_edge_enable),
    .low_level_enable (low_level_enable),
    .high_level_enable (high_level_enable),
    .fifo_depth (fifo_depth),
    .trigger_delay (trigger_delay),
    .trigger_logic (trigger_logic),
    .clock_select (clock_select),
    .overwrite_enable (overwrite_enable),
    .overwrite_data (overwrite_data),
    .input_data (adc_data_m2),
    .od_pp_n (od_pp_n),

    .triggered (up_triggered),

    .streaming(streaming),

    // bus interface

    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_wreq (up_wreq),
    .up_waddr (up_waddr),
    .up_wdata (up_wdata),
    .up_wack (up_wack),
    .up_rreq (up_rreq),
    .up_raddr (up_raddr),
    .up_rdata (up_rdata),
    .up_rack (up_rack));

  // axi interface

  up_axi #(
    .AXI_ADDRESS_WIDTH(7),
    .ADDRESS_WIDTH(5)
  ) i_up_axi (
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_axi_awvalid (s_axi_awvalid),
    .up_axi_awaddr (s_axi_awaddr),
    .up_axi_awready (s_axi_awready),
    .up_axi_wvalid (s_axi_wvalid),
    .up_axi_wdata (s_axi_wdata),
    .up_axi_wstrb (s_axi_wstrb),
    .up_axi_wready (s_axi_wready),
    .up_axi_bvalid (s_axi_bvalid),
    .up_axi_bresp (s_axi_bresp),
    .up_axi_bready (s_axi_bready),
    .up_axi_arvalid (s_axi_arvalid),
    .up_axi_araddr (s_axi_araddr),
    .up_axi_arready (s_axi_arready),
    .up_axi_rvalid (s_axi_rvalid),
    .up_axi_rresp (s_axi_rresp),
    .up_axi_rdata (s_axi_rdata),
    .up_axi_rready (s_axi_rready),
    .up_wreq (up_wreq),
    .up_waddr (up_waddr),
    .up_wdata (up_wdata),
    .up_wack (up_wack),
    .up_rreq (up_rreq),
    .up_raddr (up_raddr),
    .up_rdata (up_rdata),
    .up_rack (up_rack));

endmodule

// ***************************************************************************
// ***************************************************************************
