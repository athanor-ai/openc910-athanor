module ct_prio_output_miter(
  input clk,
  input rst_b,
  input [1:0] valid,
  input clr
);
  wire [1:0] sel_gold;
  wire [1:0] sel_gate;

  ct_prio gold (
    .clk(clk),
    .rst_b(rst_b),
    .valid(valid),
    .clr(clr),
    .sel(sel_gold)
  );

  ct_prio_gate gate (
    .clk(clk),
    .rst_b(rst_b),
    .valid(valid),
    .clr(clr),
    .sel(sel_gate)
  );

  always @(posedge clk) begin
    if (rst_b) begin
      assert(sel_gold == sel_gate);
    end
  end
endmodule
