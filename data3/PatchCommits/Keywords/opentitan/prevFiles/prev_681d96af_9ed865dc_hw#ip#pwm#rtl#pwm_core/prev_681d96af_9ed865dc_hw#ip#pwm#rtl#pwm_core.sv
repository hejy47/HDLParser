// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: PWM Core Module

module pwm_core #(
  parameter int NOutputs = 6
) (
  input                           clk_core_i,
  input                           rst_core_ni,

  input pwm_reg_pkg::pwm_reg2hw_t reg2hw,

  output logic [NOutputs-1:0]     pwm_o
);

  logic [31:0] common_param_d;
  assign common_param_d = {reg2hw.cfg.clk_div.q,
                           reg2hw.cfg.dc_resn.q,
                           reg2hw.cfg.cntr_en.q};

  logic [31:0] common_param_q;

  always_ff @(posedge clk_core_i or negedge rst_core_ni) begin
    if (!rst_core_ni) begin
      common_param_q <= 32'h0;
    end else begin
      common_param_q <= common_param_d;
    end
  end

  // Reset internal counters whenever parameters change.

  logic                clr_phase_cntr;
  logic [NOutputs-1:0] clr_blink_cntr;

  assign clr_phase_cntr = (common_param_q != common_param_d);

  for (genvar ii = 0; ii < NOutputs; ii++) begin : gen_chan_clr

    logic [83:0] chan_param_d;
    assign chan_param_d  = {reg2hw.pwm_en[ii].q,
                            reg2hw.invert[ii].q,
                            reg2hw.pwm_param[ii].phase_delay.q,
                            reg2hw.pwm_param[ii].htbt_en.q,
                            reg2hw.pwm_param[ii].blink_en.q,
                            reg2hw.duty_cycle[ii].a.q,
                            reg2hw.duty_cycle[ii].b.q,
                            reg2hw.blink_param[ii].x.q,
                            reg2hw.blink_param[ii].y.q};

    logic [83:0] chan_param_q;

    always_ff @(posedge clk_core_i or negedge rst_core_ni) begin
      if (!rst_core_ni) begin
        chan_param_q <= 84'h0;
      end else begin
        chan_param_q <= chan_param_d;
      end
    end

    // Though it may be a bit overkill, we reset the internal blink counters whenever any channel
    // specific parameters change.

    assign clr_blink_cntr[ii] = (chan_param_q != chan_param_d);

  end : gen_chan_clr

  //
  // Beat and phase counters (in core clock domain)
  //

  logic        cntr_en;
  logic [26:0] clk_div;
  logic [3:0]  dc_resn;

  logic [26:0] beat_ctr_q;
  logic [26:0] beat_ctr_d;
  logic        beat_ctr_en;
  logic        beat_end;

  logic [15:0] phase_ctr_q;
  logic [15:0] phase_ctr_d;
  logic [15:0] phase_ctr_incr;
  logic [15:0] phase_ctr_next;
  logic        phase_ctr_overflow;
  logic        phase_ctr_en;
  logic        cycle_end;

  logic        unused_regen;

  // TODO: implement register locking
  assign unused_regen = reg2hw.regen.q;

  assign cntr_en = reg2hw.cfg.cntr_en.q;
  assign dc_resn = reg2hw.cfg.dc_resn.q;
  assign clk_div = reg2hw.cfg.clk_div.q;

  assign beat_ctr_d = (clr_phase_cntr) ? 27'h0 :
                      (beat_ctr_q == clk_div) ? 27'h0 : (beat_ctr_q + 27'h1);
  assign beat_ctr_en = clr_phase_cntr | cntr_en;
  assign beat_end = (beat_ctr_q == clk_div);

  always_ff @(posedge clk_core_i or negedge rst_core_ni) begin
    if (!rst_core_ni) begin
      beat_ctr_q <= 27'h0;
    end else begin
      beat_ctr_q <= beat_ctr_en ? beat_ctr_d : beat_ctr_q;
    end
  end

  // Only update phase_ctr at the end of each beat
  // Exception: allow reset to zero whenever not enabled
  assign phase_ctr_en = beat_end & (clr_phase_cntr | cntr_en);
  assign phase_ctr_incr =  16'h1 << (15 -dc_resn);
  assign {phase_ctr_overflow, phase_ctr_next} = phase_ctr_q + phase_ctr_incr;
  assign phase_ctr_d = clr_phase_cntr ? 16'h0 : phase_ctr_next;
  assign cycle_end = beat_end & phase_ctr_overflow;

  always_ff @(posedge clk_core_i or negedge rst_core_ni) begin
    if (!rst_core_ni) begin
      phase_ctr_q <= 16'h0;
    end else begin
      phase_ctr_q <= phase_ctr_en ? phase_ctr_d : phase_ctr_q;
    end
  end

  for (genvar ii = 0; ii < NOutputs; ii++) begin : gen_chan_insts

    //
    // PWM Channel Instantiation
    //

    pwm_chan u_chan (
      .clk_i            (clk_core_i),
      .rst_ni           (rst_core_ni),
      .pwm_en_i         (reg2hw.pwm_en[ii].q),
      .invert_i         (reg2hw.invert[ii].q),
      .phase_delay_i    (reg2hw.pwm_param[ii].phase_delay.q),
      .blink_en_i       (reg2hw.pwm_param[ii].blink_en.q),
      .htbt_en_i        (reg2hw.pwm_param[ii].htbt_en.q),
      .duty_cycle_a_i   (reg2hw.duty_cycle[ii].a.q),
      .duty_cycle_b_i   (reg2hw.duty_cycle[ii].b.q),
      .blink_param_x_i  (reg2hw.blink_param[ii].x.q),
      .blink_param_y_i  (reg2hw.blink_param[ii].y.q),
      .phase_ctr_i      (phase_ctr_q),
      .clr_blink_cntr_i (clr_blink_cntr[ii]),
      .cycle_end_i      (cycle_end),
      .dc_resn_i        (dc_resn),
      .pwm_o            (pwm_o[ii])
    );

  end : gen_chan_insts

  // unused register configuration
  logic unused_reg;
  assign unused_reg = ^reg2hw.alert_test;

endmodule : pwm_core
