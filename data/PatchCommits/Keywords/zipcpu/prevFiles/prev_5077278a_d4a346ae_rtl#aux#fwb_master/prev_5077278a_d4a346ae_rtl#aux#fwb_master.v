////////////////////////////////////////////////////////////////////////////////
//
// Filename:	fwb_master.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	This file describes the rules of a wishbone interaction from the
//		perspective of a wishbone master.  These formal rules may be used
//	with yosys-smtbmc to *prove* that the master properly handles outgoing
//	transactions and incoming responses.
//
//	This module contains no functional logic.  It is intended for formal
//	verification only.  The outputs returned, the number of requests that
//	have been made, the number of acknowledgements received, and the number
//	of outstanding requests, are designed for further formal verification
//	purposes *only*.
//
//	This file is different from a companion formal_slave.v file in that the
//	assertions are made on the outputs of the wishbone master: o_wb_cyc,
//	o_wb_stb, o_wb_we, o_wb_addr, o_wb_data, and o_wb_sel, while only
//	assumptions are made about the inputs: i_wb_stall, i_wb_ack, i_wb_data,
//	i_wb_err.  In the formal_slave.v, assumptions are made about the
//	slave inputs (the master outputs), and assertions are made about the
//	slave outputs (the master inputs).
//
//
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype none
//
module	fwb_master(i_clk, i_reset,
		// The Wishbone bus
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data, i_wb_sel,
			i_wb_ack, i_wb_stall, i_wb_idata, i_wb_err,
		// Some convenience output parameters
		f_nreqs, f_nacks, f_outstanding);
	parameter		AW=32, DW=32;
	parameter		F_MAX_STALL = 0,
				F_MAX_ACK_DELAY = 0;
	parameter		F_LGDEPTH = 4;
	parameter [(F_LGDEPTH-1):0] F_MAX_REQUESTS = 0;
	//
	// If true, allow the bus to be kept open when there are no outstanding
	// requests.  This is useful for any master that might execute a
	// read modify write cycle, such as an atomic add.
	parameter [0:0]		F_OPT_RMW_BUS_OPTION = 1;
	//
	// 
	parameter [0:0]		F_OPT_SHORT_CIRCUIT_PROOF = 0;
	//
	// If this is the source of a request, then we can assume STB and CYC
	// will initially start out high.  Master interfaces following the
	// source on the way to the slave may not have this property
	parameter [0:0]		F_OPT_SOURCE = 0;
	//
	// If true, allow the bus to issue multiple discontinuous requests.
	// Unlike F_OPT_RMW_BUS_OPTION, these requests may be issued while other
	// requests are outstanding
	parameter	[0:0]	F_OPT_DISCONTINUOUS = 0;
	//
	//
	localparam [(F_LGDEPTH-1):0] MAX_OUTSTANDING = {(F_LGDEPTH){1'b1}};
	localparam	MAX_DELAY = (F_MAX_STALL > F_MAX_ACK_DELAY)
				? F_MAX_STALL : F_MAX_ACK_DELAY;
	localparam	DLYBITS= (MAX_DELAY < 4) ? 2
				: ((MAX_DELAY <    16) ? 4
				: ((MAX_DELAY <    64) ? 6
				: ((MAX_DELAY <   256) ? 8
				: ((MAX_DELAY <  1024) ? 10
				: ((MAX_DELAY <  4096) ? 12
				: ((MAX_DELAY < 16384) ? 14
				: ((MAX_DELAY < 65536) ? 16
				: 32)))))));
	//
	input	wire			i_clk, i_reset;
	// Input/master bus
	input	wire			i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[(AW-1):0]	i_wb_addr;
	input	wire	[(DW-1):0]	i_wb_data;
	input	wire	[(DW/8-1):0]	i_wb_sel;
	//
	input	wire			i_wb_ack;
	input	wire			i_wb_stall;
	input	wire	[(DW-1):0]	i_wb_idata;
	input	wire			i_wb_err;
	//
	output	reg	[(F_LGDEPTH-1):0]	f_nreqs, f_nacks;
	output	wire	[(F_LGDEPTH-1):0]	f_outstanding;

	//
	// Let's just make sure our parameters are set up right
	//
	assert property(F_MAX_REQUESTS < {(F_LGDEPTH){1'b1}});

	//
	// Wrap the request line in a bundle.  The top bit, named STB_BIT,
	// is the bit indicating whether the request described by this vector
	// is a valid request or not.
	//
	localparam	STB_BIT = 2+AW+DW+DW/8-1;
	wire	[STB_BIT:0]	f_request;
	assign	f_request = { i_wb_stb, i_wb_we, i_wb_addr, i_wb_data, i_wb_sel };

	//
	// A quick register to be used later to know if the $past() operator
	// will yield valid result
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;
	always @(*)
		if (!f_past_valid)
			assume(i_reset);
	//
	//
	// Assertions regarding the initial (and reset) state
	//
	//

	//
	// Assume we start from a reset condition
	initial assert(i_reset);
	initial assert(!i_wb_cyc);
	initial assert(!i_wb_stb);
	//
	initial	assume(!i_wb_ack);
	initial	assume(!i_wb_err);

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(i_reset)))
	begin
		assert(!i_wb_cyc);
		assert(!i_wb_stb);
		//
		assume(!i_wb_ack);
		assume(!i_wb_err);
	end

	// Things can only change on the positive edge of the clock
	always @($global_clock)
	if ((f_past_valid)&&(!$rose(i_clk)))
	begin
		assert($stable(i_reset));
		assert($stable(i_wb_cyc));
		if (i_wb_we)
			assert($stable(f_request)); // The entire request should b stabl
		else
			assert($stable(f_request[(2+AW-1):(DW+DW/8)]));
		//
		assume($stable(i_wb_ack));
		assume($stable(i_wb_stall));
		assume($stable(i_wb_idata));
		assume($stable(i_wb_err));
	end

	//
	//
	// Bus requests
	//
	//

	// Following any bus error, the CYC line should be dropped to abort
	// the transaction
	always @(posedge i_clk)
	if ((f_past_valid)&&($past(i_wb_err))&&($past(i_wb_cyc)))
		assert(!i_wb_cyc);

	// STB can only be true if CYC is also true
	always @(posedge i_clk)
		if (i_wb_stb)
			assert(i_wb_cyc);

	// If a request was both outstanding and stalled on the last clock,
	// then nothing should change on this clock regarding it.
	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset))&&($past(i_wb_stb))
			&&($past(i_wb_stall))&&(i_wb_cyc))
	begin
		assert(i_wb_stb);
		assert($stable(f_request));
	end

	// Within any series of STB/requests, the direction of the request
	// may not change.
	always @(posedge i_clk)
		if ((f_past_valid)&&($past(i_wb_stb))&&(i_wb_stb))
			assert(i_wb_we == $past(i_wb_we));


	// Within any given bus cycle, the direction may *only* change when
	// there are no further outstanding requests.
	always @(posedge i_clk)
		if ((f_past_valid)&&(f_outstanding > 0))
			assert(i_wb_we == $past(i_wb_we));

	// Write requests must also set one (or more) of i_wb_sel
	always @(posedge i_clk)
		if ((i_wb_stb)&&(i_wb_we))
			assert(|i_wb_sel);


	//
	//
	// Bus responses
	//
	//

	// If CYC was low on the last clock, then both ACK and ERR should be
	// low on this clock.
	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_wb_cyc))&&(!i_wb_cyc))
	begin
		assume(!i_wb_ack);
		assume(!i_wb_err);
		// Stall may still be true--such as when we are not
		// selected at some arbiter between us and the slave
	end

	// ACK and ERR may never both be true at the same time
	always @(*)
		assume((!i_wb_ack)||(!i_wb_err));

	generate if (F_MAX_STALL > 0)
	begin : MXSTALL
		//
		// Assume the slave cannnot stall for more than F_MAX_STALL
		// counts.  We'll count this forward any time STB and STALL
		// are both true.
		//
		reg	[(DLYBITS-1):0]		f_stall_count;

		initial	f_stall_count = 0;
		always @(posedge i_clk)
			if ((!i_reset)&&(i_wb_stb)&&(i_wb_stall))
				f_stall_count <= f_stall_count + 1'b1;
			else
				f_stall_count <= 0;
		always @(posedge i_clk)
			if (i_wb_cyc)
				assume(f_stall_count < F_MAX_STALL);
	end endgenerate

	generate if (F_MAX_ACK_DELAY > 0)
	begin : MXWAIT
		//
		// Assume the slave will respond within F_MAX_ACK_DELAY cycles,
		// counted either from the end of the last request, or from the
		// last ACK received
		//
		reg	[(DLYBITS-1):0]		f_ackwait_count;

		initial	f_ackwait_count = 0;
		always @(posedge i_clk)
			if ((!i_reset)&&(i_wb_cyc)&&(!i_wb_stb)
					&&(!i_wb_ack)&&(!i_wb_err))
			begin
				f_ackwait_count <= f_ackwait_count + 1'b1;
				assume(f_ackwait_count < F_MAX_ACK_DELAY);
			end else
				f_ackwait_count <= 0;
	end endgenerate

	//
	// Count the number of requests that have been made
	//
	initial	f_nreqs = 0;
	always @(posedge i_clk)
		if ((i_reset)||(!i_wb_cyc))
			f_nreqs <= 0;
		else if ((i_wb_stb)&&(!i_wb_stall))
			f_nreqs <= f_nreqs + 1'b1;


	//
	// Count the number of acknowledgements that have been received
	//
	initial	f_nacks = 0;
	always @(posedge i_clk)
		if (!i_wb_cyc)
			f_nacks <= 0;
		else if ((i_wb_ack)||(i_wb_err))
			f_nacks <= f_nacks + 1'b1;

	//
	// The number of outstanding requests is the difference between
	// the number of requests and the number of acknowledgements
	//
	assign	f_outstanding = (i_wb_cyc) ? (f_nreqs - f_nacks):0;

	always @(posedge i_clk)
		if ((i_wb_cyc)&&(F_MAX_REQUESTS > 0))
		begin
			if (i_wb_stb)
				assert(f_nreqs < F_MAX_REQUESTS);
			else
				assert(f_nreqs <= F_MAX_REQUESTS);
			assume(f_nacks <= f_nreqs);
			assert(f_outstanding < (1<<F_LGDEPTH)-1);
		end else
			assume(f_outstanding < (1<<F_LGDEPTH)-1);

	always @(posedge i_clk)
		if ((i_wb_cyc)&&(f_outstanding == 0))
		begin
			// If nothing is outstanding, then there should be
			// no acknowledgements ... however, an acknowledgement
			// *can* come back on the same clock as the stb is
			// going out.
			assume((!i_wb_ack)||((i_wb_stb)&&(!i_wb_stall)));
			// The same is true of errors.  They may not be
			// created before the request gets through
			assume((!i_wb_err)||((i_wb_stb)&&(!i_wb_stall)));
		end

	generate if (F_OPT_SOURCE)
	begin : SRC
		// Any opening bus request starts with both CYC and STB high
		// This is true for the master only, and more specifically
		// only for those masters that are the initial source of any
		// transaction.  By the time an interaction gets to the slave,
		// the CYC line may go high or low without actually affecting
		// the STB line of the slave.
		always @(posedge i_clk)
			if ((f_past_valid)&&(!$past(i_wb_cyc))&&(i_wb_cyc))
				assert(i_wb_stb);
	end endgenerate


	generate if (!F_OPT_RMW_BUS_OPTION)
	begin
		// If we aren't waiting for anything, and we aren't issuing
		// any requests, then then our transaction is over and we
		// should be dropping the CYC line.
		always @(posedge i_clk)
			if (f_outstanding == 0)
				assert((i_wb_stb)||(!i_wb_cyc));
		// Not all masters will abide by this restriction.  Some
		// masters may wish to implement read-modify-write bus
		// interactions.  These masters need to keep CYC high between
		// transactions, even though nothing is outstanding.  For
		// these busses, turn F_OPT_RMW_BUS_OPTION on.
	end endgenerate

	generate if (F_OPT_SHORT_CIRCUIT_PROOF)
	begin
		// In many ways, we don't care what happens on the bus return
		// lines if the cycle line is low, so restricting them to a
		// known value makes a lot of sense.
		//
		// On the other hand, if something above *does* depend upon
		// these values (when it shouldn't), then we might want to know
		// about it.
		//
		//
		always @(posedge i_clk)
		begin
			if (!i_wb_cyc)
			begin
				restrict(!i_wb_stall);
				restrict($stable(i_wb_idata));
			end else if ((!$past(i_wb_ack))&&(!i_wb_ack))
				restrict($stable(i_wb_idata));
		end
	end endgenerate

	generate if ((!F_OPT_DISCONTINUOUS)&&(!F_OPT_RMW_BUS_OPTION))
	begin : INSIST_ON_NO_DISCONTINUOUS_STBS
		// Within my own code, once a request begins it goes to
		// completion and the CYC line is dropped.  The master
		// is not allowed to raise STB again after dropping it.
		// Doing so would be a *discontinuous* request.
		//
		// However, in any RMW scheme, discontinuous requests are
		// necessary, and the spec doesn't disallow them.  Hence we
		// make this check optional.
		always @(posedge i_clk)
			if ((f_past_valid)&&($past(i_wb_cyc))&&(!$past(i_wb_stb)))
				assert(!i_wb_stb);
	end endgenerate

endmodule
