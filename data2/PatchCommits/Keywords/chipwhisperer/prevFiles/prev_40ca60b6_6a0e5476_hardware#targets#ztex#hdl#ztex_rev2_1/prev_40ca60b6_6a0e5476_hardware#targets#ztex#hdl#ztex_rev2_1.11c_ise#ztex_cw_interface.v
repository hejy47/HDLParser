`include "includes.v"
//`define CHIPSCOPE
/***********************************************************************
This file is part of the OpenADC Project. See www.newae.com for more details,
or the codebase at http://www.assembla.com/spaces/openadc .

This file is the example using the LX9 Board in USB (Serial) Mode.

Copyright (c) 2013, Colin O'Flynn <coflynn@newae.com>. All rights reserved.
This project (and file) is released under the 2-Clause BSD License:

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:

   * Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above copyright
	  notice, this list of conditions and the following disclaimer in the
	  documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
*************************************************************************/

module interface(
    input         reset_i,    
    input         ifclk,
       
	 output			sloe,
	 output			slrd,
	 output			slwr,
	 output			fifoadr0,
	 output			fifoadr1,
	 output			pktend,
	 input			flaga,
	 input			flagb,
	 inout [7:0]   fd,
		 
    output        GPIO_LED1,
    output        GPIO_LED2,
    output        GPIO_LED3,
    output        GPIO_LED4,
	 output			GPIO_LED5,
	 output			GPIO_LED6,
	  
	 input [9:0]   ADC_Data,
	 input         ADC_OR,
	 output        ADC_clk,
	 input         DUT_CLK_i,
	 input         DUT_trigger_i,
	 output        amp_gain,
	 output        amp_hilo,
	 
	 inout 			target_io4, // Normally trigger
	 inout			target_io3, // Normally Spare/Extra comms
	 inout			target_io2, // Normally RXD
	 inout			target_io1, // Normally TXD
	 inout			target_hs1, // Clock from victim device
	 output			target_hs1_dir, //HIGH = Output
	 inout			target_hs2, // Clock to victim device
	 output			target_hs2_dir //HIGH = Output
	 
`ifdef OPT_DDR
 /* To avoid modifying UCF file we keep these even in FIFO mode */
	 ,output [12:0] LPDDR_A,
	 output [1:0]  LPDDR_BA,
	 inout  [15:0] LPDDR_DQ,
	 output        LPDDR_LDM,
	 output        LPDDR_UDM,
	 inout			LPDDR_LDQS,
	 inout			LPDDR_UDQS,
	 output			LPDDR_CK_N,
	 output			LPDDR_CK_P,
	 output			LPDDR_CKE,
	 output			LPDDR_CAS_n,
	 output			LPDDR_RAS_n,
	 output			LPDDR_WE_n,
	 output			LPDDR_RZQ
`endif
    );
	 
	 assign target_hs1_dir = 1'b0;
	 assign target_hs2_dir = 1'b1;
	 assign target_hs1 = 1'bZ;
	 
	 //TODO: FIX THESE IF NEEDED
	 assign target_hs2 = 1'b0;
	 assign target_io2 = 1'bZ;
	 //assign target_io1 = 1'bZ;
	 assign target_io3 = 1'bZ;
	 assign target_io4 = 1'bZ;
	 
	 /* Notes on the FX2 Interface:
	   EP2 is IN (input from FPGA to computer)
		EP6 is OUT (output from computer to FPGA)
		FLAGA = EP2 FULL (aka stop writing)
		FLAGB = EP6 EMPTY (aka stop reading)
		
		All signals have active-low polarity
	 */
	
	wire sloe_int;
	wire ifclk_buf;
	wire ADC_clk_int;
	assign ADC_clk = ADC_clk_int;
	assign GPIO_LED1 = ~reset_i;	
	reg sloe_int_last;	
	assign pktend = ~(sloe_int_last & ~sloe_int);	
	always @(posedge ifclk_buf) begin
		sloe_int_last <= sloe_int;
	end
	
	assign sloe = sloe_int;
	
	assign GPIO_LED5 = 1'b1;
	assign GPIO_LED6 = 1'b1;
	
	assign fifoadr0 = 1'b0;
		
	/*
	EP2: ADR1=0
	EP6: ADR1=1
	When SLOE_INT is low we are reading (e.g. from EP6). When it goes
	high we are going to write to EP2.
	*/
	reg fifoadr1_reg;
	always @(posedge ifclk_buf) begin
		fifoadr1_reg <= ~sloe_int;
	end
	assign fifoadr1 = fifoadr1_reg;	
	
	IBUFG IBUFG_inst (
	.O(ifclk_buf),
	.I(ifclk) );

	wire reg_rst;
	wire [5:0] reg_addr;
	wire [15:0] reg_bcnt;
	wire [7:0] reg_datao;
	wire [7:0] reg_datai;
	wire [15:0] reg_size;
	wire reg_read;
	wire reg_write;
	wire reg_addrvalid;
	wire reg_stream;
	wire [5:0] reg_hypaddr;
	wire [15:0] reg_hyplen;

	openadc_interface oadc(
		.reset_i(reset_i),
		.clk_adcint(ifclk_buf),
		.clk_iface(ifclk_buf),
		.LED_hbeat(GPIO_LED2),
		.LED_armed(GPIO_LED3),
		.LED_capture(GPIO_LED4),
		.ADC_Data(ADC_Data),
		.ADC_OR(ADC_OR),
		.ADC_clk(ADC_clk_int),
		.ADC_clk_feedback(ADC_clk_int),
		//.DUT_CLK_i(DUT_CLK_i),
		.DUT_CLK_i(target_hs1),
		.DUT_trigger_i(DUT_trigger_i),
		.amp_gain(amp_gain),
		.amp_hilo(amp_hilo),
				
		.ftdi_data(fd),
		.ftdi_rxfn(~flagb),
		.ftdi_txen(~flaga),
		.ftdi_rdn(slrd),
		.ftdi_wrn(slwr),
		.ftdi_oen(sloe_int),	
		.ftdi_siwua(),
		
		.reg_reset_o(reg_rst),
		.reg_address_o(reg_addr),
		.reg_bytecnt_o(reg_bcnt),
		.reg_datao_o(reg_datao),
		.reg_datai_i(reg_datai),
		.reg_size_o(reg_size),
		.reg_read_o(reg_read),
		.reg_write_o(reg_write),
		.reg_addrvalid_o(reg_addrvalid),
		.reg_stream_i(reg_stream),
		.reg_hypaddress_o(reg_hypaddr),
		.reg_hyplen_i(reg_hyplen) 
	/*
		,.LPDDR_A(LPDDR_A),
		.LPDDR_BA(LPDDR_BA),
		.LPDDR_DQ(LPDDR_DQ),
		.LPDDR_LDM(LPDDR_LDM),
		.LPDDR_UDM(LPDDR_UDM),
		.LPDDR_LDQS(LPDDR_LDQS),
		.LPDDR_UDQS(LPDDR_UDQS),
		.LPDDR_CK_N(LPDDR_CK_N),
		.LPDDR_CK_P(LPDDR_CK_P),
		.LPDDR_CKE(LPDDR_CKE),
		.LPDDR_CAS_n(LPDDR_CAS_n),
		.LPDDR_RAS_n(LPDDR_RAS_n),
		.LPDDR_WE_n(LPDDR_WE_n),
		.LPDDR_RZQ(LPDDR_RZQ)	
	*/
	);
	
	reg_serialtarget registers_serialtarget(
		.reset_i(reg_rst),
		.clk(ifclk_buf),
		.reg_address(reg_addr), 
		.reg_bytecnt(reg_bcnt), 
		.reg_datao(reg_datai), 
		.reg_datai(reg_datao), 
		.reg_size(reg_size), 
		.reg_read(reg_read), 
		.reg_write(reg_write), 
		.reg_addrvalid(reg_addrvalid), 
		.reg_stream(reg_stream),
		.reg_hypaddress(reg_hypaddr), 
		.reg_hyplen(reg_hyplen),
		.target_tx(target_io1),
		.target_rx(target_io2)					              
   );
	
	`ifdef CHIPSCOPE
   wire [127:0] cs_data;   
   wire [35:0]  chipscope_control;
   	
	coregen_icon icon (
    .CONTROL0(chipscope_control) // INOUT BUS [35:0]
   ); 

   coregen_ila ila (
    .CONTROL(chipscope_control), // INOUT BUS [35:0]
    .CLK(ifclk_buf), // IN
    .TRIG0(cs_data) // IN BUS [127:0]
   );
	
  assign cs_data[7:0] = fd;
  assign cs_data[8] = sloe;
  assign cs_data[9] = slrd;
  assign cs_data[10] = slwr;
  assign cs_data[11] = fifoadr0;
  assign cs_data[12] = fifoadr1;
  assign cs_data[13] = pktend;
  assign cs_data[14] = flaga;
  assign cs_data[15] = flagb; 
  `endif
	
endmodule
