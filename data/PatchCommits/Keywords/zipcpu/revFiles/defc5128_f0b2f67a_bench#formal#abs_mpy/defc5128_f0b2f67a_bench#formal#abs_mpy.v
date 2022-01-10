////////////////////////////////////////////////////////////////////////////////
//
// Filename:	abs_mpy.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	This code has been modified from the mpyop.v file so as to
//		abstract the multiply that formal methods struggle so hard to
//	deal with.  It also simplifies the interface so that (if enabled)
//	the multiply will return in 1-6 clocks, rather than the specified
//	number for the given architecture.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2018, Gisselquist Technology, LLC
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
`default_nettype	none
//
module	abs_mpy(i_clk,i_reset, i_stb, i_op, i_a, i_b, o_valid, o_busy, o_result, o_hi);
	// The following parameter selects which multiply algorithm we use.
	// Timing performance is strictly dependent upon it.
	parameter	IMPLEMENT_MPY = 1;
	input	wire		i_clk, i_reset, i_stb;
	input	wire	[1:0]	i_op; // 2'b00=MPY, 2'b10=MPYUHI, 2'b11=MPYSHI
	input	wire	[31:0]	i_a, i_b;
	output	wire		o_valid; // True if we'll be valid on the next clock;
	output	wire		o_busy; // The multiply is busy if true
	output	wire	[63:0]	o_result; // Where we dump the multiply result
	output	reg		o_hi;	// Return the high half of the multiply

// i_stb instead of this_is_a_multiply_op
// o_result
// o_busy
// o_done
	generate
	if (IMPLEMENT_MPY == 0)
	begin // No multiply support.

		assign	o_result   = 64'h00;
		assign	o_busy     = 1'b0;
		assign	o_valid    = 1'b1;
		always @(*) o_hi = 1'b0; // Not needed

	end else //
	begin // Our single clock option (no extra clocks)

		wire	[2:0]	next_delay_to_valid;

		assign	next_delay_to_valid = $anyseq;
		assign	o_result = $anyseq;

		reg	[2:0]	delay_to_valid;
		reg		r_busy;

		initial	delay_to_valid = 3'h0;
		always @(posedge i_clk)
		if (i_reset)
			delay_to_valid <= 0;
		else if ((i_stb)&&(next_delay_to_valid != 0))
			delay_to_valid <= next_delay_to_valid;
		else if (delay_to_valid > 0)
			delay_to_valid <= delay_to_valid - 1'b1;

		initial	r_busy = 1'b0;
		always @(posedge i_clk)
		if (i_reset)
			r_busy <= 1'b0;
		else if (i_stb)
			r_busy <= (next_delay_to_valid != 0);
		else if (r_busy)
			r_busy <= (delay_to_valid != 3'h1);

		always @(posedge i_clk)
		if (i_reset)
			o_valid <= 1'b0;
		else if ((i_stb)&&(next_delay_to_valid == 0))
			o_valid <= 1'b1;
		else
			o_valid <= (o_busy)&&(delay_to_valid == 3'h1);

		always @(posedge i_clk)
		if (i_stb)
			o_hi <= i_op[1];

		assign	o_busy = r_busy;
	end
	endgenerate // All possible multiply results have been determined

endmodule
