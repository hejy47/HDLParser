// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Renzo Andri - andrire@student.ethz.ch                      //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Instruction Decode Stage                                   //
// Project Name:   ibex                                                       //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decode stage of the core. It decodes the instructions      //
//                 and hosts the register file.                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`ifdef RISCV_FORMAL
  `define RVFI
`endif

/**
 * Instruction Decode Stage
 *
 * Decode stage of the core. It decodes the instructions and hosts the register
 * file.
 */
module ibex_id_stage #(
    parameter bit RV32E = 0,
    parameter bit RV32M = 1
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,

    input  logic                      test_en_i,

    input  logic                      fetch_enable_i,
    output logic                      ctrl_busy_o,
    output logic                      core_ctrl_firstfetch_o,
    output logic                      is_decoding_o,
    output logic                      illegal_insn_o,

    // Interface to IF stage
    input  logic                      instr_valid_i,
    input  logic                      instr_new_i,
    input  logic [31:0]               instr_rdata_i,         // from IF-ID pipeline registers
    input  logic [15:0]               instr_rdata_c_i,       // from IF-ID pipeline registers
    input  logic                      instr_is_compressed_i,
    output logic                      instr_req_o,
    output logic                      instr_valid_clear_o,   // kill instr in IF-ID reg
    output logic                      id_ready_o,            // ID stage is ready for next instr
    output logic                      halt_if_o,             // ID stage requests IF stage to halt

    // Jumps and branches
    input  logic                      branch_decision_i,

    // IF and ID stage signals
    output logic                      pc_set_o,
    output ibex_defines::pc_sel_e     pc_mux_o,
    output ibex_defines::exc_pc_sel_e exc_pc_mux_o,

    input  logic                      illegal_c_insn_i,

    input  logic [31:0]               pc_id_i,

    // Stalls
    input  logic                      ex_valid_i,  // EX stage has valid output
    input  logic                      lsu_valid_i, // LSU has valid output, or is done
    output logic                      id_valid_o,  // ID stage is done

    // ALU
    output ibex_defines::alu_op_e     alu_operator_ex_o,
    output logic [31:0]               alu_operand_a_ex_o,
    output logic [31:0]               alu_operand_b_ex_o,

    // MUL, DIV
    output logic                      mult_en_ex_o,
    output logic                      div_en_ex_o,
    output ibex_defines::md_op_e      multdiv_operator_ex_o,
    output logic  [1:0]               multdiv_signed_mode_ex_o,
    output logic [31:0]               multdiv_operand_a_ex_o,
    output logic [31:0]               multdiv_operand_b_ex_o,

    // CSR
    output logic                      csr_access_o,
    output ibex_defines::csr_op_e     csr_op_o,
    output logic                      csr_save_if_o,
    output logic                      csr_save_id_o,
    output logic                      csr_restore_mret_id_o,
    output logic                      csr_restore_dret_id_o,
    output logic                      csr_save_cause_o,
    output logic [31:0]               csr_mtval_o,
    input  logic                      illegal_csr_insn_i,

    // Interface to load store unit
    output logic                      data_req_ex_o,
    output logic                      data_we_ex_o,
    output logic [1:0]                data_type_ex_o,
    output logic                      data_sign_ext_ex_o,
    output logic [1:0]                data_reg_offset_ex_o,
    output logic [31:0]               data_wdata_ex_o,

    input  logic                      data_misaligned_i,
    input  logic [31:0]               lsu_addr_last_i,

    // Interrupt signals
    input  logic                      irq_i,
    input  logic [4:0]                irq_id_i,
    input  logic                      m_irq_enable_i,
    output logic                      irq_ack_o,
    output logic [4:0]                irq_id_o,
    output ibex_defines::exc_cause_e  exc_cause_o,

    input  logic                      lsu_load_err_i,
    input  logic                      lsu_store_err_i,

    // Debug Signal
    output ibex_defines::dbg_cause_e  debug_cause_o,
    output logic                      debug_csr_save_o,
    input  logic                      debug_req_i,
    input  logic                      debug_single_step_i,
    input  logic                      debug_ebreakm_i,

    // Write back signal
    input  logic [31:0]               regfile_wdata_lsu_i,
    input  logic [31:0]               regfile_wdata_ex_i,
    input  logic [31:0]               csr_rdata_i,

