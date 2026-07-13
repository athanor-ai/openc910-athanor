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

reg    [NUM-1:0] prio [NUM-1:0];
reg    [NUM-1:0] unused [NUM-1:0];
wire   [NUM-1:0] sel;

genvar i, j;
generate
for(i=0; i<NUM; i=i+1) begin:PRIO_ROW_GEN
  for(j=0; j<NUM; j=j+1) begin:PRIO_BIT_GEN
    always @(posedge clk or negedge rst_b) begin
      if (!rst_b) begin
        // Initialization matches the original shift logic:
        // {prio[i], unused[i]} <= {{NUM{1'b0}}, {NUM{1'b1}}} << i;
        prio[i][j]   <= (j < i);
        unused[i][j] <= (j >= i);
      end else if (clr) begin
        // Simplified update logic: if requester i just finished (sel[i]),
        // it now has lowest priority (all j have priority over it),
        // except for i itself (prio[i][i] is always 0).
        if (sel[i] && (i != j)) begin
          prio[i][j] <= 1'b1;
        end else if (sel[j]) begin
          // If requester j finished, it loses priority over i.
          prio[i][j] <= 1'b0;
        end
      end
    end
  end
  // Grant logic: grant to i if it is valid and no other valid requester j has priority over it.
  assign sel[i] = valid[i] && !(|(valid[NUM-1:0] & prio[i][NUM-1:0]));
end
endgenerate

endmodule