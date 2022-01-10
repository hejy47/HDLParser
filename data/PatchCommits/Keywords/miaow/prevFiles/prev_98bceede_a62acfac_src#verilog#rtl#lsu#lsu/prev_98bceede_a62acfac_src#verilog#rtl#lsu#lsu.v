module lsu
  (/*AUTOARG*/
   // Outputs
   issue_ready, vgpr_instr_done, vgpr_source1_rd_en,
   vgpr_source2_rd_en, sgpr_instr_done, sgpr_source1_rd_en,
   sgpr_source2_rd_en, mem_gm_or_lds, tracemon_gm_or_lds,
   vgpr_dest_wr_en, mem_rd_en, mem_wr_en, sgpr_dest_wr_en,
   vgpr_instr_done_wfid, exec_rd_wfid, sgpr_instr_done_wfid,
   mem_tag_req, sgpr_source1_addr, sgpr_source2_addr, sgpr_dest_addr,
   vgpr_source1_addr, vgpr_source2_addr, vgpr_dest_addr,
   tracemon_retire_pc, vgpr_dest_wr_mask, mem_wr_mask, sgpr_dest_data,
   mem_addr, vgpr_dest_data, mem_wr_data, rfa_dest_wr_req,
   // Inputs
   clk, rst, issue_lsu_select, mem_ack, issue_wfid, mem_tag_resp,
   issue_source_reg1, issue_source_reg2, issue_source_reg3,
   issue_dest_reg, issue_mem_sgpr, issue_imm_value0, issue_lds_base,
   issue_imm_value1, issue_opcode, sgpr_source2_data,
   exec_rd_m0_value, issue_instr_pc, exec_exec_value,
   sgpr_source1_data, vgpr_source2_data, vgpr_source1_data,
   mem_rd_data, lsu_stall
   );

   input clk;

   input rst;

   input issue_lsu_select, mem_ack;
   input [5:0] issue_wfid;
   input [6:0] mem_tag_resp;
   input [11:0] issue_source_reg1, issue_source_reg2, issue_source_reg3,
		issue_dest_reg, issue_mem_sgpr;
   input [15:0] issue_imm_value0, issue_lds_base;
   input [31:0] issue_imm_value1, issue_opcode, sgpr_source2_data, exec_rd_m0_value,
		issue_instr_pc;
   input [63:0] exec_exec_value;
   input [127:0] sgpr_source1_data;
   input [2047:0] vgpr_source2_data;
   /////////////////////////////////////////////////CHANGE
   input [2047:0] vgpr_source1_data;
   input [31:0] mem_rd_data;
   input lsu_stall;

   output 	  issue_ready, vgpr_instr_done, vgpr_source1_rd_en, vgpr_source2_rd_en,
		  sgpr_instr_done, sgpr_source1_rd_en, sgpr_source2_rd_en, mem_gm_or_lds,
		  tracemon_gm_or_lds;
   output vgpr_dest_wr_en, mem_rd_en, mem_wr_en;
   output [3:0] sgpr_dest_wr_en;
   output [5:0]   vgpr_instr_done_wfid, exec_rd_wfid, sgpr_instr_done_wfid;
   output [6:0]   mem_tag_req;
   output [8:0]   sgpr_source1_addr, sgpr_source2_addr, sgpr_dest_addr;
   output [9:0]   vgpr_source1_addr, vgpr_source2_addr, vgpr_dest_addr;
   output [31:0]  tracemon_retire_pc;
   output [63:0]  vgpr_dest_wr_mask, mem_wr_mask;
   output [127:0] sgpr_dest_data;
   output [31:0] mem_addr;
   ////////////////////////////////////////////////CHANGE
   output [2047:0] vgpr_dest_data;
   output [31:0] mem_wr_data;

   output 	   rfa_dest_wr_req;
   
   wire [31:0] 	   dummy;
   assign dummy = exec_rd_m0_value;

   wire [31:0] 	   sgpr_source2_data_i;
   reg [31:0] 	   exec_rd_m0_value_i;
   reg [63:0] 	   exec_exec_value_i;
   wire [127:0] 	   sgpr_source1_data_i;
   wire [2047:0]    vgpr_source2_data_i;
   ///////////////////////////////////////////////CHANGE
   wire [2047:0]    vgpr_source1_data_i;

   //////////////////////////////////////////////CHANGE
   // create a ff for holding the issue_stall signal
   reg freez;
   wire set_freez, clr_freez;
   always @ (posedge clk, posedge rst) begin
     if(rst) begin
       freez <= 0;
     end
     else if(set_freez) begin
       freez <= 1;
     end
     else if(clr_freez) begin
       freez <= 0;
     end
   end
   assign issue_ready = ~freez;


   // Keep single cycle delay on exec signals
   always @ ( posedge clk or posedge rst ) begin
      if(rst) begin
	 exec_rd_m0_value_i <= 0;
	 //sgpr_source2_data_i <= 0;
	 exec_exec_value_i <= 0;
	 //sgpr_source1_data_i <= 0;
	 //vgpr_source2_data_i <= 0;
	 //vgpr_source1_data_i <= 0;
      end
      else begin
	 exec_rd_m0_value_i <= exec_rd_m0_value;
	 //sgpr_source2_data_i <= sgpr_source2_data;
	 exec_exec_value_i <= exec_exec_value;
	 //sgpr_source1_data_i <= sgpr_source1_data;
	 //vgpr_source2_data_i <= vgpr_source2_data;
	 //vgpr_source1_data_i <= vgpr_source1_data;
      end
   end
   assign sgpr_source2_data_i = sgpr_source2_data;
   assign sgpr_source1_data_i = sgpr_source1_data;
   assign vgpr_source2_data_i = vgpr_source2_data;
   assign vgpr_source1_data_i = vgpr_source1_data;
   
   
   //flops_issue_lsu
   wire router_lsu_select;
   wire [5:0] rd_wfid;
   wire [15:0] rd_lds_base;
   wire [11:0] router_source_reg1;
   wire [11:0] router_source_reg2;
   wire [11:0] router_source_reg3;
   wire [11:0] router_mem_sgpr;
   wire [15:0] rd_imm_value0;
   wire [31:0] rd_imm_value1;
   wire [11:0] router_dest_reg;
   wire [31:0] rd_opcode;
   wire [31:0] rd_instr_pc;
   wire load_src_a, shift_src_a;

   assign exec_rd_wfid = issue_wfid;