`ifdef RVFI
    output logic [4:0]                rfvi_reg_raddr_ra_o,
    output logic [31:0]               rfvi_reg_rdata_ra_o,
    output logic [4:0]                rfvi_reg_raddr_rb_o,
    output logic [31:0]               rfvi_reg_rdata_rb_o,
    output logic [4:0]                rfvi_reg_waddr_rd_o,
    output logic [31:0]               rfvi_reg_wdata_rd_o,
    output logic                      rfvi_reg_we_o,
`endif

    // Performance Counters
    output logic                      perf_jump_o,    // executing a jump instr
    output logic                      perf_branch_o,  // executing a branch instr
    output logic                      perf_tbranch_o  // executing a taken branch instr
);

  import ibex_defines::*;

  // Decoder/Controller ID stage internal signals
  logic        deassert_we;

  logic        illegal_insn_dec;
  logic        ebrk_insn;
  logic        mret_insn_dec;
  logic        dret_insn_dec;
  logic        ecall_insn_dec;
  logic        pipe_flush_dec;

  logic        branch_in_id, branch_in_dec;
  logic        branch_set_n, branch_set_q;
  logic        jump_in_dec;
  logic        jump_set;

  logic        instr_executing;
  logic        instr_multicycle;
  logic        instr_multicycle_done_n, instr_multicycle_done_q;
  logic        stall_lsu;
  logic        stall_multdiv;
  logic        stall_branch;
  logic        stall_jump;

  // Immediate decoding and sign extension
  logic [31:0] imm_i_type;
  logic [31:0] imm_s_type;
  logic [31:0] imm_b_type;
  logic [31:0] imm_u_type;
  logic [31:0] imm_j_type;
  logic [31:0] zimm_rs1_type;

  logic [31:0] imm_a;       // contains the immediate for operand b
  logic [31:0] imm_b;       // contains the immediate for operand b

  // Signals running between controller and exception controller
  logic       irq_req_ctrl;
  logic [4:0] irq_id_ctrl;
  logic       exc_ack, exc_kill;// handshake

  // Register file interface
  logic [4:0]  regfile_raddr_a;
  logic [4:0]  regfile_raddr_b;

  logic [4:0]  regfile_waddr;
  logic        regfile_we_id, regfile_we_dec;

  logic [31:0] regfile_rdata_a;
  logic [31:0] regfile_rdata_b;
  logic [31:0] regfile_wdata;

  rf_wd_sel_e  regfile_wdata_sel;
  logic        regfile_we;

  // ALU Control
  alu_op_e     alu_operator;
  op_a_sel_e   alu_op_a_mux_sel, alu_op_a_mux_sel_dec;
  op_b_sel_e   alu_op_b_mux_sel, alu_op_b_mux_sel_dec;

  imm_a_sel_e  imm_a_mux_sel;
  imm_b_sel_e  imm_b_mux_sel, imm_b_mux_sel_dec;

  // Multiplier Control
  logic        mult_en_id, mult_en_dec; // use integer multiplier
  logic        div_en_id, div_en_dec;   // use integer division or reminder
  logic        multdiv_en_dec;
  md_op_e      multdiv_operator;
  logic [1:0]  multdiv_signed_mode;

  // Data Memory Control
  logic        data_we_id;
  logic [1:0]  data_type_id;
  logic        data_sign_ext_id;
  logic [1:0]  data_reg_offset_id;
  logic        data_req_id, data_req_dec;

  // CSR control
  logic        csr_status;

  // For tracer
  logic [31:0] operand_a_fw_id, unused_operand_a_fw_id;
  logic [31:0] operand_b_fw_id, unused_operand_b_fw_id;

  logic [31:0] alu_operand_a;
  logic [31:0] alu_operand_b;

  /////////////
  // LSU Mux //
  /////////////

  // Misaligned loads/stores result in two aligned loads/stores, compute second address
  assign alu_op_a_mux_sel = data_misaligned_i ? OP_A_FWD        : alu_op_a_mux_sel_dec;
  assign alu_op_b_mux_sel = data_misaligned_i ? OP_B_IMM        : alu_op_b_mux_sel_dec;
  assign imm_b_mux_sel    = data_misaligned_i ? IMM_B_INCR_ADDR : imm_b_mux_sel_dec;

  // do not write back the second address since the first calculated address was the correct one
  assign regfile_we_id    = data_misaligned_i ? 1'b0            : regfile_we_dec & ~deassert_we;

  ///////////////////
  // Operand A MUX //
  ///////////////////

  // Immediate MUX for Operand A
  assign imm_a = (imm_a_mux_sel == IMM_A_Z) ? zimm_rs1_type : '0;

  // ALU MUX for Operand A
  always_comb begin : alu_operand_a_mux
    unique case (alu_op_a_mux_sel)
      OP_A_REG_A:  alu_operand_a = regfile_rdata_a;
      OP_A_FWD:    alu_operand_a = lsu_addr_last_i;
      OP_A_CURRPC: alu_operand_a = pc_id_i;
      OP_A_IMM:    alu_operand_a = imm_a;
      default:     alu_operand_a = 'X;
    endcase
  end

  ///////////////////
  // Operand B MUX //
  ///////////////////

  // Immediate MUX for Operand B
  always_comb begin : immediate_b_mux
    unique case (imm_b_mux_sel)
      IMM_B_I:         imm_b = imm_i_type;
      IMM_B_S:         imm_b = imm_s_type;
      IMM_B_B:         imm_b = imm_b_type;
      IMM_B_U:         imm_b = imm_u_type;
      IMM_B_J:         imm_b = imm_j_type;
      IMM_B_INCR_PC:   imm_b = instr_is_compressed_i ? 32'h2 : 32'h4;
      IMM_B_INCR_ADDR: imm_b = 32'h4;
      default:         imm_b = 'X;
    endcase
  end

  // ALU MUX for Operand B
  assign alu_operand_b = (alu_op_b_mux_sel == OP_B_IMM) ? imm_b : regfile_rdata_b;

  // Signals used by tracer
  assign operand_a_fw_id = data_misaligned_i ? lsu_addr_last_i : regfile_rdata_a;
  assign operand_b_fw_id = regfile_rdata_b;

  assign unused_operand_a_fw_id = operand_a_fw_id;
  assign unused_operand_b_fw_id = operand_b_fw_id;

  ///////////////////////
  // Register File MUX //
  ///////////////////////

  // Register file write data mux
  always_comb begin : regfile_wdata_mux
    unique case (regfile_wdata_sel)
      RF_WD_EX:  regfile_wdata = regfile_wdata_ex_i;
      RF_WD_LSU: regfile_wdata = regfile_wdata_lsu_i;
      RF_WD_CSR: regfile_wdata = csr_rdata_i;
      default:   regfile_wdata = 'X;
    endcase;
  end

  ///////////////////
  // Register File //
  ///////////////////

  ibex_register_file #( .RV32E ( RV32E ) ) registers_i (
      .clk_i        ( clk_i           ),
      .rst_ni       ( rst_ni          ),

      .test_en_i    ( test_en_i       ),

      // Read port a
      .raddr_a_i    ( regfile_raddr_a ),
      .rdata_a_o    ( regfile_rdata_a ),
      // Read port b
      .raddr_b_i    ( regfile_raddr_b ),
      .rdata_b_o    ( regfile_rdata_b ),
      // write port
      .waddr_a_i    ( regfile_waddr   ),
      .wdata_a_i    ( regfile_wdata   ),
      .we_a_i       ( regfile_we      )
  );

