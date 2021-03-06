// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Arithmetic logic unit
 */
module ibex_alu #(
  parameter bit RV32B = 1'b0
) (
    input  ibex_pkg::alu_op_e operator_i,
    input  logic [31:0]       operand_a_i,
    input  logic [31:0]       operand_b_i,

    input  logic              instr_first_cycle_i,

    input  logic [32:0]       multdiv_operand_a_i,
    input  logic [32:0]       multdiv_operand_b_i,

    input  logic              multdiv_sel_i,

    input  logic [31:0]       imd_val_q_i,
    output logic [31:0]       imd_val_d_o,
    output logic              imd_val_we_o,

    output logic [31:0]       adder_result_o,
    output logic [33:0]       adder_result_ext_o,

    output logic [31:0]       result_o,
    output logic              comparison_result_o,
    output logic              is_equal_result_o
);
  import ibex_pkg::*;

  logic [31:0] operand_a_rev;
  logic [32:0] operand_b_neg;

  // bit reverse operand_a for left shifts and bit counting
  for (genvar k = 0; k < 32; k++) begin : gen_rev_operand_a
    assign operand_a_rev[k] = operand_a_i[31-k];
  end

  ///////////
  // Adder //
  ///////////

  logic        adder_op_b_negate;
  logic [32:0] adder_in_a, adder_in_b;
  logic [31:0] adder_result;

  always_comb begin
    adder_op_b_negate = 1'b0;
    unique case (operator_i)
      // Adder OPs
      ALU_SUB,

      // Comparator OPs
      ALU_EQ,   ALU_NE,
      ALU_GE,   ALU_GEU,
      ALU_LT,   ALU_LTU,
      ALU_SLT,  ALU_SLTU,

      // MinMax OPs (RV32B Ops)
      ALU_MIN,  ALU_MINU,
      ALU_MAX,  ALU_MAXU: adder_op_b_negate = 1'b1;

      default:;
    endcase
  end

  // prepare operand a
  assign adder_in_a    = multdiv_sel_i ? multdiv_operand_a_i : {operand_a_i,1'b1};

  // prepare operand b
  assign operand_b_neg = {operand_b_i,1'b0} ^ {33{1'b1}};
  always_comb begin
    unique case(1'b1)
      multdiv_sel_i:     adder_in_b = multdiv_operand_b_i;
      adder_op_b_negate: adder_in_b = operand_b_neg;
      default :          adder_in_b = {operand_b_i, 1'b0};
    endcase
  end

  // actual adder
  assign adder_result_ext_o = $unsigned(adder_in_a) + $unsigned(adder_in_b);

  assign adder_result       = adder_result_ext_o[32:1];

  assign adder_result_o     = adder_result;

  ////////////////
  // Comparison //
  ////////////////

  logic is_equal;
  logic is_greater_equal;  // handles both signed and unsigned forms
  logic cmp_signed;

  always_comb begin
    unique case (operator_i)
      ALU_GE,
      ALU_LT,
      ALU_SLT,
      // RV32B only
      ALU_MIN,
      ALU_MAX: cmp_signed = 1'b1;

      default: cmp_signed = 1'b0;
    endcase
  end

  assign is_equal = (adder_result == 32'b0);
  assign is_equal_result_o = is_equal;

  // Is greater equal
  always_comb begin
    if ((operand_a_i[31] ^ operand_b_i[31]) == 1'b0) begin
      is_greater_equal = (adder_result[31] == 1'b0);
    end else begin
      is_greater_equal = operand_a_i[31] ^ (cmp_signed);
    end
  end

  // GTE unsigned:
  // (a[31] == 1 && b[31] == 1) => adder_result[31] == 0
  // (a[31] == 0 && b[31] == 0) => adder_result[31] == 0
  // (a[31] == 1 && b[31] == 0) => 1
  // (a[31] == 0 && b[31] == 1) => 0

  // GTE signed:
  // (a[31] == 1 && b[31] == 1) => adder_result[31] == 0
  // (a[31] == 0 && b[31] == 0) => adder_result[31] == 0
  // (a[31] == 1 && b[31] == 0) => 0
  // (a[31] == 0 && b[31] == 1) => 1

  // generate comparison result
  logic cmp_result;

  always_comb begin
    unique case (operator_i)
      ALU_EQ:             cmp_result =  is_equal;
      ALU_NE:             cmp_result = ~is_equal;
      ALU_GE,   ALU_GEU,
      ALU_MAX,  ALU_MAXU: cmp_result = is_greater_equal; // RV32B only
      ALU_LT,   ALU_LTU,
      ALU_MIN,  ALU_MINU, //RV32B only
      ALU_SLT,  ALU_SLTU: cmp_result = ~is_greater_equal;

      default: cmp_result = is_equal;
    endcase
  end

  assign comparison_result_o = cmp_result;

  ///////////
  // Shift //
  ///////////

  // The shifter structure consists of a 33-bit shifter: 32-bit operand + 1 bit extension for
  // arithmetic shifts and one-shift support.
  // Rotations and funnel shifts are implemented as multi-cycle instructions.
  // The shifter is also used for single-bit instructions as detailed below.
  //
  // Standard Shifts
  // ===============
  // For standard shift instructions, the direction of the shift is to the right by default. For
  // left shifts, the signal shift_left signal is set. If so, the operand is initially reversed,
  // shifted to the right by the specified amount and shifted back again. For arithmetic- and
  // one-shifts the 33rd bit of the shifter operand can is set accordingly.
  //
  // Multicycle Shifts
  // =================
  //
  // Rotation
  // --------
  // For rotations, the operand signals operand_a_i and operand_b_i are kept constant to rs1 and
  // rs2 respectively.
  //
  // Rotation pseudocode:
  //   shift_amt = rs2 & 31;
  //   multicycle_result = (rs1 >> shift_amt) | (rs1 << (32 - shift_amt));
  //                       ^-- cycle 0 -----^ ^-- cycle 1 --------------^
  //
  // Funnel Shifts
  // -------------
  // For funnel shifs, operand_a_i is tied to rs1 in the first cycle and rs3 in the
  // second cycle. operand_b_i is always tied to rs2. The order of applying the shift amount or
  // its complement is determined by bit [5] of shift_amt.
  //
  // Funnel shift Pseudocode: (fsl)
  //  shift_amt = rs2 & 63;
  //  shift_amt_compl = 32 - shift_amt[4:0]
  //  if (shift_amt >=33):
  //     multicycle_result = (rs1 >> shift_amt_cmpl[4:0]) | (rs3 << shift_amt[4:0]);
  //                         ^-- cycle 0 ---------------^ ^-- cycle 1 ------------^
  //  else if (shift_amt <= 31 && shift_amt > 0):
  //     multicycle_result = (rs1 << shift_amt[4:0]) | (rs3 >> shift_amt_compl[4:0]);
  //                         ^-- cycle 0 ----------^ ^-- cycle 1 -------------------^
  //  For shift_amt == 0, 32, both shift_amt[4:0] and shift_amt_compl[4:0] == '0.
  //  these cases need to be handled separately outside the shifting structure:
  //  else if (shift_amt == 32):
  //     multicycle_result = rs3
  //  else if (shift_amt == 0):
  //     multicycle_result = rs1.
  //
  // Single-Bit Instructions
  // =======================
  // Single bit instructions operate on bit operand_b_i[4:0] of operand_a_i.

  // The operations sbset, sbclr and sbinv are implemented by generation of a bit-mask using the
  // shifter structure. This is done by left-shifting the operand 32'h1 by the required amount.
  // The signal shift_sbmode multiplexes the shifter input and sets the signal shift_left.
  // Further processing is taken care of by a separate structure.
  //
  // For sbext, the bit defined by operand_b_i[4:0] is to be returned. This is done by simply
  // shifting operand_a_i to the right by the required amount and returning bit [0] of the result.

  logic       shift_left;
  logic       shift_ones;
  logic       shift_arith;
  logic       shift_funnel;
  logic       shift_sbmode;
  logic [5:0] shift_amt;
  logic [5:0] shift_amt_compl; // complementary shift amount (32 - shift_amt)

  logic [31:0] shift_result;
  logic [32:0] shift_result_ext;
  logic [31:0] shift_result_rev;

  // bit shift_amt[5]: word swap bit: only considered for FSL/FSR.
  // if set, reverse operations in first and second cycle.
  assign shift_amt[5] = operand_b_i[5] & shift_funnel;
  assign shift_amt_compl = 32 - operand_b_i[4:0];

  assign shift_amt[4:0] = instr_first_cycle_i ?
      (operand_b_i[5] && shift_funnel ? shift_amt_compl[4:0] : operand_b_i[4:0]) :
      (operand_b_i[5] && shift_funnel ? operand_b_i[4:0] : shift_amt_compl[4:0]);

  // single-bit mode: shift
  assign shift_sbmode = RV32B ?
      (operator_i == ALU_SBSET) | (operator_i == ALU_SBCLR) | (operator_i == ALU_SBINV) : 1'b0;

  // left shift if this is:
  // * a standard left shift (slo, sll)
  // * a rol in the first cycle
  // * a ror in the second cycle
  // * fsl: without word-swap bit: first cycle, else: second cycle
  // * fsr: without word-swap bit: second cycle, else: first cycle
  // * a single-bit instruction: sbclr, sbset, sbinv (excluding sbext)
  always_comb begin
    unique case (operator_i)
      ALU_SLL: shift_left = 1'b1;
      ALU_SLO: shift_left = RV32B ? 1'b1 : 1'b0;
      ALU_ROL: shift_left = RV32B ? instr_first_cycle_i : 0;
      ALU_ROR: shift_left = RV32B ? ~instr_first_cycle_i : 0;
      ALU_FSL: shift_left =
          RV32B ? (shift_amt[5] ? ~instr_first_cycle_i : instr_first_cycle_i) : 1'b0;
      ALU_FSR: shift_left =
          RV32B ? (shift_amt[5] ? instr_first_cycle_i : ~instr_first_cycle_i) : 1'b0;
      default: shift_left = 1'b0;
    endcase
    if (shift_sbmode) begin
      shift_left = 1'b1;
    end
  end

  assign shift_arith      = (operator_i == ALU_SRA);
  assign shift_ones       = RV32B ? (operator_i == ALU_SLO) | (operator_i == ALU_SRO) : 1'b0;
  assign shift_funnel     = RV32B ? (operator_i == ALU_FSL) | (operator_i == ALU_FSR) : 1'b0;

  // shifter structure.
  always_comb begin
    shift_result = operand_a_i;

    // select bit reversed or normal input
    if (shift_left) begin
      shift_result = operand_a_rev;
    end

    // if this is a single bit instruction: we left-shift 32'h1 by shift_amt.
    // the first reverse of the left-shift operation can be easily omitted, since we
    // know the result of rev(32'h1).
    if (shift_sbmode) begin
      shift_result = 32'h8000_0000;
    end

    shift_result_ext =
        $signed({shift_ones | (shift_arith & shift_result[31]), shift_result}) >>> shift_amt[4:0];

    shift_result = shift_result_ext[31:0];

    for (int unsigned i=0; i<32; i++) begin
      shift_result_rev[i] = shift_result[31-i];
    end

    shift_result = shift_left ? shift_result_rev : shift_result;

  end

  ///////////////////
  // Bitwise Logic //
  ///////////////////

  logic bwlogic_or;
  logic bwlogic_and;
  logic [31:0] bwlogic_operand_b;
  logic [31:0] bwlogic_or_result;
  logic [31:0] bwlogic_and_result;
  logic [31:0] bwlogic_xor_result;
  logic [31:0] bwlogic_result;

  logic bwlogic_op_b_negate;

  always_comb begin
    unique case (operator_i)
      // Logic-with-negate OPs (RV32B Ops)
      ALU_XNOR,
      ALU_ORN,
      ALU_ANDN: bwlogic_op_b_negate = RV32B ? 1'b1 : 1'b0;
      ALU_CMIX: bwlogic_op_b_negate = RV32B ? ~instr_first_cycle_i : 1'b0;
      default:  bwlogic_op_b_negate = 1'b0;
    endcase
  end

  assign bwlogic_operand_b = bwlogic_op_b_negate ? operand_b_neg[32:1] : operand_b_i;

  assign bwlogic_or_result  = operand_a_i | bwlogic_operand_b;
  assign bwlogic_and_result = operand_a_i & bwlogic_operand_b;
  assign bwlogic_xor_result = operand_a_i ^ bwlogic_operand_b;

  assign bwlogic_or  = (operator_i == ALU_OR)  | (operator_i == ALU_ORN);
  assign bwlogic_and = (operator_i == ALU_AND) | (operator_i == ALU_ANDN);

  always_comb begin
    unique case (1'b1)
      bwlogic_or:  bwlogic_result = bwlogic_or_result;
      bwlogic_and: bwlogic_result = bwlogic_and_result;
      default:     bwlogic_result = bwlogic_xor_result;
    endcase
  end

  logic [31:0] shuffle_result;
  logic [31:0] butterfly_result;
  logic [31:0] invbutterfly_result;

  logic [31:0] minmax_result;
  logic [5:0]  bitcnt_result;
  logic [31:0] pack_result;
  logic [31:0] multicycle_result;
  logic [31:0] singlebit_result;

  if (RV32B) begin : g_alu_rvb

    /////////////////
    // Bitcounting //
    /////////////////

    // The bit-counter structure computes the number of set bits in its operand. Partial results
    // (from left to right) are needed to compute the control masks for computation of bext/bdep
    // by the butterfly network, if implemented.
    // For pcnt, clz and ctz, only the end result is used.

    logic        zbe_op;
    logic        bitcnt_ctz;
    logic        bitcnt_clz;
    logic        bitcnt_cz;
    logic [31:0] bitcnt_bits;
    logic [31:0] bitcnt_mask_op;
    logic [31:0] bitcnt_bit_mask;
    logic [ 5:0] bitcnt_partial [32];


    assign bitcnt_ctz    = operator_i == ALU_CTZ;
    assign bitcnt_clz    = operator_i == ALU_CLZ;
    assign bitcnt_cz     = bitcnt_ctz | bitcnt_clz;
    assign bitcnt_result = bitcnt_partial[31];

    // Bit-mask generation for clz and ctz:
    // The bit mask is generated by spreading the lowest-order set bit in the operand to all
    // higher order bits. The resulting mask is inverted to cover the lowest order zeros. In order
    // to create the bit mask for leading zeros, the input operand needs to be reversed.
    assign bitcnt_mask_op = bitcnt_clz ? operand_a_rev : operand_a_i;

    always_comb begin
      bitcnt_bit_mask = bitcnt_mask_op;
      bitcnt_bit_mask |= bitcnt_bit_mask << 1;
      bitcnt_bit_mask |= bitcnt_bit_mask << 2;
      bitcnt_bit_mask |= bitcnt_bit_mask << 4;
      bitcnt_bit_mask |= bitcnt_bit_mask << 8;
      bitcnt_bit_mask |= bitcnt_bit_mask << 16;
      bitcnt_bit_mask = ~bitcnt_bit_mask;
    end

    always_comb begin
      case(1'b1)
        zbe_op:      bitcnt_bits = operand_b_i;
        bitcnt_cz:   bitcnt_bits = bitcnt_bit_mask & ~bitcnt_mask_op; // clz / ctz
        default:     bitcnt_bits = operand_a_i; // pcnt
      endcase
    end

    // The parallel prefix counter is of the structure of a Brent-Kung Adder. In the first
    // log2(width) stages, the sum of the n preceding bit lines is computed for the bit lines at
    // positions 2**n-1 (power-of-two positions) where n denotes the current stage.
    // In stage n=log2(width), the count for position width-1 (the MSB) is finished.
    // For the intermediate values, an inverse adder tree then computes the bit counts for the bit
    // lines at positions
    // m = 2**(n-1) + i*2**(n-2), where i = [1 ... width / 2**(n-1)-1] and n = [log2(width) ... 2].
    // Thus, at every subsequent stage the result of two previously unconnected sub-trees is
    // summed, starting at the node summing bits [width/2-1 : 0] and [3*width/4-1: width/2]
    // and moving to iteratively sum up all the sub-trees.
    // The inverse adder tree thus features log2(width) - 1 stages the first of these stages is a
    // single addition at position 3*width/4 - 1. It does not interfere with the last
    // stage of the primary adder tree. These stages can thus be folded together, resulting in a
    // total of 2*log2(width)-2 stages.
    // For more details refer to R. Brent, H. T. Kung, "A Regular Layout for Parallel Adders",
    // (1982).
    // For a bitline at position p, only bits
    // bitcnt_partial[max(i, such that p % log2(i) == 0)-1 : 0] are needed for generation of the
    // butterfly network control signals. The adders in the intermediate value adder tree thus need
    // not be full 5-bit adders. We leave the optimization to the synthesis tools.
    //
    // Consider the following 8-bit example for illustraton.
    //
    // let bitcnt_bits = 8'babcdefgh.
    //
    //                   a  b  c  d  e  f  g  h
    //                   | /:  | /:  | /:  | /:
    //                   |/ :  |/ :  |/ :  |/ :
    // stage 1:          +  :  +  :  +  :  +  :
    //                   |  : /:  :  |  : /:  :
    //                   |,--+ :  :  |,--+ :  :
    // stage 2:          +  :  :  :  +  :  :  :
    //                   |  :  |  : /:  :  :  :
    //                   |,-----,--+ :  :  :  : ^-primary adder tree
    // stage 3:          +  :  +  :  :  :  :  : -------------------------
    //                   :  | /| /| /| /| /|  : ,-intermediate adder tree
    //                   :  |/ |/ |/ |/ |/ :  :
    // stage 4           :  +  +  +  +  +  :  :
    //                   :  :  :  :  :  :  :  :
    // bitcnt_partial[i] 7  6  5  4  3  2  1  0

    always_comb begin
      bitcnt_partial = '{default: '0};
      // stage 1
      for (int unsigned i=1; i<32; i+=2) begin
        bitcnt_partial[i] = {5'h0, bitcnt_bits[i]} + {5'h0, bitcnt_bits[i-1]};
      end
      // stage 2
      for (int unsigned i=3; i<32; i+=4) begin
        bitcnt_partial[i] = bitcnt_partial[i-2] + bitcnt_partial[i];
      end
      // stage 3
      for (int unsigned i=7; i<32; i+=8) begin
        bitcnt_partial[i] = bitcnt_partial[i-4] + bitcnt_partial[i];
      end
      // stage 4
      for (int unsigned i=15; i <32; i+=16) begin
        bitcnt_partial[i] = bitcnt_partial[i-8] + bitcnt_partial[i];
      end
      // stage 5
      bitcnt_partial[31] = bitcnt_partial[15] + bitcnt_partial[31];
      // ^- primary adder tree
      // -------------------------------
      // ,-intermediate value adder tree
      bitcnt_partial[23] = bitcnt_partial[15] + bitcnt_partial[23];

      // stage 6
      for (int unsigned i=11; i<32; i+=8) begin
        bitcnt_partial[i] = bitcnt_partial[i-4] + bitcnt_partial[i];
      end

      // stage 7
      for (int unsigned i=5; i<32; i+=4) begin
        bitcnt_partial[i] = bitcnt_partial[i-2] + bitcnt_partial[i];
      end
      // stage 8
      bitcnt_partial[0] = {5'h0, bitcnt_bits[0]};
      for (int unsigned i=2; i<32; i+=2) begin
        bitcnt_partial[i] = bitcnt_partial[i-1] + {5'h0, bitcnt_bits[i]};
      end
    end

    ///////////////
    // Butterfly //
    ///////////////

    // The butterfly / inverse butterfly network is shared between bext/bdep (zbe)instructions
    // respectively and grev / gorc instructions (zbp).
    // For bdep, the control bits mask of a local left region is generated by
    // the inverse of a n-bit left rotate and complement upon wrap (LROTC) operation by the number
    // of ones in the deposit bitmask to the right of the segment. n hereby denotes the width
    // of the according segment. The bitmask for a pertaining local right region is equal to the
    // corresponding local left region. Bext uses an analogue inverse process.
    // Consider the following 8-bit example.  For details, see Hilewitz et al. "Fast Bit Gather,
    // Bit Scatter and Bit Permuation Instructions for Commodity Microprocessors", (2008).

    // 8-bit example:  (Hilewitz et al.)
    // Consider the instruction bdep operand_a_i deposit_mask
    // Let operand_a_i = 8'babcd_efgh
    //    deposit_mask = 8'b1010_1101
    //
    // control bitmask for stage 1:
    //  - number of ones in the right half of the deposit bitmask: 3
    //  - width of the segment: 4
    //  - control bitmask = ~LROTC(4'b0, 3)[3:0] = 4'b1000
    //
    // control bitmask:   c3 c2  c1 c0  c3 c2  c1 c0
    //                    1  0   0  0   1  0   0  0
    //                    <- L ----->   <- R ----->
    // operand_a_i        a  b   c  d   e  f   g  h
    //                    :\ |   |  |  /:  |   |  |
    //                    : +|---|--|-+ :  |   |  |
    //                    :/ |   |  |  \:  |   |  |
    // stage 1            e  b   c  d   a  f   g  h
    //                    <L->   <R->   <L->   <R->
    // control bitmask:   c3 c2  c3 c2  c1 c0  c1 c0
    //                    1  1   1  1   1  0   1  0
    //                    :\ :\ /: /:   :\ |  /:  |
    //                    : +:-+-:+ :   : +|-+ :  |
    //                    :/ :/ \: \:   :/ |  \:  |
    // stage 2            c  d   e  b   g  f   a  h
    //                    L  R   L  R   L  R   L  R
    // control bitmask:   c3 c3  c2 c2  c1 c1  c0 c0
    //                    1  1   0  0   1  1   0  0
    //                    :\/:   |  |   :\/:   |  |
    //                    :  :   |  |   :  :   |  |
    //                    :/\:   |  |   :/\:   |  |
    // stage 3            d  c   e  b   f  g   a  h
    // & deposit bitmask: 1  0   1  0   1  1   0  1
    // result:            d  0   e  0   f  g   0  h

    assign zbe_op = (operator_i == ALU_BEXT) | (operator_i == ALU_BDEP);

    logic [31:0] butterfly_mask_l[5];
    logic [31:0] butterfly_mask_r[5];
    logic [31:0] butterfly_mask_not[5];
    logic [31:0] lrotc_stage [5]; // left rotate and complement upon wrap

    // bext / bdep
    logic [31:0] butterfly_zbe_mask_l[5];
    logic [31:0] butterfly_zbe_mask_r[5];
    logic [31:0] butterfly_zbe_mask_not[5];

    // grev / gorc
    logic [31:0] butterfly_zbp_mask_l[5];
    logic [31:0] butterfly_zbp_mask_r[5];
    logic [31:0] butterfly_zbp_mask_not[5];

    logic grev_op;
    logic gorc_op;
    logic zbp_op;

    // number of bits in local r = 32 / 2**(stage + 1) = 16/2**stage
    `define _N(stg) (16 >> stg)

    // bext / bdep control bit generation
    for (genvar stg=0; stg<5; stg++) begin
      // number of segs: 2** stg
      for (genvar seg=0; seg<2**stg; seg++) begin

        assign lrotc_stage[stg][2*`_N(stg)*(seg+1)-1 : 2*`_N(stg)*seg] =
            {{`_N(stg){1'b0}},{`_N(stg){1'b1}}} <<
                bitcnt_partial[`_N(stg)*(2*seg+1)-1][$clog2(`_N(stg)):0];

        assign butterfly_zbe_mask_l[stg][`_N(stg)*(2*seg+2)-1 : `_N(stg)*(2*seg+1)]
                     = ~lrotc_stage[stg][`_N(stg)*(2*seg+2)-1 : `_N(stg)*(2*seg+1)];

        assign butterfly_zbe_mask_r[stg][`_N(stg)*(2*seg+1)-1 : `_N(stg)*(2*seg)]
                     = ~lrotc_stage[stg][`_N(stg)*(2*seg+2)-1 : `_N(stg)*(2*seg+1)];

        assign butterfly_zbe_mask_l[stg][`_N(stg)*(2*seg+1)-1 : `_N(stg)*(2*seg)]   = '0;
        assign butterfly_zbe_mask_r[stg][`_N(stg)*(2*seg+2)-1 : `_N(stg)*(2*seg+1)] = '0;
      end
    end
    `undef _N

    for (genvar stg=0; stg<5; stg++) begin
      assign butterfly_zbe_mask_not[stg] =
          ~(butterfly_zbe_mask_l[stg] | butterfly_zbe_mask_r[stg]);
    end

    // grev / gorc control bit generation
    assign butterfly_zbp_mask_l[0] = shift_amt[4] ? 32'hffff_0000 : 32'h0000_0000;
    assign butterfly_zbp_mask_r[0] = shift_amt[4] ? 32'h0000_ffff : 32'h0000_0000;
    assign butterfly_zbp_mask_not[0] =
       !shift_amt[4] || (shift_amt[4] && gorc_op) ? 32'hffff_ffff : 32'h0000_0000;

    assign butterfly_zbp_mask_l[1] = shift_amt[3] ? 32'hff00_ff00 : 32'h0000_0000;
    assign butterfly_zbp_mask_r[1] = shift_amt[3] ? 32'h00ff_00ff : 32'h0000_0000;
    assign butterfly_zbp_mask_not[1] =
       !shift_amt[3] || (shift_amt[3] && gorc_op) ? 32'hffff_ffff : 32'h0000_0000;

    assign butterfly_zbp_mask_l[2] = shift_amt[2] ? 32'hf0f0_f0f0 : 32'h0000_0000;
    assign butterfly_zbp_mask_r[2] = shift_amt[2] ? 32'h0f0f_0f0f : 32'h0000_0000;
    assign butterfly_zbp_mask_not[2] =
       !shift_amt[2] || (shift_amt[2] && gorc_op) ? 32'hffff_ffff : 32'h0000_0000;

    assign butterfly_zbp_mask_l[3] = shift_amt[1] ? 32'hcccc_cccc : 32'h0000_0000;
    assign butterfly_zbp_mask_r[3] = shift_amt[1] ? 32'h3333_3333 : 32'h0000_0000;
    assign butterfly_zbp_mask_not[3] =
       !shift_amt[1] || (shift_amt[1] && gorc_op) ? 32'hffff_ffff : 32'h0000_0000;

    assign butterfly_zbp_mask_l[4] = shift_amt[0] ? 32'haaaa_aaaa : 32'h0000_0000;
    assign butterfly_zbp_mask_r[4] = shift_amt[0] ? 32'h5555_5555 : 32'h0000_0000;
    assign butterfly_zbp_mask_not[4] =
       !shift_amt[0] || (shift_amt[0] && gorc_op) ? 32'hffff_ffff : 32'h0000_0000;

    // grev / gorc instructions
    assign grev_op = RV32B ? (operator_i == ALU_GREV) : 1'b0;
    assign gorc_op = RV32B ? (operator_i == ALU_GORC) : 1'b0;
    assign zbp_op = grev_op | gorc_op;

    // select set of masks:
    assign butterfly_mask_l   = zbp_op ? butterfly_zbp_mask_l   : butterfly_zbe_mask_l;
    assign butterfly_mask_r   = zbp_op ? butterfly_zbp_mask_r   : butterfly_zbe_mask_r;
    assign butterfly_mask_not = zbp_op ? butterfly_zbp_mask_not : butterfly_zbe_mask_not;

    always_comb begin
      butterfly_result = operand_a_i;

      butterfly_result = butterfly_result & butterfly_mask_not[0] |
          ((butterfly_result & butterfly_mask_l[0]) >> 16)|
          ((butterfly_result & butterfly_mask_r[0]) << 16);

      butterfly_result = butterfly_result & butterfly_mask_not[1] |
          ((butterfly_result & butterfly_mask_l[1]) >> 8)|
          ((butterfly_result & butterfly_mask_r[1]) << 8);

      butterfly_result = butterfly_result & butterfly_mask_not[2] |
          ((butterfly_result & butterfly_mask_l[2]) >> 4)|
          ((butterfly_result & butterfly_mask_r[2]) << 4);

      butterfly_result = butterfly_result & butterfly_mask_not[3] |
          ((butterfly_result & butterfly_mask_l[3]) >> 2)|
          ((butterfly_result & butterfly_mask_r[3]) << 2);

      butterfly_result = butterfly_result & butterfly_mask_not[4] |
          ((butterfly_result & butterfly_mask_l[4]) >> 1)|
          ((butterfly_result & butterfly_mask_r[4]) << 1);

      if (!zbp_op) begin
        butterfly_result = butterfly_result & operand_b_i;
      end
    end

    always_comb begin
      invbutterfly_result = operand_a_i & operand_b_i;

      invbutterfly_result = invbutterfly_result & butterfly_mask_not[4] |
          ((invbutterfly_result & butterfly_mask_l[4]) >> 1)|
          ((invbutterfly_result & butterfly_mask_r[4]) << 1);

      invbutterfly_result = invbutterfly_result & butterfly_mask_not[3] |
          ((invbutterfly_result & butterfly_mask_l[3]) >> 2)|
          ((invbutterfly_result & butterfly_mask_r[3]) << 2);

      invbutterfly_result = invbutterfly_result & butterfly_mask_not[2] |
          ((invbutterfly_result & butterfly_mask_l[2]) >> 4)|
          ((invbutterfly_result & butterfly_mask_r[2]) << 4);

      invbutterfly_result = invbutterfly_result & butterfly_mask_not[1] |
          ((invbutterfly_result & butterfly_mask_l[1]) >> 8)|
          ((invbutterfly_result & butterfly_mask_r[1]) << 8);

      invbutterfly_result = invbutterfly_result & butterfly_mask_not[0] |
          ((invbutterfly_result & butterfly_mask_l[0]) >> 16)|
          ((invbutterfly_result & butterfly_mask_r[0]) << 16);
    end

    /////////////////////////
    // Shuffle / Unshuffle //
    /////////////////////////

    localparam logic [31:0] SHUFFLE_MASK_L [0:3] =
        '{32'h00ff_0000, 32'h0f00_0f00, 32'h3030_3030, 32'h4444_4444};
    localparam logic [31:0] SHUFFLE_MASK_R [0:3] =
        '{32'h0000_ff00, 32'h00f0_00f0, 32'h0c0c_0c0c, 32'h2222_2222};

    localparam logic [31:0] FLIP_MASK_L [0:3] =
        '{32'h2200_1100, 32'h0044_0000, 32'h4411_0000, 32'h1100_0000};
    localparam logic [31:0] FLIP_MASK_R [0:3] =
        '{32'h0088_0044, 32'h0000_2200, 32'h0000_8822, 32'h0000_0088};

    logic [31:0] SHUFFLE_MASK_NOT [0:3];
    for(genvar i = 0; i < 4; i++) begin : gen_shuffle_mask_not
      assign SHUFFLE_MASK_NOT[i] = ~(SHUFFLE_MASK_L[i] | SHUFFLE_MASK_R[i]);
    end

    logic shuffle_flip;
    assign shuffle_flip = operator_i == ALU_UNSHFL;

    logic [3:0] shuffle_mode;

    always_comb begin
      shuffle_result = operand_a_i;

      if (shuffle_flip) begin
        shuffle_mode[3] = shift_amt[0];
        shuffle_mode[2] = shift_amt[1];
        shuffle_mode[1] = shift_amt[2];
        shuffle_mode[0] = shift_amt[3];
      end else begin
        shuffle_mode = shift_amt[3:0];
      end

      if (shuffle_flip) begin
        shuffle_result = (shuffle_result & 32'h8822_4411) |
            ((shuffle_result << 6)  & FLIP_MASK_L[0]) | ((shuffle_result >> 6)  & FLIP_MASK_R[0]) |
            ((shuffle_result << 9)  & FLIP_MASK_L[1]) | ((shuffle_result >> 9)  & FLIP_MASK_R[1]) |
            ((shuffle_result << 15) & FLIP_MASK_L[2]) | ((shuffle_result >> 15) & FLIP_MASK_R[2]) |
            ((shuffle_result << 21) & FLIP_MASK_L[3]) | ((shuffle_result >> 21) & FLIP_MASK_R[3]);
      end

      if (shuffle_mode[3]) begin
        shuffle_result = (shuffle_result & SHUFFLE_MASK_NOT[0]) |
            (((shuffle_result << 8) & SHUFFLE_MASK_L[0]) |
            ((shuffle_result >> 8) & SHUFFLE_MASK_R[0]));
      end
      if (shuffle_mode[2]) begin
        shuffle_result = (shuffle_result & SHUFFLE_MASK_NOT[1]) |
            (((shuffle_result << 4) & SHUFFLE_MASK_L[1]) |
            ((shuffle_result >> 4) & SHUFFLE_MASK_R[1]));
      end
      if (shuffle_mode[1]) begin
        shuffle_result = (shuffle_result & SHUFFLE_MASK_NOT[2]) |
            (((shuffle_result << 2) & SHUFFLE_MASK_L[2]) |
            ((shuffle_result >> 2) & SHUFFLE_MASK_R[2]));
      end
      if (shuffle_mode[0]) begin
        shuffle_result = (shuffle_result & SHUFFLE_MASK_NOT[3]) |
            (((shuffle_result << 1) & SHUFFLE_MASK_L[3]) |
            ((shuffle_result >> 1) & SHUFFLE_MASK_R[3]));
      end

      if (shuffle_flip) begin
        shuffle_result = (shuffle_result & 32'h8822_4411) |
            ((shuffle_result << 6)  & FLIP_MASK_L[0]) | ((shuffle_result >> 6) & FLIP_MASK_R[0])  |
            ((shuffle_result << 9)  & FLIP_MASK_L[1]) | ((shuffle_result >> 9) & FLIP_MASK_R[1])  |
            ((shuffle_result << 15) & FLIP_MASK_L[2]) | ((shuffle_result >> 15) & FLIP_MASK_R[2]) |
            ((shuffle_result << 21) & FLIP_MASK_L[3]) | ((shuffle_result >> 21) & FLIP_MASK_R[3]);
      end

    end

    //////////////////////////////////////
    // Multicycle Bitmanip Instructions //
    //////////////////////////////////////
    // Ternary instructions + Shift Rotations
    // For ternary instructions (zbt), operand_a_i is tied to rs1 in the first cycle and rs3 in the
    // second cycle. operand_b_i is always tied to rs2.

    always_comb begin
      unique case (operator_i)
        ALU_CMOV: begin
            imd_val_d_o = operand_a_i;
            multicycle_result = (operand_b_i == 32'h0) ? operand_a_i : imd_val_q_i;
          if (instr_first_cycle_i) begin
            imd_val_we_o = 1'b1;
          end else begin
            imd_val_we_o = 1'b0;
          end
        end

        ALU_CMIX: begin
          multicycle_result = imd_val_q_i | bwlogic_and_result;
          imd_val_d_o = bwlogic_and_result;
          if (instr_first_cycle_i) begin
            imd_val_we_o = 1'b1;
          end else begin
            imd_val_we_o = 1'b0;
          end
        end

        ALU_FSR, ALU_FSL,
        ALU_ROL, ALU_ROR: begin
          if (shift_amt[4:0] == 5'h0) begin
            multicycle_result = shift_amt[5] ? operand_a_i : imd_val_q_i;
          end else begin
            multicycle_result = imd_val_q_i | shift_result;
          end
          imd_val_d_o = shift_result;
          if (instr_first_cycle_i) begin
            imd_val_we_o = 1'b1;
          end else begin
            imd_val_we_o = 1'b0;
          end
        end
        default: begin
          imd_val_d_o = operand_a_i;
          imd_val_we_o = 1'b0;
          multicycle_result = operand_a_i;
        end
      endcase
    end

    /////////////////////////////
    // Single-bit Instructions //
    /////////////////////////////

    always_comb begin
      unique case (operator_i)
        ALU_SBSET: singlebit_result = operand_a_i | shift_result;
        ALU_SBCLR: singlebit_result = operand_a_i & ~shift_result;
        ALU_SBINV: singlebit_result = operand_a_i ^ shift_result;
        default:   singlebit_result = {31'h0, shift_result[0]}; // ALU_SBEXT
      endcase
    end

    ///////////////
    // Min / Max //
    ///////////////

    assign minmax_result = cmp_result ? operand_a_i : operand_b_i;


    //////////
    // Pack //
    //////////

    logic packu;
    logic packh;
    assign packu = operator_i == ALU_PACKU;
    assign packh = operator_i == ALU_PACKH;

    always_comb begin
      unique case (1'b1)
        packu:   pack_result = {operand_b_i[31:16], operand_a_i[31:16]};
        packh:   pack_result = {16'h0, operand_b_i[7:0], operand_a_i[7:0]};
        default: pack_result = {operand_b_i[15:0], operand_a_i[15:0]};
      endcase
    end
  end else begin : g_no_alu_rvb
    // RV32B result signals
    assign minmax_result       = '0;
    assign bitcnt_result       = '0;
    assign pack_result         = '0;
    assign multicycle_result   = '0;
    assign singlebit_result    = '0;
    assign shuffle_result      = '0;
    assign butterfly_result    = '0;
    assign invbutterfly_result = '0;
    // RV32B support signals
    assign imd_val_d_o         = '0;
    assign imd_val_we_o        = '0;
  end

  ////////////////
  // Result mux //
  ////////////////

  always_comb begin
    result_o   = '0;

    unique case (operator_i)
      // Bitwise Logic Operations (negate: RV32B Ops)
      ALU_XOR,  ALU_XNOR,
      ALU_OR,   ALU_ORN,
      ALU_AND,  ALU_ANDN: result_o = bwlogic_result;

      // Adder Operations
      ALU_ADD,  ALU_SUB: result_o = adder_result;

      // Shift Operations
      ALU_SLL,  ALU_SRL,
      ALU_SRA,
      // RV32B Ops
      ALU_SLO,  ALU_SRO: result_o = shift_result;

      // Shuffle Operations (RV32B Ops)
      ALU_SHFL, ALU_UNSHFL: result_o = shuffle_result;

      // Comparison Operations
      ALU_EQ,   ALU_NE,
      ALU_GE,   ALU_GEU,
      ALU_LT,   ALU_LTU,
      ALU_SLT,  ALU_SLTU: result_o = {31'h0,cmp_result};

      // MinMax Operations (RV32B Ops)
      ALU_MIN,  ALU_MAX,
      ALU_MINU, ALU_MAXU: result_o = minmax_result;

      // Bitcount Operations (RV32B Ops)
      ALU_CLZ, ALU_CTZ,
      ALU_PCNT: result_o = {26'h0, bitcnt_result};

      // Pack Operations (RV32B Ops)
      ALU_PACK, ALU_PACKH,
      ALU_PACKU: result_o = pack_result;

      // Ternary Bitmanip Operations (RV32B Ops)
      ALU_CMIX, ALU_CMOV,
      ALU_FSL,  ALU_FSR,
      ALU_ROL,  ALU_ROR: result_o = multicycle_result;

      // Single-Bit Bitmanip Operations (RV32B Ops)
      ALU_SBSET, ALU_SBCLR,
      ALU_SBINV, ALU_SBEXT: result_o = singlebit_result;

      // Bit Extract / Deposit (RV32B Ops)
      ALU_BDEP:  result_o = butterfly_result;
      ALU_BEXT:  result_o = invbutterfly_result;

      // General Reverse / Or-combine (RV32B Ops)
      ALU_GREV, ALU_GORC: result_o = butterfly_result;

      default: ;
    endcase
  end

endmodule