//////////////CHANGE
   // added write enable controlled by freez signal
   // in order to prevent undesired write to the reg pipeline (front end)
   PS_flops_issue_lsu flops_issue_lsu(
                                      .in_lsu_select(issue_lsu_select),
                                      .in_wfid(issue_wfid),
                                      .in_lds_base(issue_lds_base),
                                      .in_source_reg1(issue_source_reg1),
                                      .in_source_reg2(issue_source_reg2),
                                      .in_source_reg3(issue_source_reg3),
                                      .in_mem_sgpr(issue_mem_sgpr),
                                      .in_imm_value0(issue_imm_value0),
                                      .in_imm_value1(issue_imm_value1),
                                      .in_dest_reg(issue_dest_reg),
                                      .in_opcode(issue_opcode),
                                      .in_instr_pc(issue_instr_pc),
                                      .out_lsu_select(router_lsu_select),
                                      .out_wfid(rd_wfid),
                                      .out_lds_base(rd_lds_base),
                                      .out_source_reg1(router_source_reg1),
                                      .out_source_reg2(router_source_reg2),
                                      .out_source_reg3(router_source_reg3),
                                      .out_mem_sgpr(router_mem_sgpr),
                                      .out_imm_value0(rd_imm_value0),
                                      .out_imm_value1(rd_imm_value1),
                                      .out_dest_reg(router_dest_reg),
                                      .out_opcode(rd_opcode),
                                      .out_instr_pc(rd_instr_pc),
                                      .clk(clk),
                                      .rst(rst),
                                      .freez(freez)
                                      );

