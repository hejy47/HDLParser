// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//


module rv_timer (
  input clk_i,
  input rst_ni,

  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,

  output logic intr_timer_expired_0_0_o
);

  localparam int N_HARTS  = 1;
  localparam int N_TIMERS = 1;

  import rv_timer_reg_pkg::*;

  rv_timer_reg2hw_t reg2hw;
  rv_timer_hw2reg_t hw2reg;

  logic [N_HARTS-1:0] active;

  logic [11:0] prescaler [N_HARTS];
  logic [7:0]  step      [N_HARTS];

  logic [N_HARTS-1:0] tick;

  logic [63:0] mtime_d  [N_HARTS];
  logic [63:0] mtime    [N_HARTS];
  logic [63:0] mtimecmp [N_HARTS][N_TIMERS]; // Only [harts][0] is connected to mtimecmp CSRs

  logic [N_HARTS*N_TIMERS-1:0] intr_timer_set;
  logic [N_HARTS*N_TIMERS-1:0] intr_timer_en;
  logic [N_HARTS*N_TIMERS-1:0] intr_timer_test_q;
  logic [N_HARTS-1:0]          intr_timer_test_qe;
  logic [N_HARTS*N_TIMERS-1:0] intr_timer_state_q;
  logic [N_HARTS-1:0]          intr_timer_state_de;
  logic [N_HARTS*N_TIMERS-1:0] intr_timer_state_d;

  logic [N_HARTS*N_TIMERS-1:0] intr_out;

  ///////////////////////////////////////////////////////////////////
  // Connecting register interface to the signal: need to connect manually
  //
  assign active[0]  = reg2hw.ctrl.q[0];
  assign prescaler = '{reg2hw.cfg0.prescale.q};
  assign step      = '{reg2hw.cfg0.step.q};

  assign hw2reg.timer_v_upper0.de = tick[0];
  assign hw2reg.timer_v_lower0.de = tick[0];
  assign hw2reg.timer_v_upper0.d = mtime_d[0][63:32];
  assign hw2reg.timer_v_lower0.d = mtime_d[0][31: 0];
  assign mtime[0] = {reg2hw.timer_v_upper0.q, reg2hw.timer_v_lower0.q};
  assign mtimecmp = '{'{{reg2hw.compare_upper0_0,reg2hw.compare_lower0_0}}};

  assign intr_timer_expired_0_0_o = intr_out[0];
  assign intr_timer_en            = reg2hw.intr_enable0.q;
  assign intr_timer_state_q       = reg2hw.intr_state0.q;
  assign intr_timer_test_q        = reg2hw.intr_test0.q;
  assign intr_timer_test_qe       = reg2hw.intr_test0.qe;
  assign hw2reg.intr_state0.de    = intr_timer_state_de;
  assign hw2reg.intr_state0.d     = intr_timer_state_d;
  //
  //-----------------------------------------------------------------

  for (genvar h = 0 ; h < N_HARTS ; h++) begin : gen_harts
    prim_intr_hw #(
      .Width(N_TIMERS)
    ) u_intr_hw (
      .event_intr_i           (intr_timer_set),

      .reg2hw_intr_enable_q_i (intr_timer_en[h*N_TIMERS+:N_TIMERS]),
      .reg2hw_intr_test_q_i   (intr_timer_test_q[h*N_TIMERS+:N_TIMERS]),
      .reg2hw_intr_test_qe_i  (intr_timer_test_qe[h]),
      .reg2hw_intr_state_q_i  (intr_timer_state_q[h*N_TIMERS+:N_TIMERS]),
      .hw2reg_intr_state_de_o (intr_timer_state_de),
      .hw2reg_intr_state_d_o  (intr_timer_state_d[h*N_TIMERS+:N_TIMERS]),

      .intr_o                 (intr_out[h*N_TIMERS+:N_TIMERS])
    );

    timer_core #(
      .N (N_TIMERS)
    ) u_core (
      .clk_i,
      .rst_ni,

      .active    (active[h]),
      .prescaler (prescaler[h]),
      .step      (step[h]),

      .tick      (tick[h]),

      .mtime_d   (mtime_d[h]),
      .mtime     (mtime[h]),
      .mtimecmp  (mtimecmp[h]),

      .intr      (intr_timer_set[h*N_TIMERS+:N_TIMERS])
    );
  end : gen_harts

  // Register module
  rv_timer_reg_top u_reg (
    .clk_i,
    .rst_ni,

    .tl_i,
    .tl_o,

    .reg2hw,
    .hw2reg
  );

endmodule
