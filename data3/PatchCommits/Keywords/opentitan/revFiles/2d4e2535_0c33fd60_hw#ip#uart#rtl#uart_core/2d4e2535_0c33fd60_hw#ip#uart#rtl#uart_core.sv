// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: UART core module
//

module uart_core (
  input                  clk_i,
  input                  rst_ni,
  input                  scanmode_i,

  input  uart_reg_pkg::uart_reg2hw_t reg2hw,
  output uart_reg_pkg::uart_hw2reg_t hw2reg,

  input                  rx,
  output logic           tx,

  output logic           intr_tx_watermark_o,
  output logic           intr_rx_watermark_o,
  output logic           intr_tx_overflow_o,
  output logic           intr_rx_overflow_o,
  output logic           intr_rx_frame_err_o,
  output logic           intr_rx_break_err_o,
  output logic           intr_rx_timeout_o,
  output logic           intr_rx_parity_err_o
);

  import uart_reg_pkg::*;

  logic   [15:0]  rx_val;
  logic   [7:0]   uart_rdata;
  logic           tick_baud_x16, rx_tick_baud;
  logic           tx_fifo_rst_n, rx_fifo_rst_n;
  logic   [5:0]   tx_fifo_depth, rx_fifo_depth;
  logic   [5:0]   rx_fifo_depth_prev;
  logic   [23:0]  rx_timeout_count, rx_timeout_count_next, uart_rxto_val;
  logic           rx_fifo_depth_changed, uart_rxto_en;
  logic           tx_enable, rx_enable;
  logic           sys_loopback, line_loopback, rxnf_enable;
  logic           uart_fifo_rxrst, uart_fifo_txrst;
  logic   [2:0]   uart_fifo_rxilvl;
  logic   [1:0]   uart_fifo_txilvl;
  logic           ovrd_tx_en, ovrd_tx_val;
  logic   [7:0]   tx_fifo_data;
  logic           tx_fifo_rready, tx_fifo_rvalid;
  logic           tx_fifo_wready, tx_uart_idle;
  logic           tx_out;
  logic           tx_out_q;
  logic   [7:0]   rx_fifo_data;
  logic           rx_valid, rx_fifo_wvalid, rx_fifo_rvalid;
  logic           rx_fifo_wready, rx_uart_idle;
  logic           rx_sync;
  logic           rx_in;
  logic           break_err;
  logic   [4:0]   allzero_cnt;
  logic   [4:0]   allzero_cnt_next;
  logic           allzero_err, not_allzero_char;
  logic           event_tx_watermark, event_rx_watermark, event_tx_overflow, event_rx_overflow;
  logic           event_rx_frame_err, event_rx_break_err, event_rx_timeout, event_rx_parity_err;

  assign tx_enable        = reg2hw.ctrl.tx.q;
  assign rx_enable        = reg2hw.ctrl.rx.q;
  assign rxnf_enable      = reg2hw.ctrl.nf.q;
  assign sys_loopback     = reg2hw.ctrl.slpbk.q;
  assign line_loopback    = reg2hw.ctrl.llpbk.q;

  assign uart_fifo_rxrst  = reg2hw.fifo_ctrl.rxrst.q & reg2hw.fifo_ctrl.rxrst.qe;
  assign uart_fifo_txrst  = reg2hw.fifo_ctrl.txrst.q & reg2hw.fifo_ctrl.txrst.qe;
  assign uart_fifo_rxilvl = reg2hw.fifo_ctrl.rxilvl.q;
  assign uart_fifo_txilvl = reg2hw.fifo_ctrl.txilvl.q;

  assign ovrd_tx_en       = reg2hw.ovrd.txen.q;
  assign ovrd_tx_val      = reg2hw.ovrd.txval.q;

  typedef enum logic {
    BRK_CHK,
    BRK_WAIT
  } break_st_e ;

  break_st_e break_st;

  assign not_allzero_char = rx_valid & (~event_rx_frame_err | (rx_fifo_data != 8'h0));
  assign allzero_err = event_rx_frame_err & (rx_fifo_data == 8'h0);


  assign allzero_cnt_next = (break_st == BRK_WAIT || not_allzero_char) ? 5'h0 :
                            allzero_cnt[4] ? allzero_cnt :
                            allzero_err ? allzero_cnt + 5'd1 :
                            allzero_cnt;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)        allzero_cnt <= '0;
    else if (rx_enable) allzero_cnt <= allzero_cnt_next;
  end

  // break_err edges in same cycle as event_rx_frame_err edges ; that way the
  // reset-on-read works the same way for break and frame error interrupts.

  always_comb begin
    unique case (reg2hw.ctrl.rxblvl.q)
      2'h0:    break_err = allzero_cnt_next >= 5'd2;
      2'h1:    break_err = allzero_cnt_next >= 5'd4;
      2'h2:    break_err = allzero_cnt_next >= 5'd8;
      default: break_err = allzero_cnt_next >= 5'd16;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) break_st <= BRK_CHK;
    else begin
      unique case (break_st)
        BRK_CHK: begin
          if (event_rx_break_err) break_st <= BRK_WAIT;
        end

        BRK_WAIT: begin
          if (rx_in) break_st <= BRK_CHK;
        end

        default: begin
          break_st <= BRK_CHK;
        end
      endcase
    end
  end

  assign hw2reg.val.d  = rx_val;

  assign hw2reg.rdata.d = uart_rdata;

  assign hw2reg.status.rxempty.d     = ~rx_fifo_rvalid;
  assign hw2reg.status.rxidle.d      = rx_uart_idle;
  assign hw2reg.status.txidle.d      = tx_uart_idle & ~tx_fifo_rvalid;
  assign hw2reg.status.txempty.d     = ~tx_fifo_rvalid;
  assign hw2reg.status.rxfull.d      = ~rx_fifo_wready;
  assign hw2reg.status.txfull.d      = ~tx_fifo_wready;

  assign hw2reg.fifo_status.txlvl.d  = tx_fifo_depth;
  assign hw2reg.fifo_status.rxlvl.d  = rx_fifo_depth;

  // resets are self-clearing, so need to update FIFO_CTRL
  assign hw2reg.fifo_ctrl.rxilvl.de = 1'b0;
  assign hw2reg.fifo_ctrl.rxilvl.d  = 3'h0;
  assign hw2reg.fifo_ctrl.txilvl.de = 1'b0;
  assign hw2reg.fifo_ctrl.txilvl.d  = 2'h0;

  //              NCO 16x Baud Generator
  // output clock rate is:
  //      Fin * (NCO/2**16)
  // So, with a 16 bit accumulator, the output clock is
  //      Fin * (NCO/65536)
  logic   [16:0]     nco_sum; // extra bit to get the carry

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      nco_sum <= 17'h0;
    end else if (tx_enable || rx_enable) begin
      nco_sum <= {1'b0,nco_sum[15:0]} + {1'b0,reg2hw.ctrl.nco.q};
    end
  end

  assign tick_baud_x16 = nco_sum[16];

  // ######################################################################
  //              TX Logic

  assign tx_fifo_rready = tx_uart_idle & tx_fifo_rvalid & tx_enable;
  assign tx_fifo_rst_n  = scanmode_i ? rst_ni : (rst_ni & ~uart_fifo_txrst);

  prim_fifo_sync #(
    .Width(8),
    .Pass (1'b0),
    .Depth(32)
  ) u_uart_txfifo (
    .clk_i,
    .rst_ni (tx_fifo_rst_n),
    .wvalid (reg2hw.wdata.qe),
    .wready (tx_fifo_wready),
    .wdata  (reg2hw.wdata.q),
    .depth  (tx_fifo_depth),
    .rvalid (tx_fifo_rvalid),
    .rready (tx_fifo_rready),
    .rdata  (tx_fifo_data)
  );

  uart_tx uart_tx (
    .clk_i,
    .rst_ni,
    .tx_enable,
    .tick_baud_x16,
    .parity_enable  (reg2hw.ctrl.parity_en.q),
    .wr             (tx_fifo_rready),
    .wr_parity      ((^tx_fifo_data) ^ reg2hw.ctrl.parity_odd.q),
    .wr_data        (tx_fifo_data),
    .idle           (tx_uart_idle),
    .tx             (tx_out)
  );

  assign tx = line_loopback ? rx : tx_out_q ;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      tx_out_q <= 1'b1;
    end else if (ovrd_tx_en) begin
      tx_out_q <= ovrd_tx_val ;
    end else if (sys_loopback) begin
      tx_out_q <= 1'b1;
    end else begin
      tx_out_q <= tx_out;
    end
  end

  // ######################################################################
  //              RX Logic

  //      sync the incoming data
  prim_flop_2sync #(
    .Width(1),
    .ResetValue(1)
  ) sync_rx (
    .clk_i,
    .rst_ni,
    .d(rx),
    .q(rx_sync)
  );

  // Based on: en.wikipedia.org/wiki/Repetition_code mentions the use of a majority filter
  // in uarts to ignore brief noise spikes
  logic   rx_sync_q1, rx_sync_q2, rx_in_mx, rx_in_maj;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rx_sync_q1 <= 1'b1;
      rx_sync_q2 <= 1'b1;
    end else begin
      rx_sync_q1 <= rx_sync;
      rx_sync_q2 <= rx_sync_q1;
    end
  end

  assign rx_in_maj = (rx_sync    & rx_sync_q1) |
                     (rx_sync    & rx_sync_q2) |
                     (rx_sync_q1 & rx_sync_q2);
  assign rx_in_mx  = rxnf_enable ? rx_in_maj : rx_sync;

  assign rx_in =  sys_loopback ? tx_out   :
                  line_loopback ? 1'b1 :
                  rx_in_mx;

  uart_rx uart_rx (
    .clk_i,
    .rst_ni,
    .rx_enable,
    .tick_baud_x16,
    .parity_enable  (reg2hw.ctrl.parity_en.q),
    .parity_odd     (reg2hw.ctrl.parity_odd.q),
    .tick_baud      (rx_tick_baud),
    .rx_valid,
    .rx_data        (rx_fifo_data),
    .idle           (rx_uart_idle),
    .frame_err      (event_rx_frame_err),
    .rx             (rx_in),
    .rx_parity_err  (event_rx_parity_err)
  );

  assign rx_fifo_wvalid = rx_valid & ~event_rx_frame_err & ~event_rx_parity_err;
  assign rx_fifo_rst_n = scanmode_i ? rst_ni : (rst_ni & ~uart_fifo_rxrst);

  prim_fifo_sync #(
    .Width (8),
    .Pass  (1'b0),
    .Depth (32)
  ) u_uart_rxfifo (
    .clk_i  (clk_i),
    .rst_ni (rx_fifo_rst_n),
    .wvalid (rx_fifo_wvalid),
    .wready (rx_fifo_wready),
    .wdata  (rx_fifo_data),
    .depth  (rx_fifo_depth),
    .rvalid (rx_fifo_rvalid),
    .rready (reg2hw.rdata.re),
    .rdata  (uart_rdata)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)            rx_val <= 16'h0;
    else if (tick_baud_x16) rx_val <= {rx_val[14:0], rx_in};
  end

  // ######################################################################
  //              Interrupt & Status

  always_comb begin
    unique case(uart_fifo_txilvl)
      2'h0:    event_tx_watermark = (tx_fifo_depth >= 6'd1);
      2'h1:    event_tx_watermark = (tx_fifo_depth >= 6'd4);
      2'h2:    event_tx_watermark = (tx_fifo_depth >= 6'd8);
      default: event_tx_watermark = (tx_fifo_depth >= 6'd16);
    endcase
  end


  always_comb begin
    unique case(uart_fifo_rxilvl)
      3'h0:    event_rx_watermark = (rx_fifo_depth >= 6'd1);
      3'h1:    event_rx_watermark = (rx_fifo_depth >= 6'd4);
      3'h2:    event_rx_watermark = (rx_fifo_depth >= 6'd8);
      3'h3:    event_rx_watermark = (rx_fifo_depth >= 6'd16);
      3'h4:    event_rx_watermark = (rx_fifo_depth >= 6'd30);
      default: event_rx_watermark = 1'b0;
    endcase
  end


  // rx timeout interrupt
  assign uart_rxto_en  = reg2hw.timeout_ctrl.en.q;
  assign uart_rxto_val = reg2hw.timeout_ctrl.val.q;

  assign rx_fifo_depth_changed = (rx_fifo_depth != rx_fifo_depth_prev);

  assign rx_timeout_count_next =
              // don't count if timeout feature not enabled ;
              // will never reach timeout val + lower power
              (uart_rxto_en == 1'b0)              ? 24'd0 :
              // reset count if timeout interrupt is set
              event_rx_timeout                    ? 24'd0 :
              // reset count upon change in fifo level: covers both read and receiving a new byte
              rx_fifo_depth_changed               ? 24'd0 :
              // reset count if no bytes are pending
              (rx_fifo_depth == 5'd0)             ? 24'd0 :
              // stop the count at timeout value (this will set the interrupt)
              (rx_timeout_count == uart_rxto_val) ? rx_timeout_count :
              // increment if at rx baud tick
              rx_tick_baud                        ? (rx_timeout_count + 24'd1) :
              rx_timeout_count;

  assign event_rx_timeout = (rx_timeout_count == uart_rxto_val) & uart_rxto_en;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rx_timeout_count   <= 24'd0;
      rx_fifo_depth_prev <= 6'd0;
    end else begin
      rx_timeout_count    <= rx_timeout_count_next;
      rx_fifo_depth_prev  <= rx_fifo_depth;
    end
  end

  assign event_rx_overflow  = rx_fifo_wvalid & ~rx_fifo_wready;
  assign event_tx_overflow  = reg2hw.wdata.qe & ~tx_fifo_wready;
  assign event_rx_break_err = break_err && (break_st == BRK_CHK);

  // instantiate interrupt hardware primitives

  prim_intr_hw #(.Width(1)) intr_hw_tx_watermark (
    .event_intr_i           (event_tx_watermark),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.tx_watermark.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.tx_watermark.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.tx_watermark.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.tx_watermark.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.tx_watermark.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.tx_watermark.d),
    .intr_o                 (intr_tx_watermark_o)
  );

  prim_intr_hw #(.Width(1)) intr_hw_rx_watermark (
    .event_intr_i           (event_rx_watermark),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.rx_watermark.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.rx_watermark.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.rx_watermark.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.rx_watermark.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.rx_watermark.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.rx_watermark.d),
    .intr_o                 (intr_rx_watermark_o)
  );

  prim_intr_hw #(.Width(1)) intr_hw_tx_overflow (
    .event_intr_i           (event_tx_overflow),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.tx_overflow.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.tx_overflow.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.tx_overflow.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.tx_overflow.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.tx_overflow.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.tx_overflow.d),
    .intr_o                 (intr_tx_overflow_o)
  );

  prim_intr_hw #(.Width(1)) intr_hw_rx_overflow (
    .event_intr_i           (event_rx_overflow),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.rx_overflow.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.rx_overflow.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.rx_overflow.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.rx_overflow.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.rx_overflow.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.rx_overflow.d),
    .intr_o                 (intr_rx_overflow_o)
  );

  prim_intr_hw #(.Width(1)) intr_hw_rx_frame_err (
    .event_intr_i           (event_rx_frame_err),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.rx_frame_err.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.rx_frame_err.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.rx_frame_err.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.rx_frame_err.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.rx_frame_err.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.rx_frame_err.d),
    .intr_o                 (intr_rx_frame_err_o)
  );

  prim_intr_hw #(.Width(1)) intr_hw_rx_break_err (
    .event_intr_i           (event_rx_break_err),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.rx_break_err.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.rx_break_err.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.rx_break_err.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.rx_break_err.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.rx_break_err.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.rx_break_err.d),
    .intr_o                 (intr_rx_break_err_o)
  );

  prim_intr_hw #(.Width(1)) intr_hw_rx_timeout (
    .event_intr_i           (event_rx_timeout),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.rx_timeout.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.rx_timeout.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.rx_timeout.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.rx_timeout.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.rx_timeout.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.rx_timeout.d),
    .intr_o                 (intr_rx_timeout_o)
  );

  prim_intr_hw #(.Width(1)) intr_hw_rx_parity_err (
    .event_intr_i           (event_rx_parity_err),
    .reg2hw_intr_enable_q_i (reg2hw.intr_enable.rx_parity_err.q),
    .reg2hw_intr_test_q_i   (reg2hw.intr_test.rx_parity_err.q),
    .reg2hw_intr_test_qe_i  (reg2hw.intr_test.rx_parity_err.qe),
    .reg2hw_intr_state_q_i  (reg2hw.intr_state.rx_parity_err.q),
    .hw2reg_intr_state_de_o (hw2reg.intr_state.rx_parity_err.de),
    .hw2reg_intr_state_d_o  (hw2reg.intr_state.rx_parity_err.d),
    .intr_o                 (intr_rx_parity_err_o)
  );

endmodule