////////////////////////////////////////////////////CHANGE
//////////Will the read conflict with simd/f?
   //lsu_rd_stage_router
   wire [2047:0] rd_vector_source_a;
   wire [2047:0] rd_vector_source_b;
   wire [127:0]  rd_scalar_source_a;
   wire [31:0] 	 rd_scalar_source_b;
   wire [3:0] 	 rd_rd_en;
   wire [3:0] 	 rd_wr_en;
   wire [11:0] 	 rd_lddst_stsrc_addr;
   wire [1:0] addr_incre_amt;

   lsu_rd_stage_router lsu_rd_stage_router
     (
      .in_lsu_select(issue_lsu_select),
      .in_source_reg1(issue_source_reg1),
      .in_source_reg2(issue_source_reg2),
      .in_source_reg3(issue_source_reg3),
      .in_mem_sgpr(issue_mem_sgpr),
      .in_lsu_select_flopped(router_lsu_select),
      .in_source_reg2_flopped(router_source_reg2),
      .in_dest_reg(router_dest_reg),
      .in_opcode(issue_opcode),
      .in_opcode_flopped(rd_opcode),
      .in_imm_value0(rd_imm_value0),
      .in_imm_value1(rd_imm_value1),
      .in_vgpr_source1_data(vgpr_source1_data_i),
      .in_vgpr_source2_data(vgpr_source2_data_i),
      .in_sgpr_source1_data(sgpr_source1_data_i),
      .in_sgpr_source2_data(sgpr_source2_data_i),
      .out_vgpr_source1_rd_en(vgpr_source1_rd_en),
      .out_vgpr_source2_rd_en(vgpr_source2_rd_en),
      .out_sgpr_source1_rd_en(sgpr_source1_rd_en),
      .out_sgpr_source2_rd_en(sgpr_source2_rd_en),
      .out_vgpr_source1_addr(vgpr_source1_addr),
      .out_vgpr_source2_addr(vgpr_source2_addr),
      .out_sgpr_source1_addr(sgpr_source1_addr),
      .out_sgpr_source2_addr(sgpr_source2_addr),
      .out_vector_source_a(rd_vector_source_a),
      .out_vector_source_b(rd_vector_source_b),
      .out_scalar_source_a(rd_scalar_source_a),
      .out_scalar_source_b(rd_scalar_source_b),
      .out_rd_en(rd_rd_en),
      .out_wr_en(rd_wr_en),
      .out_lddst_stsrc_addr(rd_lddst_stsrc_addr),
      .addr_incre_amt(addr_incre_amt)
      );

   //flops_rd_ex
   wire [31:0] ex_wr_data;
   wire [2047:0] addr_calc_vector_source_b;
   wire [127:0]  addr_calc_scalar_source_a;
   wire [31:0] 	 addr_calc_scalar_source_b;
   wire [15:0] 	 addr_calc_imm_value0;
   wire [31:0] 	 addr_calc_opcode;
   wire [11:0] 	 transit_lddst_stsrc_addr;
   wire [3:0] 	 ex_rd_en;
   wire [3:0] 	 ex_wr_en;
   wire [5:0] 	 ex_wfid;
   wire [31:0] 	 transit_instr_pc;
   wire [15:0] 	 addr_calc_lds_base;
   wire [63:0] 	 addr_calc_exec_value;

   PS_flops_rd_ex_lsu flops_rd_ex(
				  .in_vector_source_a(rd_vector_source_a),
				  .in_vector_source_b(rd_vector_source_b),
				  .in_scalar_source_a(rd_scalar_source_a),
				  .in_scalar_source_b(rd_scalar_source_b),
				  .in_imm_value0(rd_imm_value0),
				  .in_opcode(rd_opcode),
				  .in_lddst_stsrc_addr(rd_lddst_stsrc_addr),
				  .in_rd_en(rd_rd_en),
				  .in_wr_en(rd_wr_en),
				  .in_wfid(rd_wfid),
				  .in_instr_pc(rd_instr_pc),
				  .in_lds_base(rd_lds_base),
				  .in_exec_value(exec_exec_value_i),
				  .out_vector_source_a(ex_wr_data),
				  .out_vector_source_b(addr_calc_vector_source_b),
				  .out_scalar_source_a(addr_calc_scalar_source_a),
				  .out_scalar_source_b(addr_calc_scalar_source_b),
				  .out_imm_value0(addr_calc_imm_value0),
				  .out_opcode(addr_calc_opcode),
				  .out_lddst_stsrc_addr(transit_lddst_stsrc_addr),
				  .out_rd_en(ex_rd_en),
				  .out_wr_en(ex_wr_en),
				  .out_wfid(ex_wfid),
				  .out_instr_pc(transit_instr_pc),
				  .out_lds_base(addr_calc_lds_base),
				  .out_exec_value(addr_calc_exec_value),
				  .clk(clk),
				  .rst(rst),
          .load_src_a(load_src_a),
          .shift_src_a(shift_src_a)
				  );
   //addr_calc
   wire [2047:0] ex_ld_st_addr;
   wire [63:0] 	 ex_exec_value;
   wire 	 ex_gm_or_lds;

   lsu_addr_calculator addr_calc(
				 .in_vector_source_b(addr_calc_vector_source_b),
				 .in_scalar_source_a(addr_calc_scalar_source_a),
				 .in_scalar_source_b(addr_calc_scalar_source_b),
				 .in_opcode(addr_calc_opcode),
				 .in_lds_base(addr_calc_lds_base),
				 .in_imm_value0(addr_calc_imm_value0),
				 .in_exec_value(addr_calc_exec_value),
				 .out_exec_value(ex_exec_value),
				 .out_ld_st_addr(ex_ld_st_addr),
				 .out_gm_or_lds(ex_gm_or_lds)
				 );

   wire [31:0] ctrl_addr;
   wire ctrl_wr_en,ctrl_rd_en, wb_ack, shift_wb, load_wb;
   rw_controller mem_ctrl(
        .rd_en_in(rd_rd_en), 
        .wrt_en_in(rd_wr_en), 
        .exec_mask_in(ex_exec_value), 
        .addr_in(ex_ld_st_addr), 
        .addr_out(ctrl_addr), 
        .wrt_en(ctrl_wr_en), 
        .rd_en(ctrl_rd_en), 
        .clk(clk), 
        .rst(rst), 
        .shift(shift_src_a), 
        .increAddr(addr_incre_amt), 
        .mem_ack(wb_ack), 
        .lsu_stall(lsu_stall),
        .lsu_rdy(), 
        .lsu_select(issue_lsu_select),
        .load_src_a(load_src_a),
        .set_freez(set_freez),
        .clr_freez(clr_freez),
        .wb_en(wb_en),
        .shift_wb(shift_wb),
        .load_wb(load_wb)
      );

