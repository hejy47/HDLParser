// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// SECDED Decoder generated by
// util/design/secded_gen.py -m 8 -k 64 -s 1218923287 -c hamming

module prim_secded_hamming_72_64_dec (
  input        [71:0] in,
  output logic [63:0] d_o,
  output logic [7:0] syndrome_o,
  output logic [1:0] err_o
);


  // Syndrome calculation
  assign syndrome_o[0] = ^(in & 72'h01AB55555556AAAD5B);
  assign syndrome_o[1] = ^(in & 72'h02CD9999999B33366D);
  assign syndrome_o[2] = ^(in & 72'h04F1E1E1E1E3C3C78E);
  assign syndrome_o[3] = ^(in & 72'h0801FE01FE03FC07F0);
  assign syndrome_o[4] = ^(in & 72'h1001FFFE0003FFF800);
  assign syndrome_o[5] = ^(in & 72'h2001FFFFFFFC000000);
  assign syndrome_o[6] = ^(in & 72'h40FE00000000000000);
  assign syndrome_o[7] = ^(in & 72'hFFFFFFFFFFFFFFFFFF);

  // Corrected output calculation
  assign d_o[0] = (syndrome_o == 8'h83) ^ in[0];
  assign d_o[1] = (syndrome_o == 8'h85) ^ in[1];
  assign d_o[2] = (syndrome_o == 8'h86) ^ in[2];
  assign d_o[3] = (syndrome_o == 8'h87) ^ in[3];
  assign d_o[4] = (syndrome_o == 8'h89) ^ in[4];
  assign d_o[5] = (syndrome_o == 8'h8a) ^ in[5];
  assign d_o[6] = (syndrome_o == 8'h8b) ^ in[6];
  assign d_o[7] = (syndrome_o == 8'h8c) ^ in[7];
  assign d_o[8] = (syndrome_o == 8'h8d) ^ in[8];
  assign d_o[9] = (syndrome_o == 8'h8e) ^ in[9];
  assign d_o[10] = (syndrome_o == 8'h8f) ^ in[10];
  assign d_o[11] = (syndrome_o == 8'h91) ^ in[11];
  assign d_o[12] = (syndrome_o == 8'h92) ^ in[12];
  assign d_o[13] = (syndrome_o == 8'h93) ^ in[13];
  assign d_o[14] = (syndrome_o == 8'h94) ^ in[14];
  assign d_o[15] = (syndrome_o == 8'h95) ^ in[15];
  assign d_o[16] = (syndrome_o == 8'h96) ^ in[16];
  assign d_o[17] = (syndrome_o == 8'h97) ^ in[17];
  assign d_o[18] = (syndrome_o == 8'h98) ^ in[18];
  assign d_o[19] = (syndrome_o == 8'h99) ^ in[19];
  assign d_o[20] = (syndrome_o == 8'h9a) ^ in[20];
  assign d_o[21] = (syndrome_o == 8'h9b) ^ in[21];
  assign d_o[22] = (syndrome_o == 8'h9c) ^ in[22];
  assign d_o[23] = (syndrome_o == 8'h9d) ^ in[23];
  assign d_o[24] = (syndrome_o == 8'h9e) ^ in[24];
  assign d_o[25] = (syndrome_o == 8'h9f) ^ in[25];
  assign d_o[26] = (syndrome_o == 8'ha1) ^ in[26];
  assign d_o[27] = (syndrome_o == 8'ha2) ^ in[27];
  assign d_o[28] = (syndrome_o == 8'ha3) ^ in[28];
  assign d_o[29] = (syndrome_o == 8'ha4) ^ in[29];
  assign d_o[30] = (syndrome_o == 8'ha5) ^ in[30];
  assign d_o[31] = (syndrome_o == 8'ha6) ^ in[31];
  assign d_o[32] = (syndrome_o == 8'ha7) ^ in[32];
  assign d_o[33] = (syndrome_o == 8'ha8) ^ in[33];
  assign d_o[34] = (syndrome_o == 8'ha9) ^ in[34];
  assign d_o[35] = (syndrome_o == 8'haa) ^ in[35];
  assign d_o[36] = (syndrome_o == 8'hab) ^ in[36];
  assign d_o[37] = (syndrome_o == 8'hac) ^ in[37];
  assign d_o[38] = (syndrome_o == 8'had) ^ in[38];
  assign d_o[39] = (syndrome_o == 8'hae) ^ in[39];
  assign d_o[40] = (syndrome_o == 8'haf) ^ in[40];
  assign d_o[41] = (syndrome_o == 8'hb0) ^ in[41];
  assign d_o[42] = (syndrome_o == 8'hb1) ^ in[42];
  assign d_o[43] = (syndrome_o == 8'hb2) ^ in[43];
  assign d_o[44] = (syndrome_o == 8'hb3) ^ in[44];
  assign d_o[45] = (syndrome_o == 8'hb4) ^ in[45];
  assign d_o[46] = (syndrome_o == 8'hb5) ^ in[46];
  assign d_o[47] = (syndrome_o == 8'hb6) ^ in[47];
  assign d_o[48] = (syndrome_o == 8'hb7) ^ in[48];
  assign d_o[49] = (syndrome_o == 8'hb8) ^ in[49];
  assign d_o[50] = (syndrome_o == 8'hb9) ^ in[50];
  assign d_o[51] = (syndrome_o == 8'hba) ^ in[51];
  assign d_o[52] = (syndrome_o == 8'hbb) ^ in[52];
  assign d_o[53] = (syndrome_o == 8'hbc) ^ in[53];
  assign d_o[54] = (syndrome_o == 8'hbd) ^ in[54];
  assign d_o[55] = (syndrome_o == 8'hbe) ^ in[55];
  assign d_o[56] = (syndrome_o == 8'hbf) ^ in[56];
  assign d_o[57] = (syndrome_o == 8'hc1) ^ in[57];
  assign d_o[58] = (syndrome_o == 8'hc2) ^ in[58];
  assign d_o[59] = (syndrome_o == 8'hc3) ^ in[59];
  assign d_o[60] = (syndrome_o == 8'hc4) ^ in[60];
  assign d_o[61] = (syndrome_o == 8'hc5) ^ in[61];
  assign d_o[62] = (syndrome_o == 8'hc6) ^ in[62];
  assign d_o[63] = (syndrome_o == 8'hc7) ^ in[63];

  // err_o calc. bit0: single error, bit1: double error
  assign err_o[0] = syndrome_o[7];
  assign err_o[1] = |syndrome_o[6:0] & ~syndrome_o[7];

endmodule : prim_secded_hamming_72_64_dec
