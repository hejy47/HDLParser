// ***************************************************************************
// ***************************************************************************
// Copyright 2011(c) Analog Devices, Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//     - Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     - Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in
//       the documentation and/or other materials provided with the
//       distribution.
//     - Neither the name of Analog Devices, Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//     - The use of this software may or may not infringe the patent rights
//       of one or more patent holders.  This license does not release you
//       from the requirement that you obtain separate licenses from these
//       patent holders to use this software.
//     - Use of the software either in source or binary form, must be run
//       on or directly connected to an Analog Devices Inc. component.
//
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED.
//
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, INTELLECTUAL PROPERTY
// RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module system_top (

  ddr_addr,
  ddr_ba,
  ddr_cas_n,
  ddr_ck_n,
  ddr_ck_p,
  ddr_cke,
  ddr_cs_n,
  ddr_dm,
  ddr_dq,
  ddr_dqs_n,
  ddr_dqs_p,
  ddr_odt,
  ddr_ras_n,
  ddr_reset_n,
  ddr_we_n,

  fixed_io_ddr_vrn,
  fixed_io_ddr_vrp,
  fixed_io_mio,
  fixed_io_ps_clk,
  fixed_io_ps_porb,
  fixed_io_ps_srstb,

  gpio_bd,

  hdmi_out_clk,
  hdmi_vsync,
  hdmi_hsync,
  hdmi_data_e,
  hdmi_data,

  spdif,

  iic_scl,
  iic_sda,

  rx_clk_in_p,
  rx_clk_in_n,
  rx_frame_in_p,
  rx_frame_in_n,
  rx_data_in_p,
  rx_data_in_n,
  tx_clk_out_p,
  tx_clk_out_n,
  tx_frame_out_p,
  tx_frame_out_n,
  tx_data_out_p,
  tx_data_out_n,

  gpio_txnrx,
  gpio_enable,
  gpio_resetb,
  gpio_sync,
  gpio_en_agc,
  gpio_ctl,
  gpio_status,

  spi_csn,
  spi_clk,
  spi_mosi,
  spi_miso);

  inout   [14:0]  ddr_addr;
  inout   [ 2:0]  ddr_ba;
  inout           ddr_cas_n;
  inout           ddr_ck_n;
  inout           ddr_ck_p;
  inout           ddr_cke;
  inout           ddr_cs_n;
  inout   [ 3:0]  ddr_dm;
  inout   [31:0]  ddr_dq;
  inout   [ 3:0]  ddr_dqs_n;
  inout   [ 3:0]  ddr_dqs_p;
  inout           ddr_odt;
  inout           ddr_ras_n;
  inout           ddr_reset_n;
  inout           ddr_we_n;

  inout           fixed_io_ddr_vrn;
  inout           fixed_io_ddr_vrp;
  inout   [53:0]  fixed_io_mio;
  inout           fixed_io_ps_clk;
  inout           fixed_io_ps_porb;
  inout           fixed_io_ps_srstb;

  inout   [14:0]  gpio_bd;

  output          hdmi_out_clk;
  output          hdmi_vsync;
  output          hdmi_hsync;
  output          hdmi_data_e;
  output  [23:0]  hdmi_data;

  output          spdif;

  inout           iic_scl;
  inout           iic_sda;

  input           rx_clk_in_p;
  input           rx_clk_in_n;
  input           rx_frame_in_p;
  input           rx_frame_in_n;
  input   [ 5:0]  rx_data_in_p;
  input   [ 5:0]  rx_data_in_n;
  output          tx_clk_out_p;
  output          tx_clk_out_n;
  output          tx_frame_out_p;
  output          tx_frame_out_n;
  output  [ 5:0]  tx_data_out_p;
  output  [ 5:0]  tx_data_out_n;

  inout           gpio_txnrx;
  inout           gpio_enable;
  inout           gpio_resetb;
  inout           gpio_sync;
  inout           gpio_en_agc;
  inout   [ 3:0]  gpio_ctl;
  inout   [ 7:0]  gpio_status;

  output          spi_csn;
  output          spi_clk;
  output          spi_mosi;
  input           spi_miso;

  // internal signals

  wire    [63:0]  gpio_i;
  wire    [63:0]  gpio_o;
  wire    [63:0]  gpio_t;

  wire            clk;
  wire            dma_dac_i0_enable;
  wire    [15:0]  dma_dac_i0_data;
  wire            dma_dac_i0_valid;
  wire            dma_dac_q0_enable;
  wire    [15:0]  dma_dac_q0_data;
  wire            dma_dac_q0_valid;
  wire            dma_dac_i1_enable;
  wire    [15:0]  dma_dac_i1_data;
  wire            dma_dac_i1_valid;
  wire            dma_dac_q1_enable;
  wire    [15:0]  dma_dac_q1_data;
  wire            dma_dac_q1_valid;
  wire            core_dac_i0_enable;
  wire    [15:0]  core_dac_i0_data;
  wire            core_dac_i0_valid;
  wire            core_dac_q0_enable;
  wire    [15:0]  core_dac_q0_data;
  wire            core_dac_q0_valid;
  wire            core_dac_i1_enable;
  wire    [15:0]  core_dac_i1_data;
  wire            core_dac_i1_valid;
  wire            core_dac_q1_enable;
  wire    [15:0]  core_dac_q1_data;
  wire            core_dac_q1_valid;
  wire            dma_adc_i0_enable;
  wire    [15:0]  dma_adc_i0_data;
  wire            dma_adc_i0_valid;
  wire            dma_adc_q0_enable;
  wire    [15:0]  dma_adc_q0_data;
  wire            dma_adc_q0_valid;
  wire            dma_adc_i1_enable;
  wire    [15:0]  dma_adc_i1_data;
  wire            dma_adc_i1_valid;
  wire            dma_adc_q1_enable;
  wire    [15:0]  dma_adc_q1_data;
  wire            dma_adc_q1_valid;
  wire            core_adc_i0_enable;
  wire    [15:0]  core_adc_i0_data;
  wire            core_adc_i0_valid;
  wire            core_adc_q0_enable;
  wire    [15:0]  core_adc_q0_data;
  wire            core_adc_q0_valid;
  wire            core_adc_i1_enable;
  wire    [15:0]  core_adc_i1_data;
  wire            core_adc_i1_valid;
  wire            core_adc_q1_enable;
  wire    [15:0]  core_adc_q1_data;
  wire            core_adc_q1_valid;

  wire    [31:0]  adc_gpio_input;
  wire    [31:0]  adc_gpio_output;
  wire    [31:0]  dac_gpio_input;
  wire    [31:0]  dac_gpio_output;
  wire            tdd_sync_t;
  wire            tdd_sync_o;
  wire            tdd_sync_i;

  // instantiations

  ad_iobuf #(.DATA_WIDTH(17)) i_iobuf (
    .dio_t ({gpio_t[50:49], gpio_t[46:32]}),
    .dio_i ({gpio_o[50:49], gpio_o[46:32]}),
    .dio_o ({gpio_i[50:49], gpio_i[46:32]}),
    .dio_p ({ gpio_muxout_tx,     // 50:50
              gpio_muxout_rx,     // 49:49
              gpio_resetb,        // 46:46
              gpio_sync,          // 45:45
              gpio_en_agc,        // 44:44
              gpio_ctl,           // 43:40
              gpio_status}));     // 39:32

  ad_iobuf #(.DATA_WIDTH(15)) i_iobuf_bd (
    .dio_t (gpio_t[14:0]),
    .dio_i (gpio_o[14:0]),
    .dio_o (gpio_i[14:0]),
    .dio_p (gpio_bd));

  ad_iobuf #(.DATA_WIDTH(1)) i_iobuf_tdd_sync (
    .dio_t (tdd_sync_t),
    .dio_i (tdd_sync_o),
    .dio_o (tdd_sync_i),
    .dio_p (tdd_sync));

  // prcfg instance
  prcfg i_prcfg (
    .clk (clk),
    .adc_gpio_input (adc_gpio_input),
    .adc_gpio_output (adc_gpio_output),
    .dac_gpio_input (dac_gpio_input),
    .dac_gpio_output (dac_gpio_output),
    .dma_dac_i0_enable (dma_dac_i0_enable),
    .dma_dac_i0_data (dma_dac_i0_data),
    .dma_dac_i0_valid (dma_dac_i0_valid),
    .dma_dac_q0_enable (dma_dac_q0_enable),
    .dma_dac_q0_data (dma_dac_q0_data),
    .dma_dac_q0_valid (dma_dac_q0_valid),
    .dma_dac_i1_enable (dma_dac_i1_enable),
    .dma_dac_i1_data (dma_dac_i1_data),
    .dma_dac_i1_valid (dma_dac_i1_valid),
    .dma_dac_q1_enable (dma_dac_q1_enable),
    .dma_dac_q1_data (dma_dac_q1_data),
    .dma_dac_q1_valid (dma_dac_q1_valid),
    .core_dac_i0_enable (core_dac_i0_enable),
    .core_dac_i0_data (core_dac_i0_data),
    .core_dac_i0_valid (core_dac_i0_valid),
    .core_dac_q0_enable (core_dac_q0_enable),
    .core_dac_q0_data (core_dac_q0_data),
    .core_dac_q0_valid (core_dac_q0_valid),
    .core_dac_i1_enable (core_dac_i1_enable),
    .core_dac_i1_data (core_dac_i1_data),
    .core_dac_i1_valid (core_dac_i1_valid),
    .core_dac_q1_enable (core_dac_q1_enable),
    .core_dac_q1_data (core_dac_q1_data),
    .core_dac_q1_valid (core_dac_q1_valid),
    .dma_adc_i0_enable (dma_adc_i0_enable),
    .dma_adc_i0_data (dma_adc_i0_data),
    .dma_adc_i0_valid (dma_adc_i0_valid),
    .dma_adc_q0_enable (dma_adc_q0_enable),
    .dma_adc_q0_data (dma_adc_q0_data),
    .dma_adc_q0_valid (dma_adc_q0_valid),
    .dma_adc_i1_enable (dma_adc_i1_enable),
    .dma_adc_i1_data (dma_adc_i1_data),
    .dma_adc_i1_valid (dma_adc_i1_valid),
    .dma_adc_q1_enable (dma_adc_q1_enable),
    .dma_adc_q1_data (dma_adc_q1_data),
    .dma_adc_q1_valid (dma_adc_q1_valid),
    .core_adc_i0_enable (core_adc_i0_enable),
    .core_adc_i0_data (core_adc_i0_data),
    .core_adc_i0_valid (core_adc_i0_valid),
    .core_adc_q0_enable (core_adc_q0_enable),
    .core_adc_q0_data (core_adc_q0_data),
    .core_adc_q0_valid (core_adc_q0_valid),
    .core_adc_i1_enable (core_adc_i1_enable),
    .core_adc_i1_data (core_adc_i1_data),
    .core_adc_i1_valid (core_adc_i1_valid),
    .core_adc_q1_enable (core_adc_q1_enable),
    .core_adc_q1_data (core_adc_q1_data),
    .core_adc_q1_valid (core_adc_q1_valid)
  );

  system_wrapper i_system_wrapper (
    .ddr_addr (ddr_addr),
    .ddr_ba (ddr_ba),
    .ddr_cas_n (ddr_cas_n),
    .ddr_ck_n (ddr_ck_n),
    .ddr_ck_p (ddr_ck_p),
    .ddr_cke (ddr_cke),
    .ddr_cs_n (ddr_cs_n),
    .ddr_dm (ddr_dm),
    .ddr_dq (ddr_dq),
    .ddr_dqs_n (ddr_dqs_n),
    .ddr_dqs_p (ddr_dqs_p),
    .ddr_odt (ddr_odt),
    .ddr_ras_n (ddr_ras_n),
    .ddr_reset_n (ddr_reset_n),
    .ddr_we_n (ddr_we_n),
    .enable (enable),
    .fixed_io_ddr_vrn (fixed_io_ddr_vrn),
    .fixed_io_ddr_vrp (fixed_io_ddr_vrp),
    .fixed_io_mio (fixed_io_mio),
    .fixed_io_ps_clk (fixed_io_ps_clk),
    .fixed_io_ps_porb (fixed_io_ps_porb),
    .fixed_io_ps_srstb (fixed_io_ps_srstb),
    .gpio_i (gpio_i),
    .gpio_o (gpio_o),
    .gpio_t (gpio_t),
    .hdmi_data (hdmi_data),
    .hdmi_data_e (hdmi_data_e),
    .hdmi_hsync (hdmi_hsync),
    .hdmi_out_clk (hdmi_out_clk),
    .hdmi_vsync (hdmi_vsync),
    .iic_main_scl_io (iic_scl),
    .iic_main_sda_io (iic_sda),
    .ps_intr_00 (1'b0),
    .ps_intr_01 (1'b0),
    .ps_intr_02 (1'b0),
    .ps_intr_03 (1'b0),
    .ps_intr_04 (1'b0),
    .ps_intr_05 (1'b0),
    .ps_intr_06 (1'b0),
    .ps_intr_07 (1'b0),
    .ps_intr_08 (1'b0),
    .ps_intr_09 (1'b0),
    .ps_intr_10 (1'b0),
    .ps_intr_11 (1'b0),
    .rx_clk_in_n (rx_clk_in_n),
    .rx_clk_in_p (rx_clk_in_p),
    .rx_data_in_n (rx_data_in_n),
    .rx_data_in_p (rx_data_in_p),
    .rx_frame_in_n (rx_frame_in_n),
    .rx_frame_in_p (rx_frame_in_p),
    .spdif (spdif),
    .spi0_clk_i (1'b0),
    .spi0_clk_o (spi_clk),
    .spi0_csn_0_o (spi_csn),
    .spi0_csn_1_o (),
    .spi0_csn_2_o (),
    .spi0_csn_i (1'b1),
    .spi0_sdi_i (spi_miso),
    .spi0_sdo_i (1'b0),
    .spi0_sdo_o (spi_mosi),
    .tx_clk_out_n (tx_clk_out_n),
    .tx_clk_out_p (tx_clk_out_p),
    .tx_data_out_n (tx_data_out_n),
    .tx_data_out_p (tx_data_out_p),
    .tx_frame_out_n (tx_frame_out_n),
    .tx_frame_out_p (tx_frame_out_p),
    // pr related ports
    .clk (clk),
    .up_adc_gpio_in (adc_gpio_input),
    .up_adc_gpio_out (adc_gpio_output),
    .up_dac_gpio_in (dac_gpio_input),
    .up_dac_gpio_out (dac_gpio_output),
    .dma_dac_i0_enable (dma_dac_i0_enable),
    .dma_dac_i0_data (dma_dac_i0_data),
    .dma_dac_i0_valid (dma_dac_i0_valid),
    .dma_dac_q0_enable (dma_dac_q0_enable),
    .dma_dac_q0_data (dma_dac_q0_data),
    .dma_dac_q0_valid (dma_dac_q0_valid),
    .dma_dac_i1_enable (dma_dac_i1_enable),
    .dma_dac_i1_data (dma_dac_i1_data),
    .dma_dac_i1_valid (dma_dac_i1_valid),
    .dma_dac_q1_enable (dma_dac_q1_enable),
    .dma_dac_q1_data (dma_dac_q1_data),
    .dma_dac_q1_valid (dma_dac_q1_valid),
    .core_dac_i0_enable (core_dac_i0_enable),
    .core_dac_i0_data (core_dac_i0_data),
    .core_dac_i0_valid (core_dac_i0_valid),
    .core_dac_q0_enable (core_dac_q0_enable),
    .core_dac_q0_data (core_dac_q0_data),
    .core_dac_q0_valid (core_dac_q0_valid),
    .core_dac_i1_enable (core_dac_i1_enable),
    .core_dac_i1_data (core_dac_i1_data),
    .core_dac_i1_valid (core_dac_i1_valid),
    .core_dac_q1_enable (core_dac_q1_enable),
    .core_dac_q1_data (core_dac_q1_data),
    .core_dac_q1_valid (core_dac_q1_valid),
    .dma_adc_i0_enable (dma_adc_i0_enable),
    .dma_adc_i0_data (dma_adc_i0_data),
    .dma_adc_i0_valid (dma_adc_i0_valid),
    .dma_adc_q0_enable (dma_adc_q0_enable),
    .dma_adc_q0_data (dma_adc_q0_data),
    .dma_adc_q0_valid (dma_adc_q0_valid),
    .dma_adc_i1_enable (dma_adc_i1_enable),
    .dma_adc_i1_data (dma_adc_i1_data),
    .dma_adc_i1_valid (dma_adc_i1_valid),
    .dma_adc_q1_enable (dma_adc_q1_enable),
    .dma_adc_q1_data (dma_adc_q1_data),
    .dma_adc_q1_valid (dma_adc_q1_valid),
    .core_adc_i0_enable (core_adc_i0_enable),
    .core_adc_i0_data (core_adc_i0_data),
    .core_adc_i0_valid (core_adc_i0_valid),
    .core_adc_q0_enable (core_adc_q0_enable),
    .core_adc_q0_data (core_adc_q0_data),
    .core_adc_q0_valid (core_adc_q0_valid),
    .core_adc_i1_enable (core_adc_i1_enable),
    .core_adc_i1_data (core_adc_i1_data),
    .core_adc_i1_valid (core_adc_i1_valid),
    .core_adc_q1_enable (core_adc_q1_enable),
    .core_adc_q1_data (core_adc_q1_data),
    .core_adc_q1_valid (core_adc_q1_valid)
  );

endmodule

// ***************************************************************************
// ***************************************************************************