// rw_controller(rd_en_in, wrt_en_in, exec_mask_in, addr_in, addr_out, 
//   wrt_en, rd_en, clk, rst, shift, increAddr, mem_ack, lsu_stall, 
//   lsu_rdy, lsu_select, load_src_a, set_freez, clr_freez, wb_en,
//   load_wb, shift_wb);

   //flops_ex_mem
   wire 	 ex_ld1_st0;
   assign ex_ld1_st0 = (|ex_rd_en) ? 1'b1 : ((|ex_wr_en) ? 1'b0 : 1'bx);

   PS_flops_ex_mem_lsu flops_ex_mem(
				    .in_mem_wr_data(ex_wr_data),
				    .in_rd_en(ctrl_rd_en),
				    .in_wr_en(ctrl_wr_en),
				    .in_ld_st_addr(ctrl_addr),
				    .in_mem_tag({ex_wfid, ex_ld1_st0}),
				    .in_exec_value(ex_exec_value),
				    .in_gm_or_lds(ex_gm_or_lds),
				    .out_mem_wr_data(mem_wr_data),
				    .out_rd_en(mem_rd_en),
				    .out_wr_en(mem_wr_en),
				    .out_ld_st_addr(mem_addr),
				    .out_mem_tag(mem_tag_req),
				    .out_exec_value(mem_wr_mask),
				    .out_gm_or_lds(mem_gm_or_lds),
				    .clk(clk),
				    .rst(rst)
				    );
   //flops_mem_wb
   wire [2047:0] wb_rd_data;
   wire [6:0] 	 wb_wftag_resp;
   //wire 	 wb_ack;

   PS_flops_mem_wb_lsu flops_mem_wb(
                                    .in_rd_data(mem_rd_data),
                                    .in_ack(mem_ack),
                                    .in_tag(mem_tag_resp),
                                    .out_rd_data(wb_rd_data),
                                    .out_ack(wb_ack),
                                    .out_tag(wb_wftag_resp),
                                    .clk(clk),
                                    .rst(rst),
                                    .shift_wb(shift_wb),
                                    .load_wb(load_wb)
                                    );

   // lsu_in_flight_counter lsu_in_flight_counter (
			// 			.in_rd_en(mem_rd_en),
			// 			.in_wr_en(mem_wr_en),
			// 			.in_mem_ack(wb_ack),
			// 			.out_lsu_ready(issue_ready),
			// 			.clk(clk),
			// 			.rst(rst)
			// 			);

   //transit_table
   wire [63:0] 	 wb_exec_value;
   wire 	 wb_gm_or_lds;
   wire [11:0] 	 wb_lddst_stsrc_addr;
   wire [3:0] 	 wb_reg_wr_en;
   wire [31:0] 	 wb_instr_pc;


