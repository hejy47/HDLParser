// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Matthias Baer - baermatt@student.ethz.ch                   //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Main controller                                            //
// Project Name:   ibex                                                       //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Main controller of the processor                           //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

/**
 * Main controller of the processor
 */
module ibex_controller (
    input  logic                      clk_i,
    input  logic                      rst_ni,

    input  logic                      fetch_enable_i,        // start decoding
    output logic                      ctrl_busy_o,           // core is busy processing instrs
    output logic                      first_fetch_o,         // core is at the FIRST FETCH stage

    // decoder related signals
    input  logic                      illegal_insn_i,        // decoder has an invalid instr
    input  logic                      ecall_insn_i,          // decoder has ECALL instr
    input  logic                      mret_insn_i,           // decoder has MRET instr
    input  logic                      dret_insn_i,           // decoder has DRET instr
    input  logic                      wfi_insn_i,            // decoder has WFI instr
    input  logic                      ebrk_insn_i,           // decoder has EBREAK instr
    input  logic                      csr_status_i,          // decoder has CSR status instr

    // from IF-ID pipeline stage
    input  logic                      instr_valid_i,         // instr from IF-ID reg is valid
    input  logic [31:0]               instr_i,               // instr from IF-ID reg, for mtval
    input  logic [15:0]               instr_compressed_i,    // instr from IF-ID reg, for mtval
    input  logic                      instr_is_compressed_i, // instr from IF-ID reg is compressed

    // to IF-ID pipeline stage
    output logic                      instr_valid_clear_o,   // kill instr in IF-ID reg
    output logic                      id_in_ready_o,         // ID stage is ready for new instr

    // to prefetcher
    output logic                      instr_req_o,           // start fetching instructions
    output logic                      pc_set_o,              // jump to address set by pc_mux
    output ibex_defines::pc_sel_e     pc_mux_o,              // IF stage fetch address selector
                                                             // (boot, normal, exception...)
    output ibex_defines::exc_pc_sel_e exc_pc_mux_o,          // IF stage selector for exception PC

    // LSU
    input  logic [31:0]               lsu_addr_last_i,       // for mtval
    input  logic                      load_err_i,
    input  logic                      store_err_i,

    // jump/branch signals
    input  logic                      branch_set_i,          // branch taken set signal
    input  logic                      jump_set_i,            // jump taken set signal

    // External Interrupt Req Signals, used to wake up from wfi even if the interrupt is not taken
    input  logic                      irq_i,
    // Interrupt Controller Signals
    input  logic                      irq_req_ctrl_i,
    input  logic [4:0]                irq_id_ctrl_i,
    input  logic                      m_IE_i,                // interrupt enable bit from CSR
                                                             // (M mode)

    output logic                      irq_ack_o,
    output logic [4:0]                irq_id_o,

    output ibex_defines::exc_cause_e  exc_cause_o,
    output logic                      exc_ack_o,
    output logic                      exc_kill_o,

    // debug signals
    input  logic                      debug_req_i,
    output ibex_defines::dbg_cause_e  debug_cause_o,
    output logic                      debug_csr_save_o,
    input  logic                      debug_single_step_i,
    input  logic                      debug_ebreakm_i,

    output logic                      csr_save_if_o,
    output logic                      csr_save_id_o,
    output logic                      csr_restore_mret_id_o,
    output logic                      csr_restore_dret_id_o,
    output logic                      csr_save_cause_o,
    output logic [31:0]               csr_mtval_o,

    // stall signals
    input  logic                      stall_lsu_i,
    input  logic                      stall_multdiv_i,
    input  logic                      stall_jump_i,
    input  logic                      stall_branch_i,

    // performance monitors
    output logic                      perf_jump_o,           // we are executing a jump
                                                             // instruction (j, jr, jal, jalr)
    output logic                      perf_tbranch_o         // we are executing a taken branch
                                                             // instruction
);
  import ibex_defines::*;

  // FSM state encoding
  typedef enum logic [3:0] {
    RESET, BOOT_SET, WAIT_SLEEP, SLEEP, FIRST_FETCH, DECODE, FLUSH,
    IRQ_TAKEN, DBG_TAKEN_IF, DBG_TAKEN_ID
  } ctrl_fsm_e;

  ctrl_fsm_e ctrl_fsm_cs, ctrl_fsm_ns;

  logic debug_mode_q, debug_mode_d;
  logic load_err_q, load_err_d;
  logic store_err_q, store_err_d;

  logic stall;
  logic halt_if;
  logic halt_id;
  logic exc_req;
  logic exc_req_lsu;
  logic special_req;
  logic enter_debug_mode;
  logic handle_irq;

