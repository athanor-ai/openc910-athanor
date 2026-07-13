module ct_fifo_relation_miter(
  input       clk,
  input       rst_b,
  input       fifo_create_en,
  input       fifo_create_en_dp,
  input       fifo_pop_en,
  input [5:0] fifo_create_data,
  input       pad_yy_icg_scan_en,
  input       fifo_icg_en
);
  wire [5:0] gold_pop_data;
  wire       gold_pop_data_vld;
  wire       gold_full;
  wire       gold_empty;
  wire [1:0] gold_create_ptr;
  wire [1:0] gold_pop_ptr;
  wire [1:0] gold_entry_vld;
  wire [5:0] gold_entry_cont0;
  wire [5:0] gold_entry_cont1;

  wire [5:0] gate_pop_data;
  wire       gate_pop_data_vld;
  wire       gate_full;
  wire       gate_empty;
  wire [1:0] gate_create_ptr;
  wire [1:0] gate_pop_ptr;
  wire [1:0] gate_entry_vld;
  wire [5:0] gate_entry_cont0;
  wire [5:0] gate_entry_cont1;

  ct_fifo_gold_dbg gold (
    .clk(clk),
    .rst_b(rst_b),
    .fifo_create_en(fifo_create_en),
    .fifo_create_en_dp(fifo_create_en_dp),
    .fifo_pop_en(fifo_pop_en),
    .fifo_create_data(fifo_create_data),
    .fifo_pop_data(gold_pop_data),
    .fifo_pop_data_vld(gold_pop_data_vld),
    .fifo_full(gold_full),
    .fifo_empty(gold_empty),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .fifo_icg_en(fifo_icg_en),
    .dbg_create_ptr(gold_create_ptr),
    .dbg_pop_ptr(gold_pop_ptr),
    .dbg_entry_vld(gold_entry_vld),
    .dbg_entry_cont0(gold_entry_cont0),
    .dbg_entry_cont1(gold_entry_cont1)
  );

  ct_fifo_gate_dbg gate (
    .clk(clk),
    .rst_b(rst_b),
    .fifo_create_en(fifo_create_en),
    .fifo_create_en_dp(fifo_create_en_dp),
    .fifo_pop_en(fifo_pop_en),
    .fifo_create_data(fifo_create_data),
    .fifo_pop_data(gate_pop_data),
    .fifo_pop_data_vld(gate_pop_data_vld),
    .fifo_full(gate_full),
    .fifo_empty(gate_empty),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .fifo_icg_en(fifo_icg_en),
    .dbg_create_ptr(gate_create_ptr),
    .dbg_pop_ptr(gate_pop_ptr),
    .dbg_entry_vld(gate_entry_vld),
    .dbg_entry_cont0(gate_entry_cont0),
    .dbg_entry_cont1(gate_entry_cont1)
  );

  always @* begin
    if (rst_b) begin
      assert(gold_pop_data == gate_pop_data);
      assert(gold_pop_data_vld == gate_pop_data_vld);
      assert(gold_full == gate_full);
      assert(gold_empty == gate_empty);
      assert(gold_create_ptr == gate_create_ptr);
      assert(gold_pop_ptr == gate_pop_ptr);
      assert(gold_entry_vld == gate_entry_vld);
      assert(gold_entry_cont0 == gate_entry_cont0);
      assert(gold_entry_cont1 == gate_entry_cont1);
    end
  end
endmodule
