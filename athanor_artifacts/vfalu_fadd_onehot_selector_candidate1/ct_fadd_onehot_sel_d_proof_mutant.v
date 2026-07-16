module ct_fadd_onehot_sel_d(
  data_in,
  onehot,
  result
);

input   [53:0]  data_in;
input   [53:0]  onehot;
output  [53:0]  result;

assign result[53:0] =
    {54{1'b0}}
  | ({54{onehot[53]}} & data_in[53:0])
  | ({54{onehot[52]}} & {data_in[52:0], 1'b0})
  | ({54{onehot[51]}} & {data_in[51:0], 2'b0})
  | ({54{onehot[50]}} & {data_in[50:0], 3'b0})
  | ({54{onehot[49]}} & {data_in[49:0], 4'b0})
  | ({54{onehot[48]}} & {data_in[48:0], 5'b0})
  | ({54{onehot[47]}} & {data_in[47:0], 6'b0})
  | ({54{onehot[46]}} & {data_in[46:0], 7'b0})
  | ({54{onehot[45]}} & {data_in[45:0], 8'b0})
  | ({54{onehot[44]}} & {data_in[44:0], 9'b0})
  | ({54{onehot[43]}} & {data_in[43:0], 10'b0})
  | ({54{onehot[42]}} & {data_in[42:0], 11'b0})
  | ({54{onehot[41]}} & {data_in[41:0], 12'b0})
  | ({54{onehot[40]}} & {data_in[40:0], 13'b0})
  | ({54{onehot[39]}} & {data_in[39:0], 14'b0})
  | ({54{onehot[38]}} & {data_in[38:0], 15'b0})
  | ({54{onehot[37]}} & {data_in[37:0], 16'b0})
  | ({54{onehot[36]}} & {data_in[36:0], 17'b0})
  | ({54{onehot[35]}} & {data_in[35:0], 18'b0})
  | ({54{onehot[34]}} & {data_in[34:0], 19'b0})
  | ({54{onehot[33]}} & {data_in[33:0], 20'b0})
  | ({54{onehot[32]}} & {data_in[32:0], 21'b0})
  | ({54{onehot[31]}} & {data_in[31:0], 22'b0})
  | ({54{onehot[30]}} & {data_in[30:0], 23'b0})
  | ({54{onehot[29]}} & {data_in[29:0], 24'b0})
  | ({54{onehot[28]}} & {data_in[28:0], 25'b0})
  | ({54{onehot[27]}} & {data_in[27:0], 26'b0})
  | ({54{onehot[26]}} & {data_in[26:0], 27'b0})
  | ({54{onehot[25]}} & {data_in[25:0], 28'b0})
  | ({54{onehot[24]}} & {data_in[24:0], 29'b0})
  | ({54{onehot[23]}} & {data_in[23:0], 30'b0})
  | ({54{onehot[22]}} & {data_in[22:0], 31'b0})
  | ({54{onehot[21]}} & {data_in[21:0], 32'b0})
  | ({54{onehot[20]}} & {data_in[20:0], 33'b0})
  | ({54{onehot[19]}} & {data_in[19:0], 34'b0})
  | ({54{onehot[18]}} & {data_in[18:0], 35'b0})
  | ({54{onehot[17]}} & {data_in[17:0], 36'b0})
  | ({54{onehot[16]}} & {data_in[16:0], 37'b0})
  | ({54{onehot[15]}} & {data_in[15:0], 38'b0})
  | ({54{onehot[14]}} & {data_in[14:0], 39'b0})
  | ({54{onehot[13]}} & {data_in[13:0], 40'b0})
  | ({54{onehot[12]}} & {data_in[12:0], 41'b0})
  | ({54{onehot[11]}} & {data_in[11:0], 42'b0})
  | ({54{onehot[10]}} & {data_in[10:0], 43'b0})
  | ({54{onehot[9]}} & {data_in[9:0], 44'b0})
  | ({54{onehot[8]}} & {data_in[8:0], 45'b0})
  | ({54{onehot[7]}} & {data_in[7:0], 46'b0})
  | ({54{onehot[6]}} & {data_in[6:0], 47'b0})
  | ({54{onehot[5]}} & {data_in[5:0], 48'b0})
  | ({54{onehot[4]}} & {data_in[4:0], 49'b0})
  | ({54{onehot[3]}} & {data_in[3:0], 50'b0})
  | ({54{onehot[2]}} & {data_in[2:0], 51'b0})
  | ({54{onehot[1]}} & {data_in[0], 53'b0})
  | ({54{onehot[0]}} & {data_in[1:0], 52'b0})
  ;

endmodule
