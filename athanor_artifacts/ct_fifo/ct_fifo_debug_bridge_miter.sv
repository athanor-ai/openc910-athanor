module ct_fifo_debug_bridge_miter(
  input       clk,
  input       rst_b,
  input       fifo_create_en,
  input       fifo_create_en_dp,
  input       fifo_pop_en,
  input [5:0] fifo_create_data,
  input       pad_yy_icg_scan_en,
  input       fifo_icg_en
);
  wire [5:0] gold_exact_pop_data;
  wire       gold_exact_pop_data_vld;
  wire       gold_exact_full;
  wire       gold_exact_empty;
  wire [5:0] gold_dbg_pop_data;
  wire       gold_dbg_pop_data_vld;
  wire       gold_dbg_full;
  wire       gold_dbg_empty;
  wire [1:0] gold_dbg_create_ptr;
  wire [1:0] gold_dbg_pop_ptr;
  wire [1:0] gold_dbg_entry_vld;
  wire [5:0] gold_dbg_entry_cont0;
  wire [5:0] gold_dbg_entry_cont1;

  wire [5:0] gate_exact_pop_data;
  wire       gate_exact_pop_data_vld;
  wire       gate_exact_full;
  wire       gate_exact_empty;
  wire [5:0] gate_dbg_pop_data;
  wire       gate_dbg_pop_data_vld;
  wire       gate_dbg_full;
  wire       gate_dbg_empty;
  wire [1:0] gate_dbg_create_ptr;
  wire [1:0] gate_dbg_pop_ptr;
  wire [1:0] gate_dbg_entry_vld;
  wire [5:0] gate_dbg_entry_cont0;
  wire [5:0] gate_dbg_entry_cont1;

  ct_fifo gold_exact (
    .clk(clk),
    .rst_b(rst_b),
    .fifo_create_en(fifo_create_en),
    .fifo_create_en_dp(fifo_create_en_dp),
    .fifo_pop_en(fifo_pop_en),
    .fifo_create_data(fifo_create_data),
    .fifo_pop_data(gold_exact_pop_data),
    .fifo_pop_data_vld(gold_exact_pop_data_vld),
    .fifo_full(gold_exact_full),
    .fifo_empty(gold_exact_empty),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .fifo_icg_en(fifo_icg_en)
  );

  ct_fifo_gold_dbg gold_dbg (
    .clk(clk),
    .rst_b(rst_b),
    .fifo_create_en(fifo_create_en),
    .fifo_create_en_dp(fifo_create_en_dp),
    .fifo_pop_en(fifo_pop_en),
    .fifo_create_data(fifo_create_data),
    .fifo_pop_data(gold_dbg_pop_data),
    .fifo_pop_data_vld(gold_dbg_pop_data_vld),
    .fifo_full(gold_dbg_full),
    .fifo_empty(gold_dbg_empty),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .fifo_icg_en(fifo_icg_en),
    .dbg_create_ptr(gold_dbg_create_ptr),
    .dbg_pop_ptr(gold_dbg_pop_ptr),
    .dbg_entry_vld(gold_dbg_entry_vld),
    .dbg_entry_cont0(gold_dbg_entry_cont0),
    .dbg_entry_cont1(gold_dbg_entry_cont1)
  );

  ct_fifo_gate gate_exact (
    .clk(clk),
    .rst_b(rst_b),
    .fifo_create_en(fifo_create_en),
    .fifo_create_en_dp(fifo_create_en_dp),
    .fifo_pop_en(fifo_pop_en),
    .fifo_create_data(fifo_create_data),
    .fifo_pop_data(gate_exact_pop_data),
    .fifo_pop_data_vld(gate_exact_pop_data_vld),
    .fifo_full(gate_exact_full),
    .fifo_empty(gate_exact_empty),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .fifo_icg_en(fifo_icg_en)
  );

  ct_fifo_gate_dbg gate_dbg (
    .clk(clk),
    .rst_b(rst_b),
    .fifo_create_en(fifo_create_en),
    .fifo_create_en_dp(fifo_create_en_dp),
    .fifo_pop_en(fifo_pop_en),
    .fifo_create_data(fifo_create_data),
    .fifo_pop_data(gate_dbg_pop_data),
    .fifo_pop_data_vld(gate_dbg_pop_data_vld),
    .fifo_full(gate_dbg_full),
    .fifo_empty(gate_dbg_empty),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .fifo_icg_en(fifo_icg_en),
    .dbg_create_ptr(gate_dbg_create_ptr),
    .dbg_pop_ptr(gate_dbg_pop_ptr),
    .dbg_entry_vld(gate_dbg_entry_vld),
    .dbg_entry_cont0(gate_dbg_entry_cont0),
    .dbg_entry_cont1(gate_dbg_entry_cont1)
  );

  always @* begin
    if (rst_b) begin
      assert(gold_exact_pop_data == gold_dbg_pop_data);
      assert(gold_exact_pop_data_vld == gold_dbg_pop_data_vld);
      assert(gold_exact_full == gold_dbg_full);
      assert(gold_exact_empty == gold_dbg_empty);
      assert(gate_exact_pop_data == gate_dbg_pop_data);
      assert(gate_exact_pop_data_vld == gate_dbg_pop_data_vld);
      assert(gate_exact_full == gate_dbg_full);
      assert(gate_exact_empty == gate_dbg_empty);
    end
  end
endmodule
