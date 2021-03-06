// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: USB UART top level wrapper file
//

module usbuart (
  input        clk_i,
  input        clk_48mhz_i,
  input        rst_ni,

  // Bus Interface
  input        tlul_pkg::tl_h2d_t tl_i,
  output       tlul_pkg::tl_d2h_t tl_o,

  // Generic IO
  input        cio_usb_dp_i,
  output logic cio_usb_dp_o,
  output logic cio_usb_dp_en_o,

  input        cio_usb_dn_i,
  output logic cio_usb_dn_o,
  output logic cio_usb_dn_en_o,

  input        cio_usb_sense_i,

  output logic cio_pullup_o,
  output logic cio_pullup_en_o,

  // Interrupts
  output logic intr_tx_watermark_o ,
  output logic intr_rx_watermark_o ,
  output logic intr_tx_overflow_o ,
  output logic intr_rx_overflow_o ,
  output logic intr_rx_frame_err_o ,
  output logic intr_rx_break_err_o ,
  output logic intr_rx_timeout_o ,
  output logic intr_rx_parity_err_o
);

  import usbuart_reg_pkg::*;

  usbuart_reg2hw_t reg2hw;
  usbuart_hw2reg_t hw2reg;

  usbuart_reg_top u_reg (
    .clk_i,
    .rst_ni,
    .tl_i,
    .tl_o,

    .reg2hw,
    .hw2reg
    );

  logic              usb_tx_en_o;
  assign cio_usb_dp_en_o = usb_tx_en_o;
  assign cio_usb_dn_en_o = usb_tx_en_o;
  assign cio_pullup_en_o = 1;

  usbuart_core usbuart_core (
    .clk_i,
    .rst_ni,
    .reg2hw,
    .hw2reg,

    .clk_usb_48mhz_i(clk_48mhz_i),
    .usb_dp_i(cio_usb_dp_i),
    .usb_dp_o(cio_usb_dp_o),
    .usb_dn_i(cio_usb_dn_i),
    .usb_dn_o(cio_usb_dn_o),
    .usb_tx_en_o(usb_tx_en_o),

    .usb_sense_i(cio_usb_sense_i),
    .usb_pullup_o(cio_pullup_o),

    .intr_tx_watermark_o  (intr_tx_watermark_o ),
    .intr_rx_watermark_o  (intr_rx_watermark_o ),
    .intr_tx_overflow_o   (intr_tx_overflow_o  ),
    .intr_rx_overflow_o   (intr_rx_overflow_o  ),
    .intr_rx_frame_err_o  (intr_rx_frame_err_o ),
    .intr_rx_break_err_o  (intr_rx_break_err_o ),
    .intr_rx_timeout_o    (intr_rx_timeout_o   ),
    .intr_rx_parity_err_o (intr_rx_parity_err_o)
    );

endmodule // usbuart
