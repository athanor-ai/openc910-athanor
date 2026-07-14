module ct_prio_gate(
  clk,
  rst_b,
  valid,
  clr,
  sel
);
parameter NUM = 2;

input            clk;
input            rst_b;
input  [NUM-1:0] valid;
input            clr;
output [NUM-1:0] sel;

reg prio_1_over_0;
wire clr0;
wire clr1;

assign sel[0] = valid[0] && !(valid[1] && prio_1_over_0);
assign sel[1] = valid[1] && !(valid[0] && !prio_1_over_0);

assign clr0 = clr && sel[0];
assign clr1 = clr && sel[1];

always @(posedge clk or negedge rst_b) begin
  if (!rst_b) begin
    prio_1_over_0 <= 1'b0;
  end else if (clr0) begin
    prio_1_over_0 <= 1'b1;
  end else if (clr1) begin
    prio_1_over_0 <= 1'b0;
  end
end

endmodule
