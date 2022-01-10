// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                                                                            //
// Additional contributions by:                                               //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    RISC-V Tracer                                              //
// Project Name:   ibex                                                       //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Traces the executed instructions                           //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`ifndef VERILATOR

import ibex_defines::*;
import ibex_tracer_defines::*;

// Source/Destination register instruction index
`define REG_S1 19:15
`define REG_S2 24:20
`define REG_S3 29:25
`define REG_D  11:07

/**
 * Traces the executed instructions
 */
module ibex_tracer #(
    parameter int unsigned RegAddrWidth = 5
) (
    // Clock and Reset
    input  logic                      clk_i,
    input  logic                      rst_ni,

    input  logic                      fetch_enable_i,
    input  logic [3:0]                core_id_i,
    input  logic [5:0]                cluster_id_i,

    input  logic [31:0]               pc_i,
    input  logic [31:0]               instr_i,
    input  logic                      compressed_i,
    input  logic                      id_valid_i,
    input  logic                      is_decoding_i,
    input  logic                      is_branch_i,
    input  logic                      branch_taken_i,
    input  logic                      pipe_flush_i,
    input  logic                      mret_insn_i,
    input  logic                      dret_insn_i,
    input  logic                      ecall_insn_i,
    input  logic                      ebrk_insn_i,
    input  logic                      csr_status_i,
    input  logic [31:0]               rs1_value_i,
    input  logic [31:0]               rs2_value_i,
    input  logic [31:0]               lsu_value_i,

    input  logic [(RegAddrWidth-1):0] ex_reg_addr_i,
    input  logic                      ex_reg_we_i,
    input  logic [31:0]               ex_reg_wdata_i,
    input  logic                      data_valid_lsu_i,
    input  logic                      ex_data_req_i,
    input  logic                      ex_data_gnt_i,
    input  logic                      ex_data_we_i,
    input  logic [31:0]               ex_data_addr_i,
    input  logic [31:0]               ex_data_wdata_i,

    input  logic [31:0]               lsu_reg_wdata_i,

    input  logic [31:0]               imm_i_type_i,
    input  logic [31:0]               imm_s_type_i,
    input  logic [31:0]               imm_b_type_i,
    input  logic [31:0]               imm_u_type_i,
    input  logic [31:0]               imm_j_type_i,
    input  logic [31:0]               zimm_rs1_type_i
);

  integer      f;
  string       fn;
  integer      cycles;
  logic [ 4:0] rd, rs1, rs2, rs3;

  typedef struct {
    logic [(RegAddrWidth-1):0] addr;
    logic [31:0] value;
  } reg_t;

  typedef struct {
    logic [31:0] addr;
    logic        we;
    logic [ 3:0] be;
    logic [31:0] wdata;
    logic [31:0] rdata;
  } mem_acc_t;

  class instr_trace_t;
    time         simtime;
    integer      cycles;
    logic [31:0] pc;
    logic [31:0] instr;
    string       str;
    reg_t        regs_read[$];
    reg_t        regs_write[$];
    mem_acc_t    mem_access[$];

    function new ();
      str        = "";
      regs_read  = {};
      regs_write = {};
      mem_access = {};
    endfunction

    function string regAddrToStr(input logic [(RegAddrWidth-1):0] addr);
      begin
        if (addr < 10) begin
          return $sformatf(" x%0d", addr);
        end else begin
          return $sformatf("x%0d", addr);
        end
      end
    endfunction

    function void printInstrTrace();
      mem_acc_t mem_acc;
      begin
        $fwrite(f, "%t %15d %h %h %-36s", simtime,
                                          cycles,
                                          pc_i,
                                          instr_i,
                                          str);

        foreach(regs_write[i]) begin
          if (regs_write[i].addr != 0) begin
            $fwrite(f, " %s=%08x", regAddrToStr(regs_write[i].addr), regs_write[i].value);
          end
        end

        foreach(regs_read[i]) begin
          if (regs_read[i].addr != 0) begin
            $fwrite(f, " %s:%08x", regAddrToStr(regs_read[i].addr), regs_read[i].value);
          end
        end

        if (mem_access.size() > 0) begin
          mem_acc = mem_access.pop_front();

          $fwrite(f, "  PA:%08x", mem_acc.addr);
        end

        $fwrite(f, "\n");
      end
    endfunction

    function void printMnemonic(input string mnemonic);
      begin
        str = mnemonic;
      end
    endfunction // printMnemonic

    function void printRInstr(input string mnemonic);
      begin
        regs_read.push_back('{rs1, rs1_value_i});
        regs_read.push_back('{rs2, rs2_value_i});
        regs_write.push_back('{rd, 'x});
        str = $sformatf("%-16s x%0d, x%0d, x%0d", mnemonic, rd, rs1, rs2);
      end
    endfunction // printRInstr

    function void printIInstr(input string mnemonic);
      begin
        regs_read.push_back('{rs1, rs1_value_i});
        regs_write.push_back('{rd, 'x});
        str = $sformatf("%-16s x%0d, x%0d, %0d", mnemonic, rd, rs1, $signed(imm_i_type_i));
      end
    endfunction // printIInstr

    function void printIuInstr(input string mnemonic);
      begin
        regs_read.push_back('{rs1, rs1_value_i});
        regs_write.push_back('{rd, 'x});
        str = $sformatf("%-16s x%0d, x%0d, 0x%0x", mnemonic, rd, rs1, imm_i_type_i);
      end
    endfunction // printIuInstr

    function void printUInstr(input string mnemonic);
      begin
        regs_write.push_back('{rd, 'x});
        str = $sformatf("%-16s x%0d, 0x%0h", mnemonic, rd, {imm_u_type_i[31:12], 12'h000});
      end
    endfunction // printUInstr

    function void printUJInstr(input string mnemonic);
      begin
        regs_write.push_back('{rd, 'x});
        str =  $sformatf("%-16s x%0d, %0d", mnemonic, rd, $signed(imm_j_type_i));
      end
    endfunction // printUJInstr

    function void printSBInstr(input string mnemonic);
      begin
        regs_read.push_back('{rs1, rs1_value_i});
        regs_read.push_back('{rs2, rs2_value_i});
        str =  $sformatf("%-16s x%0d, x%0d, %0d", mnemonic, rs1, rs2, $signed(imm_b_type_i));
      end
    endfunction // printSBInstr

    function void printCSRInstr(input string mnemonic);
      logic [11:0] csr;
      begin
        csr = instr_i[31:20];

        regs_write.push_back('{rd, 'x});

        if (!instr_i[14]) begin
          regs_read.push_back('{rs1, rs1_value_i});
          str = $sformatf("%-16s x%0d, x%0d, 0x%h", mnemonic, rd, rs1, csr);
        end else begin
          str = $sformatf("%-16s x%0d, 0x%h, 0x%h", mnemonic, rd, zimm_rs1_type_i, csr);
        end
      end
    endfunction // printCSRInstr

    function void printLoadInstr();
      string mnemonic;
      logic [2:0] size;
      begin
        // detect reg-reg load and find size
        size = instr_i[14:12];
        if (instr_i[14:12] == 3'b111) begin
          size = instr_i[30:28];
        end

        unique case (size)
          3'b000: mnemonic = "lb";
          3'b001: mnemonic = "lh";
          3'b010: mnemonic = "lw";
          3'b100: mnemonic = "lbu";
          3'b101: mnemonic = "lhu";
          3'b110: mnemonic = "p.elw";
          3'b011,
          3'b111: begin
            printMnemonic("INVALID");
            return;
          end
          default: begin
            printMnemonic("INVALID");
            return;
          end
        endcase

        regs_write.push_back('{rd, 'x});

        if (instr_i[14:12] != 3'b111) begin
          // regular load
          regs_read.push_back('{rs1, rs1_value_i});
          str = $sformatf("%-16s x%0d, %0d(x%0d)", mnemonic, rd, $signed(imm_i_type_i), rs1);
        end else begin
          printMnemonic("INVALID");
        end
      end
    endfunction

    function void printStoreInstr();
      string mnemonic;
      begin

        unique case (instr_i[13:12])
          2'b00:  mnemonic = "sb";
          2'b01:  mnemonic = "sh";
          2'b10:  mnemonic = "sw";
          2'b11: begin
            printMnemonic("INVALID");
            return;
          end
          default: begin
            printMnemonic("INVALID");
            return;
          end
        endcase

        if (!instr_i[14]) begin
          // regular store
          regs_read.push_back('{rs2, rs2_value_i});
          regs_read.push_back('{rs1, rs1_value_i});
          str = $sformatf("%-16s x%0d, %0d(x%0d)", mnemonic, rs2, $signed(imm_s_type_i), rs1);
        end else begin
          printMnemonic("INVALID");
        end
      end
    endfunction // printSInstr

  endclass

  mailbox #(instr_trace_t) instr_ex = new ();
  mailbox #(instr_trace_t) instr_wb = new ();

  // cycle counter
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycles = 0;
    end else begin
      cycles = cycles + 1;
    end
  end

  // open/close output file for writing
  initial begin
    wait(rst_ni == 1'b1);
    wait(fetch_enable_i == 1'b1);
    $sformat(fn, "trace_core_%h_%h.log", cluster_id_i, core_id_i);
    $display("[TRACER] Output filename is: %s", fn);
    f = $fopen(fn, "w");
    $fwrite(f, "                Time          Cycles PC       Instr    Mnemonic\n");
  end

  final begin
    $fclose(f);
  end

  assign rd  = instr_i[`REG_D];
  assign rs1 = instr_i[`REG_S1];
  assign rs2 = instr_i[`REG_S2];
  assign rs3 = instr_i[`REG_S3];

  // log execution
  always @(negedge clk_i) begin
    instr_trace_t trace;
    mem_acc_t     mem_acc;
    // special case for WFI because we don't wait for unstalling there
    if ((id_valid_i || mret_insn_i || ecall_insn_i || pipe_flush_i || ebrk_insn_i ||
         dret_insn_i || csr_status_i || ex_data_req_i) && is_decoding_i) begin
      trace = new ();

      trace.simtime    = $time;
      trace.cycles     = cycles;
      trace.pc         = pc_i;
      trace.instr      = instr_i;

      // separate case for 'nop' instruction to avoid overlapping with 'addi'
      if (instr_i == 32'h00_00_00_13) begin
        trace.printMnemonic("nop");
      end else begin
        // use casex instead of case inside due to ModelSim bug
        unique casex (instr_i)
          // Regular opcodes
          INSTR_LUI:        trace.printUInstr("lui");
          INSTR_AUIPC:      trace.printUInstr("auipc");
          INSTR_JAL:        trace.printUJInstr("jal");
          INSTR_JALR:       trace.printIInstr("jalr");
          // BRANCH
          INSTR_BEQ:        trace.printSBInstr("beq");
          INSTR_BNE:        trace.printSBInstr("bne");
          INSTR_BLT:        trace.printSBInstr("blt");
          INSTR_BGE:        trace.printSBInstr("bge");
          INSTR_BLTU:       trace.printSBInstr("bltu");
          INSTR_BGEU:       trace.printSBInstr("bgeu");
          // OPIMM
          INSTR_ADDI:       trace.printIInstr("addi");
          INSTR_SLTI:       trace.printIInstr("slti");
          INSTR_SLTIU:      trace.printIInstr("sltiu");
          INSTR_XORI:       trace.printIInstr("xori");
          INSTR_ORI:        trace.printIInstr("ori");
          INSTR_ANDI:       trace.printIInstr("andi");
          INSTR_SLLI:       trace.printIuInstr("slli");
          INSTR_SRLI:       trace.printIuInstr("srli");
          INSTR_SRAI:       trace.printIuInstr("srai");
          // OP
          INSTR_ADD:        trace.printRInstr("add");
          INSTR_SUB:        trace.printRInstr("sub");
          INSTR_SLL:        trace.printRInstr("sll");
          INSTR_SLT:        trace.printRInstr("slt");
          INSTR_SLTU:       trace.printRInstr("sltu");
          INSTR_XOR:        trace.printRInstr("xor");
          INSTR_SRL:        trace.printRInstr("srl");
          INSTR_SRA:        trace.printRInstr("sra");
          INSTR_OR:         trace.printRInstr("or");
          INSTR_AND:        trace.printRInstr("and");
          // SYSTEM (CSR manipulation)
          INSTR_CSRRW:      trace.printCSRInstr("csrrw");
          INSTR_CSRRS:      trace.printCSRInstr("csrrs");
          INSTR_CSRRC:      trace.printCSRInstr("csrrc");
          INSTR_CSRRWI:     trace.printCSRInstr("csrrwi");
          INSTR_CSRRSI:     trace.printCSRInstr("csrrsi");
          INSTR_CSRRCI:     trace.printCSRInstr("csrrci");
          // SYSTEM (others)
          INSTR_ECALL:      trace.printMnemonic("ecall");
          INSTR_EBREAK:     trace.printMnemonic("ebreak");
          INSTR_MRET:       trace.printMnemonic("mret");
          INSTR_DRET:       trace.printMnemonic("dret");
          INSTR_WFI:        trace.printMnemonic("wfi");
          // RV32M
          INSTR_PMUL:       trace.printRInstr("mul");
          INSTR_PMUH:       trace.printRInstr("mulh");
          INSTR_PMULHSU:    trace.printRInstr("mulhsu");
          INSTR_PMULHU:     trace.printRInstr("mulhu");
          INSTR_DIV:        trace.printRInstr("div");
          INSTR_DIVU:       trace.printRInstr("divu");
          INSTR_REM:        trace.printRInstr("rem");
          INSTR_REMU:       trace.printRInstr("remu");
          // LOAD & STORE
          INSTR_LOAD:       trace.printLoadInstr();
          INSTR_STORE:      trace.printStoreInstr();
          default:          trace.printMnemonic("INVALID");
        endcase // unique case (instr_i)
      end

      // replace register written back
      foreach(trace.regs_write[i]) begin
        if ((trace.regs_write[i].addr == ex_reg_addr_i) && ex_reg_we_i) begin
          trace.regs_write[i].value = ex_reg_wdata_i;
        end
      end
      // look for data accesses and log them
      if (ex_data_req_i) begin

        if (!ex_data_gnt_i) begin
          //we wait until the the gnt comes
          do @(negedge clk_i);
          while (!ex_data_gnt_i);
        end

        mem_acc.addr = ex_data_addr_i;
        mem_acc.we   = ex_data_we_i;

        if (mem_acc.we) begin
          mem_acc.wdata = ex_data_wdata_i;
        end else begin
          mem_acc.wdata = 'x;
        end
        //we wait until the the data instruction ends
        do @(negedge clk_i);
          while (!data_valid_lsu_i);

        if (!mem_acc.we) begin
          //load operations
          foreach(trace.regs_write[i])
            trace.regs_write[i].value = lsu_reg_wdata_i;
        end
        trace.mem_access.push_back(mem_acc);
      end
      trace.printInstrTrace();
    end
  end // always @ (posedge clk_i)

endmodule

`undef REG_S1
`undef REG_S2
`undef REG_S3
`undef REG_D

`endif
