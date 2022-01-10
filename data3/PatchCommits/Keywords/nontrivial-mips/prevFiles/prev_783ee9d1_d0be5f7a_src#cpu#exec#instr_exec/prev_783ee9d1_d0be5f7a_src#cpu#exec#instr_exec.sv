`include "cpu_defs.svh"

module instr_exec (
	input  logic    clk,
	input  logic    rst,
	input  logic    flush,

	input  logic             delayslot,
	input  logic             llbit_value,
	input  uint64_t          hilo,
	input  pipeline_decode_t data,
	output pipeline_exec_t   result,
	output branch_resolved_t resolved_branch,
	output logic             stall_req,

	input  logic        is_usermode,
	input  uint32_t     cp0_rdata_i,
	output logic [2:0]  cp0_rsel,
	output reg_addr_t   cp0_raddr,
	input  cp0_req_t    cp0_req_fwd,

	output virt_t       mmu_vaddr,
	input  mmu_result_t mmu_result
);

oper_t op;
exception_t ex;
uint32_t exec_ret, reg1, reg2, instr;
assign reg1 = data.reg1;
assign reg2 = data.reg2;
assign instr = data.fetch.instr;
assign op = data.decoded.op;

assign result.valid  = data.valid;
assign result.ex     = ex;
assign result.result = exec_ret;
assign result.pc     = data.fetch.vaddr;
assign result.eret   = (op == OP_ERET);
assign result.delayslot    = delayslot;
assign result.tlbreq.probe = (op == OP_TLBP);
assign result.tlbreq.read  = (op == OP_TLBR);
assign result.tlbreq.tlbwr = (op == OP_TLBWR);
assign result.tlbreq.tlbwi = (op == OP_TLBWI);

// unsigned register arithmetic
uint32_t add_u, sub_u;
assign add_u = reg1 + reg2;
assign sub_u = reg1 - reg2;

// overflow checking
logic ov_add, ov_sub;
assign ov_add = (reg1[31] == reg2[31]) & (reg1[31] ^ add_u[31]);
assign ov_sub = (reg1[31] ^ reg2[31]) & (reg1[31] ^ sub_u[31]);

// comparsion
logic signed_lt, unsigned_lt;
assign signed_lt = (reg1[31] != reg2[31]) ? reg1[31] : sub_u[31];
assign unsigned_lt = (reg1 < reg2);