`ifdef RVFI
  assign rfvi_reg_raddr_ra_o = regfile_raddr_a;
  assign rfvi_reg_rdata_ra_o = regfile_rdata_a;
  assign rfvi_reg_raddr_rb_o = regfile_raddr_b;
  assign rfvi_reg_rdata_rb_o = regfile_rdata_b;
  assign rfvi_reg_waddr_rd_o = regfile_waddr;
  assign rfvi_reg_wdata_rd_o = regfile_wdata;
  assign rfvi_reg_we_o       = regfile_we;
`endif

  /////////////
  // Decoder //
  /////////////

  ibex_decoder #(
      .RV32E ( RV32E ),
      .RV32M ( RV32M )
  ) decoder_i (
      // controller
      .illegal_insn_o                  ( illegal_insn_dec     ),
      .ebrk_insn_o                     ( ebrk_insn            ),
      .mret_insn_o                     ( mret_insn_dec        ),
      .dret_insn_o                     ( dret_insn_dec        ),
      .ecall_insn_o                    ( ecall_insn_dec       ),
      .pipe_flush_o                    ( pipe_flush_dec       ),
      .jump_set_o                      ( jump_set             ),

      // from IF-ID pipeline register
      .instr_new_i                     ( instr_new_i          ),
      .instr_rdata_i                   ( instr_rdata_i        ),
      .illegal_c_insn_i                ( illegal_c_insn_i     ),

      // immediates
      .imm_a_mux_sel_o                 ( imm_a_mux_sel        ),
      .imm_b_mux_sel_o                 ( imm_b_mux_sel_dec    ),

      .imm_i_type_o                    ( imm_i_type           ),
      .imm_s_type_o                    ( imm_s_type           ),
      .imm_b_type_o                    ( imm_b_type           ),
      .imm_u_type_o                    ( imm_u_type           ),
      .imm_j_type_o                    ( imm_j_type           ),
      .zimm_rs1_type_o                 ( zimm_rs1_type        ),

      // register file
      .regfile_wdata_sel_o             ( regfile_wdata_sel    ),
      .regfile_we_o                    ( regfile_we_dec       ),

      .regfile_raddr_a_o               ( regfile_raddr_a      ),
      .regfile_raddr_b_o               ( regfile_raddr_b      ),
      .regfile_waddr_o                 ( regfile_waddr        ),

      // ALU
      .alu_operator_o                  ( alu_operator         ),
      .alu_op_a_mux_sel_o              ( alu_op_a_mux_sel_dec ),
      .alu_op_b_mux_sel_o              ( alu_op_b_mux_sel_dec ),

      // MULT & DIV
      .mult_en_o                       ( mult_en_dec          ),
      .div_en_o                        ( div_en_dec           ),
      .multdiv_operator_o              ( multdiv_operator     ),
      .multdiv_signed_mode_o           ( multdiv_signed_mode  ),

      // CSRs
      .csr_access_o                    ( csr_access_o         ),
      .csr_op_o                        ( csr_op_o             ),
      .csr_status_o                    ( csr_status           ),

      // LSU
      .data_req_o                      ( data_req_dec         ),
      .data_we_o                       ( data_we_id           ),
      .data_type_o                     ( data_type_id         ),
      .data_sign_extension_o           ( data_sign_ext_id     ),
      .data_reg_offset_o               ( data_reg_offset_id   ),

      // jump/branches
      .jump_in_dec_o                   ( jump_in_dec          ),
      .branch_in_dec_o                 ( branch_in_dec        )
  );

  ////////////////
  // Controller //
  ////////////////

  assign illegal_insn_o = illegal_insn_dec | illegal_csr_insn_i;

  ibex_controller controller_i (
      .clk_i                          ( clk_i                  ),
      .rst_ni                         ( rst_ni                 ),

      .fetch_enable_i                 ( fetch_enable_i         ),
      .ctrl_busy_o                    ( ctrl_busy_o            ),
      .first_fetch_o                  ( core_ctrl_firstfetch_o ),
      .is_decoding_o                  ( is_decoding_o          ),

      // decoder related signals
      .deassert_we_o                  ( deassert_we            ),
      .illegal_insn_i                 ( illegal_insn_o         ),
      .ecall_insn_i                   ( ecall_insn_dec         ),
      .mret_insn_i                    ( mret_insn_dec          ),
      .dret_insn_i                    ( dret_insn_dec          ),
      .pipe_flush_i                   ( pipe_flush_dec         ),
      .ebrk_insn_i                    ( ebrk_insn              ),
      .csr_status_i                   ( csr_status             ),

      // from IF-ID pipeline
      .instr_valid_i                  ( instr_valid_i          ),
      .instr_i                        ( instr_rdata_i          ),
      .instr_compressed_i             ( instr_rdata_c_i        ),
      .instr_is_compressed_i          ( instr_is_compressed_i  ),

      // to IF-ID pipeline
      .instr_valid_clear_o            ( instr_valid_clear_o    ),
      .id_ready_o                     ( id_ready_o             ),
      .halt_if_o                      ( halt_if_o              ),

      // from prefetcher
      .instr_req_o                    ( instr_req_o            ),

      // to prefetcher
      .pc_set_o                       ( pc_set_o               ),
      .pc_mux_o                       ( pc_mux_o               ),
      .exc_pc_mux_o                   ( exc_pc_mux_o           ),
      .exc_cause_o                    ( exc_cause_o            ),

      // LSU
      .lsu_addr_last_i                ( lsu_addr_last_i        ),
      .load_err_i                     ( lsu_load_err_i         ),
      .store_err_i                    ( lsu_store_err_i        ),

      // jump/branch control
      .branch_in_id_i                 ( branch_in_id           ),
      .branch_set_i                   ( branch_set_q           ),
      .jump_set_i                     ( jump_set               ),

      .instr_multicycle_i             ( instr_multicycle       ),

      .irq_i                          ( irq_i                  ),
      // Interrupt Controller Signals
      .irq_req_ctrl_i                 ( irq_req_ctrl           ),
      .irq_id_ctrl_i                  ( irq_id_ctrl            ),
      .m_IE_i                         ( m_irq_enable_i         ),

      .irq_ack_o                      ( irq_ack_o              ),
      .irq_id_o                       ( irq_id_o               ),

      .exc_ack_o                      ( exc_ack                ),
      .exc_kill_o                     ( exc_kill               ),

      // CSR Controller Signals
      .csr_save_if_o                  ( csr_save_if_o          ),
      .csr_save_id_o                  ( csr_save_id_o          ),
      .csr_restore_mret_id_o          ( csr_restore_mret_id_o  ),
      .csr_restore_dret_id_o          ( csr_restore_dret_id_o  ),
      .csr_save_cause_o               ( csr_save_cause_o       ),
      .csr_mtval_o                    ( csr_mtval_o            ),

      // Debug Signal
      .debug_cause_o                  ( debug_cause_o          ),
      .debug_csr_save_o               ( debug_csr_save_o       ),
      .debug_req_i                    ( debug_req_i            ),
      .debug_single_step_i            ( debug_single_step_i    ),
      .debug_ebreakm_i                ( debug_ebreakm_i        ),

      // stall signals
      .stall_lsu_i                    ( stall_lsu              ),
      .stall_multdiv_i                ( stall_multdiv          ),
      .stall_jump_i                   ( stall_jump             ),
      .stall_branch_i                 ( stall_branch           ),

      .id_valid_o                     ( id_valid_o             ),

      // Performance Counters
      .perf_jump_o                    ( perf_jump_o            ),
      .perf_tbranch_o                 ( perf_tbranch_o         )
  );

  //////////////////////////
  // Interrupt controller //
  //////////////////////////

  ibex_int_controller int_controller_i (
      .clk_i                ( clk_i              ),
      .rst_ni               ( rst_ni             ),

      // to controller
      .irq_req_ctrl_o       ( irq_req_ctrl       ),
      .irq_id_ctrl_o        ( irq_id_ctrl        ),

      .ctrl_ack_i           ( exc_ack            ),
      .ctrl_kill_i          ( exc_kill           ),

      // Interrupt signals
      .irq_i                ( irq_i              ),
      .irq_id_i             ( irq_id_i           ),

      .m_IE_i               ( m_irq_enable_i     )
  );

  //////////////
  // ID-EX/WB //
  //////////////

  // Forward decoder output to EX, WB and controller only if current instr is still
  // being executed. This is the case if the current instr is either:
  // - a new instr (not yet done)
  // - a multicycle instr that is not yet done
  assign instr_executing = (instr_new_i | ~instr_multicycle_done_q);
  assign data_req_id     = instr_executing ? data_req_dec  : 1'b0;
  assign mult_en_id      = instr_executing ? mult_en_dec   : 1'b0;
  assign div_en_id       = instr_executing ? div_en_dec    : 1'b0;
  assign branch_in_id    = instr_executing ? branch_in_dec : 1'b0;

  ///////////
  // ID-EX //
  ///////////
  assign data_req_ex_o               = data_req_id;
  assign data_we_ex_o                = data_we_id;
  assign data_type_ex_o              = data_type_id;
  assign data_sign_ext_ex_o          = data_sign_ext_id;
  assign data_wdata_ex_o             = regfile_rdata_b;
  assign data_reg_offset_ex_o        = data_reg_offset_id;

  assign alu_operator_ex_o           = alu_operator;
  assign alu_operand_a_ex_o          = alu_operand_a;
  assign alu_operand_b_ex_o          = alu_operand_b;

  assign mult_en_ex_o                = mult_en_id;
  assign div_en_ex_o                 = div_en_id;

  assign multdiv_operator_ex_o       = multdiv_operator;
  assign multdiv_signed_mode_ex_o    = multdiv_signed_mode;
  assign multdiv_operand_a_ex_o      = regfile_rdata_a;
  assign multdiv_operand_b_ex_o      = regfile_rdata_b;

  typedef enum logic { IDLE, WAIT_MULTICYCLE } id_fsm_e;
  id_fsm_e id_wb_fsm_cs, id_wb_fsm_ns;

  ////////////////////////////////
  // ID-EX/WB Pipeline Register //
  ////////////////////////////////

  always_ff @(posedge clk_i or negedge rst_ni) begin : id_wb_pipeline_reg
    if (!rst_ni) begin
      id_wb_fsm_cs            <= IDLE;
      branch_set_q            <= 1'b0;
      instr_multicycle_done_q <= 1'b0;
    end else begin
      id_wb_fsm_cs            <= id_wb_fsm_ns;
      branch_set_q            <= branch_set_n;
      instr_multicycle_done_q <= instr_multicycle_done_n;
    end
  end

  //////////////////
  // ID-EX/WB FSM //
  //////////////////

  assign multdiv_en_dec  = mult_en_dec | div_en_dec;

  always_comb begin : id_wb_fsm
    id_wb_fsm_ns            = id_wb_fsm_cs;
    instr_multicycle        = 1'b0;
    instr_multicycle_done_n = instr_multicycle_done_q;
    regfile_we              = regfile_we_id;
    stall_lsu               = 1'b0;
    stall_multdiv           = 1'b0;
    stall_jump              = 1'b0;
    stall_branch            = 1'b0;
    branch_set_n            = 1'b0;
    perf_branch_o           = 1'b0;

    unique case (id_wb_fsm_cs)

      IDLE: begin
        // only detect multicycle when instruction is new, do not re-detect after
        // execution (when waiting for next instruction from IF stage)
        if (instr_new_i) begin
          unique case (1'b1)
            data_req_dec: begin
              // LSU operation
              regfile_we              = 1'b0;
              id_wb_fsm_ns            = WAIT_MULTICYCLE;
              stall_lsu               = 1'b1;
              instr_multicycle        = 1'b1;
              instr_multicycle_done_n = 1'b0;
            end
            multdiv_en_dec: begin
              // MUL or DIV operation
              regfile_we              = 1'b0;
              id_wb_fsm_ns            = WAIT_MULTICYCLE;
              stall_multdiv           = 1'b1;
              instr_multicycle        = 1'b1;
              instr_multicycle_done_n = 1'b0;
            end
            branch_in_dec: begin
              // cond branch operation
              id_wb_fsm_ns            =  branch_decision_i ? WAIT_MULTICYCLE : IDLE;
              stall_branch            =  branch_decision_i;
              instr_multicycle        =  branch_decision_i;
              instr_multicycle_done_n = ~branch_decision_i;
              branch_set_n            =  branch_decision_i;
              perf_branch_o           =  1'b1;
            end
            jump_in_dec: begin
              // uncond branch operation
              id_wb_fsm_ns            = WAIT_MULTICYCLE;
              stall_jump              = 1'b1;
              instr_multicycle        = 1'b1;
              instr_multicycle_done_n = 1'b0;
            end
            default:;
          endcase
        end
      end

      WAIT_MULTICYCLE: begin
        if ((data_req_dec & lsu_valid_i) | (~data_req_dec & ex_valid_i)) begin
          id_wb_fsm_ns            = IDLE;
          instr_multicycle_done_n = 1'b1;
        end else begin
          regfile_we              = 1'b0;
          instr_multicycle        = 1'b1;
          stall_lsu               = data_req_dec;
          stall_multdiv           = multdiv_en_dec;
          stall_branch            = branch_in_dec;
          stall_jump              = jump_in_dec;
        end
      end

      default: begin
        id_wb_fsm_ns = id_fsm_e'(1'bX);
      end
    endcase
  end

  ////////////////
  // Assertions //
  ////////////////

`ifndef VERILATOR
  // make sure that branch decision is valid when jumping
  assert property (
    @(posedge clk_i) (branch_decision_i !== 1'bx || branch_in_id == 1'b0) ) else
      $display("Branch decision is X");

`ifdef CHECK_MISALIGNED
  assert property (
    @(posedge clk_i) (~data_misaligned_i) ) else
      $display("Misaligned memory access at %x",pc_id_i);
`endif

  // the instruction delivered to the ID stage should always be valid
  assert property (
    @(posedge clk_i) (instr_valid_i & (~illegal_c_insn_i)) |-> (!$isunknown(instr_rdata_i)) ) else
      $display("Instruction is valid, but has at least one X");

  // make sure multicycles enable signals are unique
  assert property (
    @(posedge clk_i) ~(data_req_dec & multdiv_en_dec)) else
      $display("Multicycles enable signals are not unique");

`endif

endmodule
