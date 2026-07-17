module plic_granu_arb_miter(
  input  [44:0] int_in_prio,
  input  [8:0]  int_in_req,
  input  [89:0] int_in_id,
  output        bad
);
  wire          gold_req;
  wire [9:0]    gold_id;
  wire [4:0]    gold_prio;
  wire          gate_req;
  wire [9:0]    gate_id;
  wire [4:0]    gate_prio;

  plic_granu_arb_gold #(
    .SEL_NUM(9),
    .SEL_BIT(4),
    .ID_NUM(10),
    .PRIO_BIT(5)
  ) gold (
    .int_in_prio(int_in_prio),
    .int_in_req(int_in_req),
    .int_in_id(int_in_id),
    .int_out_req(gold_req),
    .int_out_id(gold_id),
    .int_out_prio(gold_prio)
  );

  plic_granu_arb_gate #(
    .SEL_NUM(9),
    .SEL_BIT(4),
    .ID_NUM(10),
    .PRIO_BIT(5)
  ) gate (
    .int_in_prio(int_in_prio),
    .int_in_req(int_in_req),
    .int_in_id(int_in_id),
    .int_out_req(gate_req),
    .int_out_id(gate_id),
    .int_out_prio(gate_prio)
  );

  assign bad = (gold_req != gate_req)
            || (gold_id != gate_id)
            || (gold_prio != gate_prio);
endmodule
