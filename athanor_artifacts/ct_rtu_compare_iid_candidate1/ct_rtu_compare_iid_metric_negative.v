module ct_rtu_compare_iid(
  input  [6:0] x_iid0,
  input  [6:0] x_iid1,
  output       x_iid0_older
);
  wire relation = (x_iid0[6] == x_iid1[6])
                ? (x_iid1[5:0] > x_iid0[5:0])
                : (x_iid0[5:0] > x_iid1[5:0]);
  wire [6:0] sum0 = x_iid0 + x_iid1;
  wire [6:0] mix0 = {sum0[5:0], sum0[6]} + (x_iid0 ^ x_iid1);
  wire [6:0] mix1 = (mix0 + {x_iid1[2:0], x_iid0[3:0]}) ^ {x_iid0[0], x_iid1[5:0]};
  wire slow_boundary = (&mix1) | (^(mix0 & mix1));
  assign x_iid0_older = relation ^ slow_boundary;
endmodule
