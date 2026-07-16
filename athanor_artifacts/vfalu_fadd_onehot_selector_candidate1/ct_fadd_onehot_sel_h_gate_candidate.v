module ct_fadd_onehot_sel_h(
  data_in,
  onehot,
  result
);

input   [11:0]  data_in;
input   [11:0]  onehot;
output  [11:0]  result;

assign result[11:0] =
    {12{1'b0}}
  | ({12{onehot[11]}} & data_in[11:0])
  | ({12{onehot[10]}} & {data_in[10:0], 1'b0})
  | ({12{onehot[9]}} & {data_in[9:0], 2'b0})
  | ({12{onehot[8]}} & {data_in[8:0], 3'b0})
  | ({12{onehot[7]}} & {data_in[7:0], 4'b0})
  | ({12{onehot[6]}} & {data_in[6:0], 5'b0})
  | ({12{onehot[5]}} & {data_in[5:0], 6'b0})
  | ({12{onehot[4]}} & {data_in[4:0], 7'b0})
  | ({12{onehot[3]}} & {data_in[3:0], 8'b0})
  | ({12{onehot[2]}} & {data_in[2:0], 9'b0})
  | ({12{onehot[1]}} & {data_in[1:0], 10'b0})
  | ({12{onehot[0]}} & {data_in[0], 11'b0})
  ;

endmodule