///////////////////////////////////////////CHANGE
///////////////////////////////////////////WR_EN
   lsu_transit_table transit_table(
    // change: only read entry 0
				   .in_wftag_resp(0),
    // change: only write entry 0
				   .in_wfid(0),
				   .in_lddst_stsrc_addr(transit_lddst_stsrc_addr),
				   .in_exec_value(ex_exec_value),
				   .in_gm_or_lds(ex_gm_or_lds),
				   .in_rd_en(ex_rd_en),
				   .in_wr_en(ex_wr_en),
				   .in_instr_pc(transit_instr_pc),
				   .out_exec_value(wb_exec_value),
				   .out_gm_or_lds(wb_gm_or_lds),
				   .out_lddst_stsrc_addr(wb_lddst_stsrc_addr),
				   .out_reg_wr_en(wb_reg_wr_en),
				   .out_instr_pc(wb_instr_pc),
				   .clk(clk),
				   .rst(rst)
				   );

   lsu_wb_router wb_router(
                           .in_rd_data(wb_rd_data),
                           .in_ack(wb_ack),
                           .in_wftag_resp(wb_wftag_resp),
                           .in_exec_value(wb_exec_value),
                           .in_lddst_stsrc_addr(wb_lddst_stsrc_addr),
                           .in_reg_wr_en(wb_reg_wr_en),
                           .in_instr_pc(wb_instr_pc),
                           .in_gm_or_lds(wb_gm_or_lds),
                           .out_sgpr_dest_addr(sgpr_dest_addr),
                           .out_sgpr_dest_data(sgpr_dest_data),
                           .out_sgpr_dest_wr_en(sgpr_dest_wr_en),
                           .out_sgpr_instr_done(sgpr_instr_done),
                           .out_sgpr_instr_done_wfid(sgpr_instr_done_wfid),
                           .out_vgpr_dest_addr(vgpr_dest_addr),
                           .out_vgpr_dest_data(vgpr_dest_data),
                           .out_vgpr_dest_wr_en(vgpr_dest_wr_en),
                           .out_vgpr_dest_wr_mask(vgpr_dest_wr_mask),
                           .out_vgpr_instr_done(vgpr_instr_done),
                           .out_vgpr_instr_done_wfid(vgpr_instr_done_wfid),
                           .out_tracemon_retire_pc(tracemon_retire_pc),
                           .out_gm_or_lds(tracemon_gm_or_lds),
			                     .out_rfa_dest_wr_req(rfa_dest_wr_req),
                           .wb_en(wb_en)
                           // .wb_ack(wb_ack),
                           // .increAddr(addr_incre_amt),
                           // .clk(clk),
                           // .rst(rst),
                           // .wb_en(wb_en)
                           );
// module lsu_wb_router 
// (/*AUTOARG*/
//    // Outputs
//    out_sgpr_dest_addr, out_sgpr_dest_data, out_sgpr_dest_wr_en,
//    out_sgpr_instr_done, out_sgpr_instr_done_wfid, out_vgpr_dest_addr,
//    out_vgpr_dest_data, out_vgpr_dest_wr_en, out_vgpr_dest_wr_mask,
//    out_vgpr_instr_done, out_vgpr_instr_done_wfid,
//    out_tracemon_retire_pc, out_gm_or_lds, out_rfa_dest_wr_req, wb_en
//    // Inputs
//    in_rd_data, in_wftag_resp, in_ack, in_exec_value,
//    in_lddst_stsrc_addr, in_reg_wr_en, in_instr_pc, in_gm_or_lds
//    );

endmodule
