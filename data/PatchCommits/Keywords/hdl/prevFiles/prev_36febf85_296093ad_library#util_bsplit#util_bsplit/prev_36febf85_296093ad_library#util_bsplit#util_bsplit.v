// ***************************************************************************
// ***************************************************************************
// Copyright 2011(c) Analog Devices, Inc.
// 
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//     - Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     - Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in
//       the documentation and/or other materials provided with the
//       distribution.
//     - Neither the name of Analog Devices, Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//     - The use of this software may or may not infringe the patent rights
//       of one or more patent holders.  This license does not release you
//       from the requirement that you obtain separate licenses from these
//       patent holders to use this software.
//     - Use of the software either in source or binary form, must be run
//       on or directly connected to an Analog Devices Inc. component.
//    
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED.
//
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, INTELLECTUAL PROPERTY
// RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ***************************************************************************
// ***************************************************************************
// too bad- we have to do this!

`timescale 1ns/100ps

module util_bsplit (

  data,

  split_data_0,
  split_data_1,
  split_data_2,
  split_data_3,
  split_data_4,
  split_data_5,
  split_data_6,
  split_data_7);

  // parameters

  parameter   CH_DW     = 1;
  parameter   CH_CNT    = 8;
  localparam  CH_MCNT   = 9;

  // interface

  input   [((CH_CNT*CH_DW)-1):0]    data;
  output  [(CH_DW-1):0]             split_data_0;
  output  [(CH_DW-1):0]             split_data_1;
  output  [(CH_DW-1):0]             split_data_2;
  output  [(CH_DW-1):0]             split_data_3;
  output  [(CH_DW-1):0]             split_data_4;
  output  [(CH_DW-1):0]             split_data_5;
  output  [(CH_DW-1):0]             split_data_6;
  output  [(CH_DW-1):0]             split_data_7;

  // internal signals

  wire    [((CH_MCNT*CH_DW)-1):0]   data_s;

  // extend and split
  
  assign data_s[((CH_MCNT*CH_DW)-1):(CH_CNT*CH_DW)] = 'd0;
  assign data_s[((CH_CNT*CH_DW)-1):0] = data;

  assign split_data_0 = data_s[((CH_DW*1)-1):(CH_DW*0)];
  assign split_data_1 = data_s[((CH_DW*2)-1):(CH_DW*1)];
  assign split_data_2 = data_s[((CH_DW*3)-1):(CH_DW*2)];
  assign split_data_3 = data_s[((CH_DW*4)-1):(CH_DW*3)];
  assign split_data_4 = data_s[((CH_DW*5)-1):(CH_DW*4)];
  assign split_data_5 = data_s[((CH_DW*6)-1):(CH_DW*5)];
  assign split_data_6 = data_s[((CH_DW*7)-1):(CH_DW*6)];
  assign split_data_7 = data_s[((CH_DW*8)-1):(CH_DW*7)];

endmodule

// ***************************************************************************
// ***************************************************************************