// count leading bits
uint32_t clz_cnt, clo_cnt;
count_bit count_clz(
	.bit_val(1'b0),
	.val(reg1),
	.count(clz_cnt)
);

count_bit count_clo(
	.bit_val(1'b1),
	.val(reg1),
	.count(clo_cnt)
);

// multi-cycle execution
logic multi_cyc_busy;
uint32_t mult_word;
uint64_t multi_cyc_ret;
multi_cycle_exec multi_cyc_instance(
	.*,
	.ret     ( multi_cyc_ret  ),
	.is_busy ( multi_cyc_busy )
);

assign stall_req = multi_cyc_busy;

// conditional move
always_comb begin
	result.decoded = data.decoded;
	if(op == OP_MOVZ && reg2 != '0
		|| op == OP_MOVN && reg2 == '0)
		result.decoded.rd = '0;
end

// setup hilo request
always_comb begin
	result.hiloreq.we = 1'b1;
	unique case(op)
		OP_MTHI: result.hiloreq.wdata = { reg1, hilo[31:0]  };
		OP_MTLO: result.hiloreq.wdata = { hilo[63:32], reg1 };
		OP_MADDU, OP_MADD, OP_MSUBU, OP_MSUB,
		OP_MULT, OP_MULTU, OP_DIV, OP_DIVU:
			result.hiloreq.wdata = multi_cyc_ret;
		default: begin
			result.hiloreq.we    = 1'b0;
			result.hiloreq.wdata = '0;
		end
	endcase
end

// CP0 operation
uint32_t cp0_wmask, cp0_rdata;
cp0_write_mask cp0_write_mask_inst(
	.rst,
	.sel  ( cp0_rsel  ),
	.addr ( cp0_raddr ),
	.mask ( cp0_wmask )
);

function logic cp0_match(
	input cp0_req_t   req,
	input reg_addr_t  addr,
	input logic [2:0] sel
);
	return req.we && req.waddr == addr && req.wsel == sel;
endfunction

always_comb begin
	if(rst) begin
		cp0_rdata = '0;
	end else begin
		cp0_rdata = cp0_rdata_i;
		if(cp0_match(cp0_req_fwd, cp0_raddr, cp0_rsel))
			cp0_rdata = (cp0_wmask & cp0_req_fwd.wdata) | (~cp0_wmask & cp0_rdata_i);
	end
end

assign cp0_raddr = instr[15:11];
assign cp0_rsel  = instr[2:0];
assign result.cp0_req.we    = (op == OP_MTC0);
assign result.cp0_req.wdata = reg1;
assign result.cp0_req.waddr = instr[15:11];
assign result.cp0_req.wsel  = instr[2:0];

// setup execution result
always_comb begin
	exec_ret = '0;
	unique case(op)
		/* logical instructions */
		OP_LUI: exec_ret = { instr[15:0], 16'b0 };
		OP_AND: exec_ret = reg1 & reg2;
		OP_OR:  exec_ret = reg1 | reg2;
		OP_XOR: exec_ret = reg1 ^ reg2;
		OP_NOR: exec_ret = ~(reg1 | reg2);

		/* add and subtract */
		OP_ADD, OP_ADDU: exec_ret = add_u;
		OP_SUB, OP_SUBU: exec_ret = sub_u;

		/* bits counting */
		OP_CLZ: exec_ret = clz_cnt;
		OP_CLO: exec_ret = clo_cnt;

		/* move instructions */
		OP_MOVZ, OP_MOVN: exec_ret = reg1;
		OP_MFHI: exec_ret = hilo[63:32];
		OP_MFLO: exec_ret = hilo[31:0];

		/* multiplication */
		OP_MUL: exec_ret = mult_word;

		/* jump instructions */
		OP_JAL, OP_BLTZAL, OP_BGEZAL, OP_JALR:
			exec_ret = result.pc + 32'd8;

		/* shift instructions */
		OP_SLL:  exec_ret = reg2 << instr[10:6];
		OP_SLLV: exec_ret = reg2 << reg1[4:0];
		OP_SRL:  exec_ret = reg2 >> instr[10:6];
		OP_SRLV: exec_ret = reg2 >> reg1[4:0];
		OP_SRA:  exec_ret = $signed(reg2) >>> instr[10:6];
		OP_SRAV: exec_ret = $signed(reg2) >>> reg1[4:0];

		/* compare and set */
		OP_SLTU: exec_ret = { 30'b0, unsigned_lt };
		OP_SLT:  exec_ret = { 30'b0, signed_lt   };

		/* conditional store */
		OP_SC:   exec_ret = llbit_value;

		/* read coprocessers */
		OP_MFC0: exec_ret = cp0_rdata;
		default: exec_ret = '0;
	endcase
end

/* memory operation */
uint32_t extended_imm, mem_wrdata;
logic [3:0] mem_sel;
assign extended_imm = { {16{instr[15]}}, instr[15:0] };
assign mmu_vaddr = reg1 + extended_imm;

assign result.memreq.read       = data.decoded.is_load;
assign result.memreq.write      = data.decoded.is_store
                                  & (llbit_value || (op != OP_SC));
assign result.memreq.uncached   = mmu_result.uncached;
assign result.memreq.vaddr      = mmu_vaddr;
assign result.memreq.paddr      = mmu_result.phy_addr;
assign result.memreq.wrdata     = mem_wrdata;
assign result.memreq.byteenable = mem_sel;

always_comb begin
	unique case(op)
		OP_LW, OP_LL, OP_SW, OP_SC: begin
			mem_wrdata = reg2;
			mem_sel = 4'b1111;
		end
		OP_LB, OP_LBU, OP_SB: begin
			mem_wrdata = reg2 << (mmu_vaddr[1:0] * 8);
			mem_sel = 4'b0001 << mmu_vaddr[1:0];
		end
		OP_LH, OP_LHU, OP_SH: begin
			mem_wrdata = mmu_vaddr[1] ? (reg2 << 16) : reg2;
			mem_sel = mmu_vaddr[1] ? 4'b1100 : 4'b0011;
		end
		OP_LWL: begin
			mem_wrdata = reg2;
			unique case(mmu_vaddr[1:0])
				2'd0: mem_sel = 4'b1000;
				2'd1: mem_sel = 4'b1100;
				2'd2: mem_sel = 4'b1110;
				2'd3: mem_sel = 4'b1111;
			endcase
		end
		OP_LWR: begin
			mem_wrdata = reg2;
			unique case(mmu_vaddr[1:0])
				2'd0: mem_sel = 4'b1111;
				2'd1: mem_sel = 4'b0111;
				2'd2: mem_sel = 4'b0011;
				2'd3: mem_sel = 4'b0001;
			endcase
		end
		OP_SWL:
		begin
			mem_wrdata = reg2 >> ((3 - mmu_vaddr[1:0]) * 8);
			unique case(mmu_vaddr[1:0])
				2'd0: mem_sel = 4'b0001;
				2'd1: mem_sel = 4'b0011;
				2'd2: mem_sel = 4'b0111;
				2'd3: mem_sel = 4'b1111;
			endcase
		end
		OP_SWR:
		begin
			mem_wrdata = reg2 << (mmu_vaddr[1:0] * 8);
			unique case(mmu_vaddr[1:0])
				2'd0: mem_sel = 4'b1111;
				2'd1: mem_sel = 4'b1110;
				2'd2: mem_sel = 4'b1100;
				2'd3: mem_sel = 4'b1000;
			endcase
		end
		default: begin
			mem_sel    = '0;
			mem_wrdata = '0;
		end
	endcase
end

/* exception */
logic trap_valid, daddr_unaligned, invalid_instr;
always_comb begin
	unique case(op)
		OP_TEQ:  trap_valid = (reg1 == reg2);
		OP_TNE:  trap_valid = (reg1 != reg2);
		OP_TGE:  trap_valid = ~signed_lt;
		OP_TLT:  trap_valid = signed_lt;
		OP_TGEU: trap_valid = ~unsigned_lt;
		OP_TLTU: trap_valid = unsigned_lt;
		default: trap_valid = 1'b0;
	endcase
	unique case(op)
		OP_LW, OP_LL, OP_SW, OP_SC:
			daddr_unaligned = mmu_vaddr[0] | mmu_vaddr[1];
		OP_LH, OP_LHU, OP_SH:
			daddr_unaligned = mmu_vaddr[0];
		default: daddr_unaligned = 1'b0;
	endcase
end


// ( illegal | unaligned, miss | invalid )
logic [1:0] ex_if;  // exception in IF
assign ex_if = {
	data.fetch.iaddr_ex.illegal | |data.fetch.vaddr[1:0],
	data.fetch.iaddr_ex.miss | data.fetch.iaddr_ex.invalid
};

// ( trap, break, syscall, overflow, privilege )
logic [4:0] ex_ex;  // exception in EX
assign ex_ex = {
	trap_valid,
	op == OP_BREAK,
	op == OP_SYSCALL,
	((op == OP_ADD) & ov_add) | ((op == OP_SUB) & ov_sub),
	data.decoded.is_priv & is_usermode
};

assign invalid_instr = (op == OP_INVALID);

logic mem_tlbex, mem_addrex;
assign mem_tlbex  = (mmu_result.miss | mmu_result.invalid) & ~mem_addrex;
assign mem_addrex = mmu_result.illegal | daddr_unaligned;
// ( addrex_r, addrex_w, tlbex_r, tlbex_w, readonly )
logic [4:0] ex_mm;  // exception in MEM
assign ex_mm = {
	mem_addrex & result.memreq.read,
	mem_addrex & result.memreq.write,
	mem_tlbex & result.memreq.read,
	mem_tlbex & result.memreq.write,
	~mmu_result.dirty & result.memreq.write
};

always_comb begin
	ex = '0;
	ex.valid = ((|ex_if) | invalid_instr | (|ex_ex) | (|ex_mm)) & data.valid;
	if(|ex_if) begin
		ex.extra = data.fetch.vaddr;
		unique casez(ex_if)
			2'b1?: ex.exc_code = `EXCCODE_ADEL;
			2'b01: ex.exc_code = `EXCCODE_TLBL;
			default:;
		endcase
	end else if(invalid_instr) begin
		ex.exc_code = `EXCCODE_RI;
	end else if(|ex_ex) begin
		unique case(ex_ex)
			5'b10000: ex.exc_code = `EXCCODE_TR;
			5'b01000: ex.exc_code = `EXCCODE_BP;
			5'b00100: ex.exc_code = `EXCCODE_SYS;
			5'b00010: ex.exc_code = `EXCCODE_OV;
			5'b00001: ex.exc_code = `EXCCODE_CpU;
			default:;
		endcase
	end else if(|ex_mm) begin
		ex.extra = mmu_vaddr;
		unique casez(ex_mm)
			5'b1????: ex.exc_code = `EXCCODE_ADEL;
			5'b01???: ex.exc_code = `EXCCODE_ADES;
			5'b001??: ex.exc_code = `EXCCODE_TLBL;
			5'b0001?: ex.exc_code = `EXCCODE_TLBS;
			5'b00001: ex.exc_code = `EXCCODE_MOD;
			default:;
		endcase
	end
end

/* resolve branch */
logic reg_equal;
virt_t pc_plus4, pc_plus8;
virt_t default_jump_j, default_jump_i;
assign pc_plus4       = result.pc + 32'd4;
assign pc_plus8       = result.pc + 32'd8;
assign default_jump_i = pc_plus4 + { {14{instr[15]}}, instr[15:0], 2'b0 };
assign default_jump_j = { pc_plus4[31:28], instr[25:0], 2'b0 };
assign reg_equal = (reg1 == reg2);

assign resolved_branch.valid = data.decoded.is_controlflow;
assign resolved_branch.pc    = data.fetch.vaddr;
assign resolved_branch.mispredict = 
     resolved_branch.cf != data.fetch.branch_predict.cf
  || resolved_branch.target != data.fetch.branch_predict.predict_vaddr;
always_comb begin
	unique case(op)
		OP_BLTZ, OP_BLTZAL: resolved_branch.taken = reg1[31];
		OP_BGEZ, OP_BGEZAL: resolved_branch.taken = ~reg1[31];
		OP_BEQ:  resolved_branch.taken = reg_equal;
		OP_BNE:  resolved_branch.taken = ~reg_equal;
		OP_BLEZ: resolved_branch.taken = reg_equal | reg1[31];
		OP_BGTZ: resolved_branch.taken = ~reg_equal & ~reg1[31];
		default: resolved_branch.taken = 1'b1;
	endcase

	resolved_branch.cf     = ControlFlow_None;
	resolved_branch.target = '0;
	unique case(op)
		OP_BLTZ, OP_BLTZAL, OP_BGEZ, OP_BGEZAL,
		OP_BEQ,  OP_BNE,    OP_BLEZ, OP_BGTZ: begin
			if(resolved_branch.taken)
				resolved_branch.cf = ControlFlow_Branch;
			resolved_branch.target = default_jump_i;
		end
		OP_JAL:  begin
			resolved_branch.cf = ControlFlow_JumpImm;
			resolved_branch.target = default_jump_j;
		end
		OP_JALR: begin
			resolved_branch.cf = ControlFlow_JumpReg;
			resolved_branch.target = reg1;
		end
		default:;
	endcase
end

endmodule
