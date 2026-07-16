module miter(
  fail
);
  reg [53:0] data_in;
  reg [53:0] onehot;
  wire [53:0] gold_result;
  wire [53:0] gate_result;
  output fail;

  gold u_gold(.data_in(data_in), .onehot(onehot), .result(gold_result));
  gate u_gate(.data_in(data_in), .onehot(onehot), .result(gate_result));

  wire onehot_or_zero = (onehot == 54'b0) || ((onehot & (onehot - 54'b1)) == 54'b0);

  assign fail = onehot_or_zero && (gold_result != gate_result);
endmodule
