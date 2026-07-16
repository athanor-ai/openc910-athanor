/* Scratch scout candidate derived from public ct_rtu_encode_96.v. */
module ct_rtu_encode_96(
  x_num,
  x_num_expand
);

input   [95:0]  x_num_expand;
output  [6 :0]  x_num;

wire    [6 :0]  x_num;
wire    [95:0]  x_num_expand;

assign x_num[0] = |(x_num_expand[95:0] & 96'hAAAAAAAAAAAAAAAAAAAAAAAA);
assign x_num[1] = |(x_num_expand[95:0] & 96'hCCCCCCCCCCCCCCCCCCCCCCCC);
assign x_num[2] = |(x_num_expand[95:0] & 96'hF0F0F0F0F0F0F0F0F0F0F0F0);
assign x_num[3] = |(x_num_expand[95:0] & 96'hFF00FF00FF00FF00FF00FF00);
assign x_num[4] = |(x_num_expand[95:0] & 96'hFFFF0000FFFF0000FFFF0000);
assign x_num[5] = |(x_num_expand[95:0] & 96'h00000000FFFFFFFF00000000);
assign x_num[6] = |(x_num_expand[95:0] & 96'hFFFFFFFF0000000000000000);

endmodule
