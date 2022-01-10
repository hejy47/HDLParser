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
//                                                                            //
// Design Name:    Instruction Fetch Stage                                    //
// Project Name:   ibex                                                       //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Instruction fetch unit: Selection of the next PC, and      //
//                 buffering (sampling) of the read instruction               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`ifdef RISCV_FORMAL
  `define RVFI
`endif

/**
 * Instruction Fetch Stage
 *
 * Instruction fetch unit: Selection of the next PC, and buffering (sampling) of
 * the read instruction.
 */
module ibex_if_stage #(
    parameter int unsigned DmHaltAddr      = 32'h1A110800,
    parameter int unsigned DmExceptionAddr = 32'h1A110808
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,

    input  logic [31:0]               boot_addr_i,              // also used for mtvec
    input  logic                      req_i,                    // instruction request control

    // instruction cache interface
    output logic                      instr_req_o,
    output logic [31:0]               instr_addr_o,
    input  logic                      instr_gnt_i,
    input  logic                      instr_rvalid_i,
    input  logic [31:0]               instr_rdata_i,

    // Output of IF Pipeline stage
    output logic                      instr_valid_id_o,         // instr in IF-ID is valid
    output logic                      instr_new_id_o,           // instr in IF-ID is new
    output logic [31:0]               instr_rdata_id_o,         // instr for ID stage
    output logic [15:0]               instr_rdata_c_id_o,       // compressed instr for ID stage
                                                                // (mtval), meaningful only if
                                                                // instr_is_compressed_id_o = 1'b1
    output logic                      instr_is_compressed_id_o, // compressed decoder thinks this
                                                                // is a compressed instr
    output logic                      illegal_c_insn_id_o,      // compressed decoder thinks this
                                                                // is an invalid instr
    output logic [31:0]               pc_if_o,
    output logic [31:0]               pc_id_o,

    // Forwarding ports - control signals
    input  logic                      instr_valid_clear_i,      // clear instr valid bit in IF-ID
    input  logic                      pc_set_i,                 // set the PC to a new value
    input  logic [31:0]               csr_mepc_i,               // PC to restore after handling
                                                                // the interrupt/exception
    input  logic [31:0]               csr_depc_i,               // PC to restore after handling
                                                                // the debug request
    input  ibex_defines::pc_sel_e     pc_mux_i,                 // selector for PC multiplexer
    input  ibex_defines::exc_pc_sel_e exc_pc_mux_i,             // selects ISR address
    input  ibex_defines::exc_cause_e  exc_cause,                // selects ISR address for
                                                                // vectorized interrupt lines

    // jump and branch target and decision
    input  logic [31:0]               jump_target_ex_i,         // jump target address

    // CSRs
    output logic [31:0]               csr_mtvec_o,

    // pipeline stall
    input  logic                      halt_if_i,
    input  logic                      id_ready_i,
    output logic                      if_valid_o,

    // misc signals
    output logic                      if_busy_o,                // IF stage is busy fetching instr
    output logic                      perf_imiss_o              // instr fetch miss
);

  import ibex_defines::*;

  logic              offset_in_init_d, offset_in_init_q;
  logic              valid;
  logic              if_ready;
  // prefetch buffer related signals
  logic              prefetch_busy;
  logic              branch_req;
  logic       [31:0] fetch_addr_n;

  logic              fetch_valid;
  logic              fetch_ready;
  logic       [31:0] fetch_rdata;
  logic       [31:0] fetch_addr;

  logic       [31:0] exc_pc;

  logic        [5:0] irq_id;
  logic              unused_irq_bit;

  // extract interrupt ID from exception cause
  assign irq_id         = {exc_cause};
  assign unused_irq_bit = irq_id[5];   // MSB distinguishes interrupts from exceptions

  // trap-vector base address, mtvec.MODE set to vectored
  assign csr_mtvec_o = {boot_addr_i[31:8], 6'b0, 2'b01};

  // exception PC selection mux
  always_comb begin : exc_pc_mux
    unique case (exc_pc_mux_i)
      EXC_PC_EXC:     exc_pc = { boot_addr_i[31:8], 8'h00                    };
      EXC_PC_IRQ:     exc_pc = { boot_addr_i[31:8], 1'b0, irq_id[4:0], 2'b00 };
      EXC_PC_DBD:     exc_pc = DmHaltAddr;
      EXC_PC_DBG_EXC: exc_pc = DmExceptionAddr;
      default:        exc_pc = 'X;
    endcase
  end

  // fetch address selection mux
  always_comb begin : fetch_addr_mux
    unique case (pc_mux_i)
      PC_BOOT: fetch_addr_n = { boot_addr_i[31:8], 8'h80 };
      PC_JUMP: fetch_addr_n = jump_target_ex_i;
      PC_EXC:  fetch_addr_n = exc_pc;                       // set PC to exception handler
      PC_ERET: fetch_addr_n = csr_mepc_i;                   // restore PC when returning from EXC
      PC_DRET: fetch_addr_n = csr_depc_i;
      default: fetch_addr_n = 'X;
    endcase
  end

  // prefetch buffer, caches a fixed number of instructions
  ibex_prefetch_buffer prefetch_buffer_i (
      .clk_i             ( clk_i                       ),
      .rst_ni            ( rst_ni                      ),

      .req_i             ( req_i                       ),

      .branch_i          ( branch_req                  ),
      .addr_i            ( {fetch_addr_n[31:1], 1'b0}  ),

      .ready_i           ( fetch_ready                 ),
      .valid_o           ( fetch_valid                 ),
      .rdata_o           ( fetch_rdata                 ),
      .addr_o            ( fetch_addr                  ),

      // goes to instruction memory / instruction cache
      .instr_req_o       ( instr_req_o                 ),
      .instr_addr_o      ( instr_addr_o                ),
      .instr_gnt_i       ( instr_gnt_i                 ),
      .instr_rvalid_i    ( instr_rvalid_i              ),
      .instr_rdata_i     ( instr_rdata_i               ),

      // Prefetch Buffer Status
      .busy_o            ( prefetch_busy               )
  );


  // offset initialization state
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      offset_in_init_q <= 1'b1;
    end else begin
      offset_in_init_q <= offset_in_init_d;
    end
  end

  // offset initialization related transition logic
  always_comb begin
    offset_in_init_d = offset_in_init_q;

    fetch_ready   = 1'b0;
    branch_req    = 1'b0;
    valid         = 1'b0;

    if (offset_in_init_q) begin
      // no valid instruction data for ID stage, assume aligned
      if (req_i) begin
        branch_req    = 1'b1;
        offset_in_init_d = 1'b0;
      end
    end else begin
      if (fetch_valid) begin
        valid   = 1'b1; // an instruction is ready for ID stage

        if (req_i && if_valid_o) begin
          fetch_ready   = 1'b1;
          offset_in_init_d = 1'b0;
        end
      end
    end

    // take care of jumps and branches
    if (pc_set_i) begin
      valid = 1'b0;

      // switch to new PC from ID stage
      branch_req = 1'b1;
      offset_in_init_d = 1'b0;
    end
  end

  assign pc_if_o         = fetch_addr;
  assign if_busy_o       = prefetch_busy;
  assign perf_imiss_o    = ~fetch_valid | branch_req;

  // compressed instruction decoding, or more precisely compressed instruction
  // expander
  //
  // since it does not matter where we decompress instructions, we do it here
  // to ease timing closure
  logic [31:0] instr_decompressed;
  logic        illegal_c_insn;
  logic        instr_is_compressed_int;

  ibex_compressed_decoder compressed_decoder_i (
      .instr_i         ( fetch_rdata             ),
      .instr_o         ( instr_decompressed      ),
      .is_compressed_o ( instr_is_compressed_int ),
      .illegal_instr_o ( illegal_c_insn          )
  );

  // IF-ID pipeline registers, frozen when the ID stage is stalled
  always_ff @(posedge clk_i or negedge rst_ni) begin : if_id_pipeline_regs
    if (!rst_ni) begin
      instr_new_id_o             <= 1'b0;
      instr_valid_id_o           <= 1'b0;
      instr_rdata_id_o           <= '0;
      instr_rdata_c_id_o         <= '0;
      instr_is_compressed_id_o   <= 1'b0;
      illegal_c_insn_id_o        <= 1'b0;
      pc_id_o                    <= '0;
    end else begin
      instr_new_id_o             <= if_valid_o;
      if (if_valid_o) begin
        instr_valid_id_o         <= 1'b1;
        instr_rdata_id_o         <= instr_decompressed;
        instr_rdata_c_id_o       <= fetch_rdata[15:0];
        instr_is_compressed_id_o <= instr_is_compressed_int;
        illegal_c_insn_id_o      <= illegal_c_insn;
        pc_id_o                  <= pc_if_o;
      end else if (instr_valid_clear_i) begin
        instr_valid_id_o         <= 1'b0;
      end
    end
  end

  assign if_ready = valid & id_ready_i;
  assign if_valid_o = ~halt_if_i & if_ready;

  ////////////////
  // Assertions //
  ////////////////
`ifndef VERILATOR
  // the boot address needs to be aligned to 256 bytes
  assert property (
    @(posedge clk_i) (boot_addr_i[7:0] == 8'h00) ) else
      $error("The provided boot address is not aligned to 256 bytes");

  // there should never be a grant when there is no request
  assert property (
    @(posedge clk_i) (instr_gnt_i) |-> (instr_req_o) ) else
      $warning("There was a grant without a request");

  // assert that the address is word aligned when request is sent
  assert property (
    @(posedge clk_i) (instr_req_o) |-> (instr_addr_o[1:0] == 2'b00) ) else
      $display("Instruction address not word aligned");
`endif

endmodule
