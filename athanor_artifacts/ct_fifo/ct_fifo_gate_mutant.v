module ct_fifo_gate(
  clk,
  rst_b,
  fifo_create_en,
  fifo_create_en_dp,
  fifo_pop_en,
  fifo_create_data,
  fifo_pop_data,
  fifo_pop_data_vld,
  fifo_full,
  fifo_empty,
  pad_yy_icg_scan_en,
  fifo_icg_en
);
parameter DEPTH = 2;
parameter WIDTH = 6;
parameter PTR_W = 1;

input              clk;
input              rst_b;
input              fifo_create_en;
input              fifo_create_en_dp;
input              fifo_pop_en;
input  [WIDTH-1:0] fifo_create_data;
input              pad_yy_icg_scan_en;
input              fifo_icg_en;

output [WIDTH-1:0] fifo_pop_data;
output             fifo_pop_data_vld;
output             fifo_full;
output             fifo_empty;

wire               ctrl_clk;
wire               ctrl_clk_en;
wire   [DEPTH-1:0] entry_clk;
wire   [DEPTH-1:0] fifo_create_ptr;
wire   [DEPTH-1:0] fifo_pop_sel;
wire   [DEPTH-1:0] fifo_entry_create;
wire   [DEPTH-1:0] fifo_entry_create_dp;
wire   [DEPTH-1:0] fifo_entry_pop;
wire               fifo_not_empty;

reg                fifo_create_idx;
reg                fifo_pop_idx;
reg    [DEPTH-1:0] fifo_entry_vld;
reg    [WIDTH-1:0] fifo_entry_cont [DEPTH-1:0];

assign fifo_not_empty = |fifo_entry_vld;
assign ctrl_clk_en = fifo_create_en_dp | fifo_not_empty;

gated_clk_cell x_fifo_ctrl_gated_clk(
  .clk_in               (clk                 ),
  .clk_out              (ctrl_clk            ),
  .external_en          (1'b0                ),
  .global_en            (1'b1                ),
  .local_en             (ctrl_clk_en         ),
  .module_en            (fifo_icg_en         ),
  .pad_yy_icg_scan_en   (pad_yy_icg_scan_en  )
);

always @(posedge ctrl_clk or negedge rst_b)
begin
  if (!rst_b)
    fifo_create_idx <= 1'b0;
  else if (fifo_create_en)
    fifo_create_idx <= ~fifo_create_idx;
end

always @(posedge ctrl_clk or negedge rst_b)
begin
  if (!rst_b)
    fifo_pop_idx <= 1'b0;
  else if (fifo_pop_en)
    fifo_pop_idx <= ~fifo_pop_idx;
end

assign fifo_create_ptr = fifo_create_idx ? 2'b10 : 2'b01;
assign fifo_pop_sel = fifo_pop_idx ? 2'b10 : 2'b01;
assign fifo_entry_create = {DEPTH{fifo_create_en}} & fifo_create_ptr;
assign fifo_entry_create_dp = {DEPTH{fifo_create_en_dp}} & fifo_create_ptr;
assign fifo_entry_pop = {DEPTH{fifo_pop_en}} & fifo_pop_sel;

genvar i;
generate
for(i=0; i<DEPTH; i=i+1) begin: DFIFO_GEN
always @(posedge ctrl_clk or negedge rst_b)
begin
  if (!rst_b)
    fifo_entry_vld[i] <= 1'b0;
  else if (fifo_entry_create[i])
    fifo_entry_vld[i] <= 1'b1;
  else if (fifo_entry_pop[i])
    fifo_entry_vld[i] <= 1'b0;
end

gated_clk_cell x_entry_gated_clk(
  .clk_in               (clk                 ),
  .clk_out              (entry_clk[i]        ),
  .external_en          (1'b0                ),
  .global_en            (1'b1                ),
  .local_en             (fifo_entry_create_dp[i]),
  .module_en            (fifo_icg_en         ),
  .pad_yy_icg_scan_en   (pad_yy_icg_scan_en  )
);

always @(posedge entry_clk[i] or negedge rst_b)
begin
  if (!rst_b)
    fifo_entry_cont[i] <= {WIDTH{1'b0}};
  else if (fifo_entry_create_dp[i])
    fifo_entry_cont[i] <= fifo_create_data;
end
end
endgenerate

assign fifo_full = ~&fifo_entry_vld;
assign fifo_empty = ~fifo_not_empty;
assign fifo_pop_data_vld = fifo_not_empty;
assign fifo_pop_data = fifo_pop_idx ? fifo_entry_cont[1] : fifo_entry_cont[0];

endmodule
