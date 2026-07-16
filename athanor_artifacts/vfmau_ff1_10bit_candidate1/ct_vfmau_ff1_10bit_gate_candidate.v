module ct_vfmau_ff1_10bit(
  ff1_data,
  ff1_result
);

input   [9:0]  ff1_data;
output  [3:0]  ff1_result;

wire [9:0] onehot;

assign onehot[9] = ff1_data[9];
assign onehot[8] = ff1_data[8] & ~ff1_data[9];
assign onehot[7] = ff1_data[7] & ~|ff1_data[9:8];
assign onehot[6] = ff1_data[6] & ~|ff1_data[9:7];
assign onehot[5] = ff1_data[5] & ~|ff1_data[9:6];
assign onehot[4] = ff1_data[4] & ~|ff1_data[9:5];
assign onehot[3] = ff1_data[3] & ~|ff1_data[9:4];
assign onehot[2] = ff1_data[2] & ~|ff1_data[9:3];
assign onehot[1] = ff1_data[1] & ~|ff1_data[9:2];
assign onehot[0] = ff1_data[0] & ~|ff1_data[9:1];

assign ff1_result[3:0] =
    ({4{onehot[9]}} & 4'd1)
  | ({4{onehot[8]}} & 4'd2)
  | ({4{onehot[7]}} & 4'd3)
  | ({4{onehot[6]}} & 4'd4)
  | ({4{onehot[5]}} & 4'd5)
  | ({4{onehot[4]}} & 4'd6)
  | ({4{onehot[3]}} & 4'd7)
  | ({4{onehot[2]}} & 4'd8)
  | ({4{onehot[1]}} & 4'd9)
  | ({4{onehot[0]}} & 4'd10);

endmodule