`ifndef SYNTHESIS
  // synopsys translate_off
  // make sure we are called later so that we do not generate messages for
  // glitches
  always_ff @(negedge clk_i) begin
    // print warning in case of decoding errors
    if ((ctrl_fsm_cs == DECODE) && instr_valid_i && illegal_insn_i) begin
      $display("%t: Illegal instruction (core %0d) at PC 0x%h: 0x%h", $time, ibex_core.core_id_i,
               ibex_id_stage.pc_id_i, ibex_id_stage.instr_rdata_i);
    end
  end
  // synopsys translate_on
`endif

  ////////////////
  // Exceptions //
  ////////////////

  assign load_err_d  = load_err_i;
  assign store_err_d = store_err_i;

  // exception requests
  assign exc_req     = ecall_insn_i | ebrk_insn_i | illegal_insn_i;

  // LSU exception requests
  assign exc_req_lsu = store_err_i | load_err_i;

  // special requests: special instructions, pipeline flushes, exceptions...
  assign special_req = mret_insn_i | dret_insn_i | wfi_insn_i | csr_status_i |
      exc_req | exc_req_lsu;

  ////////////////
  // Interrupts //
  ////////////////

  assign enter_debug_mode = debug_req_i & ~debug_mode_q;

  // interrupts including NMI are ignored while in debug mode [Debug Spec v0.13.2, p.39]
  assign handle_irq       = irq_req_ctrl_i & m_IE_i & ~debug_mode_q;
  assign exc_kill_o       = 1'b0;

  /////////////////////
  // Core controller //
  /////////////////////

  always_comb begin
    // Default values
    instr_req_o           = 1'b1;

    exc_ack_o             = 1'b0;

    csr_save_if_o         = 1'b0;
    csr_save_id_o         = 1'b0;
    csr_restore_mret_id_o = 1'b0;
    csr_restore_dret_id_o = 1'b0;
    csr_save_cause_o      = 1'b0;
    csr_mtval_o           = '0;

    pc_mux_o              = PC_BOOT;
    pc_set_o              = 1'b0;

    exc_pc_mux_o          = EXC_PC_IRQ;
    exc_cause_o           = EXC_CAUSE_INSN_ADDR_MISA; // = 6'h00

    ctrl_fsm_ns           = ctrl_fsm_cs;

    ctrl_busy_o           = 1'b1;
    first_fetch_o         = 1'b0;

    halt_if               = 1'b0;
    halt_id               = 1'b0;
    irq_ack_o             = 1'b0;
    irq_id_o              = irq_id_ctrl_i;

    debug_csr_save_o      = 1'b0;
    debug_cause_o         = DBG_CAUSE_EBREAK;
    debug_mode_d          = debug_mode_q;

    perf_tbranch_o        = 1'b0;
    perf_jump_o           = 1'b0;

    unique case (ctrl_fsm_cs)
      RESET: begin
        // just wait for fetch_enable
        instr_req_o   = 1'b0;
        pc_mux_o      = PC_BOOT;
        pc_set_o      = 1'b1;
        if (fetch_enable_i) begin
          ctrl_fsm_ns = BOOT_SET;
        end
      end

      BOOT_SET: begin
        // copy boot address to instr fetch address
        instr_req_o   = 1'b1;
        pc_mux_o      = PC_BOOT;
        pc_set_o      = 1'b1;

        ctrl_fsm_ns = FIRST_FETCH;
      end

      WAIT_SLEEP: begin
        ctrl_busy_o   = 1'b0;
        instr_req_o   = 1'b0;
        halt_if       = 1'b1;
        halt_id       = 1'b1;
        ctrl_fsm_ns   = SLEEP;
      end

      SLEEP: begin
        // instruction in IF stage is already valid
        // we begin execution when an interrupt has arrived
        ctrl_busy_o   = 1'b0;
        instr_req_o   = 1'b0;
        halt_if       = 1'b1;
        halt_id       = 1'b1;

        // normal execution flow
        // in debug mode or single step mode we leave immediately (wfi=nop)
        if (irq_i || debug_req_i || debug_mode_q || debug_single_step_i) begin
          ctrl_fsm_ns  = FIRST_FETCH;
        end
      end

      FIRST_FETCH: begin
        first_fetch_o = 1'b1;
        // Stall because of IF miss
        if (id_in_ready_o) begin
          ctrl_fsm_ns = DECODE;
        end

        // handle interrupts
        if (handle_irq) begin
          // This assumes that the pipeline is always flushed before
          // going to sleep.
          ctrl_fsm_ns = IRQ_TAKEN;
          halt_if     = 1'b1;
          halt_id     = 1'b1;
        end

        // enter debug mode
        if (enter_debug_mode) begin
          ctrl_fsm_ns = DBG_TAKEN_IF;
          halt_if     = 1'b1;
          halt_id     = 1'b1;
        end
      end

      DECODE: begin
        // normal operating mode of the ID stage, in case of debug and interrupt requests,
        // priorities are as follows (lower number == higher priority)
        // 1. currently running (multicycle) instructions and exceptions caused by these
        // 2. debug requests
        // 3. interrupt requests

        if (instr_valid_i) begin

          // set PC in IF stage to branch or jump target
          if (branch_set_i || jump_set_i) begin
            pc_mux_o       = PC_JUMP;
            pc_set_o       = 1'b1;

            perf_tbranch_o = branch_set_i;
            perf_jump_o    = jump_set_i;

          // get ready for special instructions, exceptions, pipeline flushes
          end else if (special_req) begin
            ctrl_fsm_ns = FLUSH;
            halt_if     = 1'b1;
            halt_id     = 1'b1;
          end

          // stall IF stage to not starve debug and interrupt requests, these just
          // need to wait until after the current (multicycle) instruction
          if ((enter_debug_mode || handle_irq) && stall) begin
            halt_if = 1'b1;
          end

          // single stepping:
          // execute a single instruction and then enter debug mode, in case of exceptions,
          // set registers but do not jump into handler [Debug Spec v0.13.2, p.44]
          if (debug_single_step_i && !debug_mode_q) begin
            halt_if = 1'b1;

            if (!special_req && !stall) begin
              ctrl_fsm_ns = DBG_TAKEN_IF;
            end
          end
        end // instr_valid_i

        if (!stall && !special_req) begin
          if (enter_debug_mode) begin
            // enter debug mode
            ctrl_fsm_ns = DBG_TAKEN_ID;
            halt_if     = 1'b1;
            halt_id     = 1'b1;

          end else if (handle_irq) begin
            // handle interrupt (not in debug mode)
            ctrl_fsm_ns = IRQ_TAKEN;
            halt_if     = 1'b1;
            halt_id     = 1'b1;
          end
        end

      end // DECODE

      IRQ_TAKEN: begin
        pc_mux_o         = PC_EXC;
        pc_set_o         = 1'b1;

        exc_pc_mux_o     = EXC_PC_IRQ;
        exc_cause_o      = exc_cause_e'({1'b1, irq_id_ctrl_i});

        csr_save_cause_o = 1'b1;
        csr_save_if_o    = 1'b1;

        irq_ack_o        = 1'b1;
        exc_ack_o        = 1'b1;

        ctrl_fsm_ns      = DECODE;
      end

      DBG_TAKEN_IF: begin
        // enter debug mode and save PC in IF to dpc
        // jump to debug exception handler in debug memory
        if (debug_single_step_i || debug_req_i) begin
          pc_mux_o         = PC_EXC;
          pc_set_o         = 1'b1;
          exc_pc_mux_o     = EXC_PC_DBD;

          csr_save_if_o    = 1'b1;
          debug_csr_save_o = 1'b1;

          csr_save_cause_o = 1'b1;
          if (debug_single_step_i) begin
            debug_cause_o = DBG_CAUSE_STEP;
          end else begin
            debug_cause_o = DBG_CAUSE_HALTREQ;
          end

          // enter debug mode
          debug_mode_d = 1'b1;
        end

        ctrl_fsm_ns  = DECODE;
      end

      DBG_TAKEN_ID: begin
        // enter debug mode and save PC in ID to dpc, used when encountering
        // 1. EBREAK during debug mode
        // 2. EBREAK with forced entry into debug mode (ebreakm or ebreaku set).
        // 3. halt request during decode
        // regular ebreak's go through FLUSH.
        //
        // for 1. do not update dcsr and dpc, for 2. and 3. do so [Debug Spec v0.13.2, p.39]
        // jump to debug exception handler in debug memory
        if (ebrk_insn_i || debug_req_i) begin
          pc_mux_o     = PC_EXC;
          pc_set_o     = 1'b1;
          exc_pc_mux_o = EXC_PC_DBD;

          // update dcsr and dpc
          if ((ebrk_insn_i && debug_ebreakm_i && !debug_mode_q) || // ebreak with forced entry
              (enter_debug_mode)) begin // halt request

            // dpc (set to the address of the EBREAK, i.e. set to PC in ID stage)
            csr_save_cause_o = 1'b1;
            csr_save_id_o    = 1'b1;

            // dcsr
            debug_csr_save_o = 1'b1;
            if (debug_req_i) begin
              debug_cause_o = DBG_CAUSE_HALTREQ;
            end else begin
              debug_cause_o = DBG_CAUSE_EBREAK;
            end
          end

          // enter debug mode
          debug_mode_d = 1'b1;
        end

        ctrl_fsm_ns  = DECODE;
      end

      FLUSH: begin
        // flush the pipeline
        halt_if     = 1'b1;
        halt_id     = 1'b1;
        ctrl_fsm_ns = DECODE;

        // exceptions: set exception PC, save PC and exception cause
        // exc_req_lsu is high for one clock cycle only (in DECODE)
        if (exc_req || store_err_q || load_err_q) begin
          pc_set_o         = 1'b1;
          pc_mux_o         = PC_EXC;
          exc_pc_mux_o     = debug_mode_q ? EXC_PC_DBG_EXC : EXC_PC_EXC;
          csr_save_id_o    = 1'b1;
          csr_save_cause_o = 1'b1;

          // set exception registers, priorities according to Table 3.7 of Privileged Spec v1.11
          if (illegal_insn_i) begin
            exc_cause_o = EXC_CAUSE_ILLEGAL_INSN;
            csr_mtval_o = instr_is_compressed_i ? {16'b0, instr_compressed_i} : instr_i;

          end else if (ecall_insn_i) begin
            exc_cause_o = EXC_CAUSE_ECALL_MMODE;

          end else if (ebrk_insn_i) begin
            if (debug_mode_q) begin
              /*
               * EBREAK in debug mode re-enters debug mode
               *
               * "The only exception is EBREAK. When that is executed in Debug
               * Mode, it halts the hart again but without updating dpc or
               * dcsr." [Debug Spec v0.13.2, p.39]
               */
              pc_set_o         = 1'b0;
              csr_save_id_o    = 1'b0;
              csr_save_cause_o = 1'b0;
              ctrl_fsm_ns      = DBG_TAKEN_ID;
            end else if (debug_ebreakm_i) begin
              /*
               * dcsr.ebreakm == 1:
               * "EBREAK instructions in M-mode enter Debug Mode."
               * [Debug Spec v0.13.2, p.42]
               */
              pc_set_o         = 1'b0;
              csr_save_id_o    = 1'b0;
              csr_save_cause_o = 1'b0;
              ctrl_fsm_ns      = DBG_TAKEN_ID;
            end else begin
              /*
               * "The EBREAK instruction is used by debuggers to cause control
               * to be transferred back to a debugging environment. It
               * generates a breakpoint exception and performs no other
               * operation. [...] ECALL and EBREAK cause the receiving
               * privilege mode’s epc register to be set to the address of the
               * ECALL or EBREAK instruction itself, not the address of the
               * following instruction." [Privileged Spec v1.11, p.40]
               */
              exc_cause_o      = EXC_CAUSE_BREAKPOINT;
            end

          end else if (store_err_q) begin
            exc_cause_o = EXC_CAUSE_STORE_ACCESS_FAULT;
            csr_mtval_o = lsu_addr_last_i;

          end else if (load_err_q) begin
            exc_cause_o = EXC_CAUSE_LOAD_ACCESS_FAULT;
            csr_mtval_o = lsu_addr_last_i;
          end

        end else begin
          // special instructions
          if (mret_insn_i) begin
            pc_mux_o              = PC_ERET;
            pc_set_o              = 1'b1;
            csr_restore_mret_id_o = 1'b1;
          end else if (dret_insn_i) begin
            pc_mux_o              = PC_DRET;
            pc_set_o              = 1'b1;
            csr_restore_dret_id_o = 1'b1;
            debug_mode_d          = 1'b0;
          end else if (wfi_insn_i) begin
            ctrl_fsm_ns           = WAIT_SLEEP;
          end
        end // exc_req

        // single stepping
        // set exception registers, but do not jump into handler [Debug Spec v0.13.2, p.44]
        if (debug_single_step_i && !debug_mode_q) begin
          pc_set_o    = 1'b0;
          ctrl_fsm_ns = DBG_TAKEN_IF;
        end
      end // FLUSH

      default: begin
        instr_req_o = 1'b0;
        ctrl_fsm_ns = ctrl_fsm_e'(1'bX);
      end
    endcase
  end

  ///////////////////
  // Stall control //
  ///////////////////

  // if high, current instr needs at least one more cycle to finish after the current cycle
  // if low, current instr finishes in current cycle
  // multicycle instructions have this set except during the last cycle
  assign stall = stall_lsu_i | stall_multdiv_i | stall_jump_i | stall_branch_i;

  // signal to IF stage that ID stage is ready for next instr
  assign id_in_ready_o       = ~stall & ~halt_if;

  // kill instr in IF-ID pipeline reg that are done, or if a
  // multicycle instr causes an exception for example
  assign instr_valid_clear_o = ~stall |  halt_id;

  // update registers
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_regs
    if (!rst_ni) begin
      ctrl_fsm_cs  <= RESET;
      debug_mode_q <= 1'b0;
      load_err_q   <= 1'b0;
      store_err_q  <= 1'b0;
    end else begin
      ctrl_fsm_cs  <= ctrl_fsm_ns;
      debug_mode_q <= debug_mode_d;
      load_err_q   <= load_err_d;
      store_err_q  <= store_err_d;
    end
  end

endmodule
