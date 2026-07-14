module ct_rtu_pst_preg_entry_relation_dbg_ports_miter(
  input          cp0_rtu_icg_en,
  input          cp0_yy_clk_en,
  input          cpurst_b,
  input          dealloc_vld_for_gateclk,
  input          forever_cpuclk,
  input   [4:0]  idu_rtu_pst_dis_inst0_dst_reg,
  input   [6:0]  idu_rtu_pst_dis_inst0_preg_iid,
  input   [6:0]  idu_rtu_pst_dis_inst0_rel_preg,
  input   [4:0]  idu_rtu_pst_dis_inst1_dst_reg,
  input   [6:0]  idu_rtu_pst_dis_inst1_preg_iid,
  input   [6:0]  idu_rtu_pst_dis_inst1_rel_preg,
  input   [4:0]  idu_rtu_pst_dis_inst2_dst_reg,
  input   [6:0]  idu_rtu_pst_dis_inst2_preg_iid,
  input   [6:0]  idu_rtu_pst_dis_inst2_rel_preg,
  input   [4:0]  idu_rtu_pst_dis_inst3_dst_reg,
  input   [6:0]  idu_rtu_pst_dis_inst3_preg_iid,
  input   [6:0]  idu_rtu_pst_dis_inst3_rel_preg,
  input          ifu_xx_sync_reset,
  input          pad_yy_icg_scan_en,
  input          retire_pst_async_flush,
  input          retire_pst_wb_retire_inst0_preg_vld,
  input          retire_pst_wb_retire_inst1_preg_vld,
  input          retire_pst_wb_retire_inst2_preg_vld,
  input          rob_pst_retire_inst0_gateclk_vld,
  input   [6:0]  rob_pst_retire_inst0_iid_updt_val,
  input          rob_pst_retire_inst1_gateclk_vld,
  input   [6:0]  rob_pst_retire_inst1_iid_updt_val,
  input          rob_pst_retire_inst2_gateclk_vld,
  input   [6:0]  rob_pst_retire_inst2_iid_updt_val,
  input          rtu_yy_xx_flush,
  input   [3:0]  x_create_vld,
  input          x_dealloc_mask,
  input          x_dealloc_vld,
  input          x_release_vld,
  input   [4:0]  x_reset_dst_reg,
  input          x_reset_mapped,
  input          x_wb_vld,
  output         ok_life,
  output         ok_storage,
  output         ok_outputs
);
  wire          gold_x_cur_state_dealloc;
  wire  [31:0] gold_x_dreg;
  wire  [95:0] gold_x_rel_preg_expand;
  wire          gold_x_retired_released_wb;
  wire          gate_x_cur_state_dealloc;
  wire  [31:0] gate_x_dreg;
  wire  [95:0] gate_x_rel_preg_expand;
  wire          gate_x_retired_released_wb;
  wire  [4:0]  gold_dbg_lifecycle_cur_state;
  wire  [6:0]  gold_dbg_iid;
  wire  [4:0]  gold_dbg_dst_reg;
  wire  [6:0]  gold_dbg_rel_preg;
  wire         gold_dbg_wb_cur_state;
  wire         gold_dbg_retire_inst0_iid_match;
  wire         gold_dbg_retire_inst1_iid_match;
  wire         gold_dbg_retire_inst2_iid_match;
  wire  [3:0]  gate_dbg_lifecycle_cur_state;
  wire  [6:0]  gate_dbg_iid;
  wire  [4:0]  gate_dbg_dst_reg;
  wire  [6:0]  gate_dbg_rel_preg;
  wire         gate_dbg_wb_cur_state;
  wire         gate_dbg_retire_inst0_iid_match;
  wire         gate_dbg_retire_inst1_iid_match;
  wire         gate_dbg_retire_inst2_iid_match;

  ct_rtu_pst_preg_entry gold (
    .cp0_rtu_icg_en(cp0_rtu_icg_en),
    .cp0_yy_clk_en(cp0_yy_clk_en),
    .cpurst_b(cpurst_b),
    .dealloc_vld_for_gateclk(dealloc_vld_for_gateclk),
    .forever_cpuclk(forever_cpuclk),
    .idu_rtu_pst_dis_inst0_dst_reg(idu_rtu_pst_dis_inst0_dst_reg),
    .idu_rtu_pst_dis_inst0_preg_iid(idu_rtu_pst_dis_inst0_preg_iid),
    .idu_rtu_pst_dis_inst0_rel_preg(idu_rtu_pst_dis_inst0_rel_preg),
    .idu_rtu_pst_dis_inst1_dst_reg(idu_rtu_pst_dis_inst1_dst_reg),
    .idu_rtu_pst_dis_inst1_preg_iid(idu_rtu_pst_dis_inst1_preg_iid),
    .idu_rtu_pst_dis_inst1_rel_preg(idu_rtu_pst_dis_inst1_rel_preg),
    .idu_rtu_pst_dis_inst2_dst_reg(idu_rtu_pst_dis_inst2_dst_reg),
    .idu_rtu_pst_dis_inst2_preg_iid(idu_rtu_pst_dis_inst2_preg_iid),
    .idu_rtu_pst_dis_inst2_rel_preg(idu_rtu_pst_dis_inst2_rel_preg),
    .idu_rtu_pst_dis_inst3_dst_reg(idu_rtu_pst_dis_inst3_dst_reg),
    .idu_rtu_pst_dis_inst3_preg_iid(idu_rtu_pst_dis_inst3_preg_iid),
    .idu_rtu_pst_dis_inst3_rel_preg(idu_rtu_pst_dis_inst3_rel_preg),
    .ifu_xx_sync_reset(ifu_xx_sync_reset),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .retire_pst_async_flush(retire_pst_async_flush),
    .retire_pst_wb_retire_inst0_preg_vld(retire_pst_wb_retire_inst0_preg_vld),
    .retire_pst_wb_retire_inst1_preg_vld(retire_pst_wb_retire_inst1_preg_vld),
    .retire_pst_wb_retire_inst2_preg_vld(retire_pst_wb_retire_inst2_preg_vld),
    .rob_pst_retire_inst0_gateclk_vld(rob_pst_retire_inst0_gateclk_vld),
    .rob_pst_retire_inst0_iid_updt_val(rob_pst_retire_inst0_iid_updt_val),
    .rob_pst_retire_inst1_gateclk_vld(rob_pst_retire_inst1_gateclk_vld),
    .rob_pst_retire_inst1_iid_updt_val(rob_pst_retire_inst1_iid_updt_val),
    .rob_pst_retire_inst2_gateclk_vld(rob_pst_retire_inst2_gateclk_vld),
    .rob_pst_retire_inst2_iid_updt_val(rob_pst_retire_inst2_iid_updt_val),
    .rtu_yy_xx_flush(rtu_yy_xx_flush),
    .x_create_vld(x_create_vld),
    .x_cur_state_dealloc(gold_x_cur_state_dealloc),
    .x_dealloc_mask(x_dealloc_mask),
    .x_dealloc_vld(x_dealloc_vld),
    .x_dreg(gold_x_dreg),
    .x_rel_preg_expand(gold_x_rel_preg_expand),
    .x_release_vld(x_release_vld),
    .x_reset_dst_reg(x_reset_dst_reg),
    .x_reset_mapped(x_reset_mapped),
    .x_retired_released_wb(gold_x_retired_released_wb),
    .x_wb_vld(x_wb_vld),
    .dbg_lifecycle_cur_state(gold_dbg_lifecycle_cur_state),
    .dbg_iid(gold_dbg_iid),
    .dbg_dst_reg(gold_dbg_dst_reg),
    .dbg_rel_preg(gold_dbg_rel_preg),
    .dbg_wb_cur_state(gold_dbg_wb_cur_state),
    .dbg_retire_inst0_iid_match(gold_dbg_retire_inst0_iid_match),
    .dbg_retire_inst1_iid_match(gold_dbg_retire_inst1_iid_match),
    .dbg_retire_inst2_iid_match(gold_dbg_retire_inst2_iid_match)
  );

  ct_rtu_pst_preg_entry_gate gate (
    .cp0_rtu_icg_en(cp0_rtu_icg_en),
    .cp0_yy_clk_en(cp0_yy_clk_en),
    .cpurst_b(cpurst_b),
    .dealloc_vld_for_gateclk(dealloc_vld_for_gateclk),
    .forever_cpuclk(forever_cpuclk),
    .idu_rtu_pst_dis_inst0_dst_reg(idu_rtu_pst_dis_inst0_dst_reg),
    .idu_rtu_pst_dis_inst0_preg_iid(idu_rtu_pst_dis_inst0_preg_iid),
    .idu_rtu_pst_dis_inst0_rel_preg(idu_rtu_pst_dis_inst0_rel_preg),
    .idu_rtu_pst_dis_inst1_dst_reg(idu_rtu_pst_dis_inst1_dst_reg),
    .idu_rtu_pst_dis_inst1_preg_iid(idu_rtu_pst_dis_inst1_preg_iid),
    .idu_rtu_pst_dis_inst1_rel_preg(idu_rtu_pst_dis_inst1_rel_preg),
    .idu_rtu_pst_dis_inst2_dst_reg(idu_rtu_pst_dis_inst2_dst_reg),
    .idu_rtu_pst_dis_inst2_preg_iid(idu_rtu_pst_dis_inst2_preg_iid),
    .idu_rtu_pst_dis_inst2_rel_preg(idu_rtu_pst_dis_inst2_rel_preg),
    .idu_rtu_pst_dis_inst3_dst_reg(idu_rtu_pst_dis_inst3_dst_reg),
    .idu_rtu_pst_dis_inst3_preg_iid(idu_rtu_pst_dis_inst3_preg_iid),
    .idu_rtu_pst_dis_inst3_rel_preg(idu_rtu_pst_dis_inst3_rel_preg),
    .ifu_xx_sync_reset(ifu_xx_sync_reset),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .retire_pst_async_flush(retire_pst_async_flush),
    .retire_pst_wb_retire_inst0_preg_vld(retire_pst_wb_retire_inst0_preg_vld),
    .retire_pst_wb_retire_inst1_preg_vld(retire_pst_wb_retire_inst1_preg_vld),
    .retire_pst_wb_retire_inst2_preg_vld(retire_pst_wb_retire_inst2_preg_vld),
    .rob_pst_retire_inst0_gateclk_vld(rob_pst_retire_inst0_gateclk_vld),
    .rob_pst_retire_inst0_iid_updt_val(rob_pst_retire_inst0_iid_updt_val),
    .rob_pst_retire_inst1_gateclk_vld(rob_pst_retire_inst1_gateclk_vld),
    .rob_pst_retire_inst1_iid_updt_val(rob_pst_retire_inst1_iid_updt_val),
    .rob_pst_retire_inst2_gateclk_vld(rob_pst_retire_inst2_gateclk_vld),
    .rob_pst_retire_inst2_iid_updt_val(rob_pst_retire_inst2_iid_updt_val),
    .rtu_yy_xx_flush(rtu_yy_xx_flush),
    .x_create_vld(x_create_vld),
    .x_cur_state_dealloc(gate_x_cur_state_dealloc),
    .x_dealloc_mask(x_dealloc_mask),
    .x_dealloc_vld(x_dealloc_vld),
    .x_dreg(gate_x_dreg),
    .x_rel_preg_expand(gate_x_rel_preg_expand),
    .x_release_vld(x_release_vld),
    .x_reset_dst_reg(x_reset_dst_reg),
    .x_reset_mapped(x_reset_mapped),
    .x_retired_released_wb(gate_x_retired_released_wb),
    .x_wb_vld(x_wb_vld),
    .dbg_lifecycle_cur_state(gate_dbg_lifecycle_cur_state),
    .dbg_iid(gate_dbg_iid),
    .dbg_dst_reg(gate_dbg_dst_reg),
    .dbg_rel_preg(gate_dbg_rel_preg),
    .dbg_wb_cur_state(gate_dbg_wb_cur_state),
    .dbg_retire_inst0_iid_match(gate_dbg_retire_inst0_iid_match),
    .dbg_retire_inst1_iid_match(gate_dbg_retire_inst1_iid_match),
    .dbg_retire_inst2_iid_match(gate_dbg_retire_inst2_iid_match)
  );

  wire [4:0] g_life = gold_dbg_lifecycle_cur_state;
  wire [3:0] q_life = gate_dbg_lifecycle_cur_state;
  wire       g_onehot = (g_life != 5'b00000) && ((g_life & (g_life - 5'b00001)) == 5'b00000);
  wire       q_onehot0 = ((q_life & (q_life - 4'b0001)) == 4'b0000);
  wire       life_relation =
             q_life[0] == g_life[0]
          && q_life[1] == g_life[2]
          && q_life[2] == g_life[3]
          && q_life[3] == g_life[4]
          && g_life[1] == (q_life == 4'b0000);
  wire       create_onehot0 = ((x_create_vld & (x_create_vld - 4'b0001)) == 4'b0000);
  assign     ok_life = !cpurst_b || (g_onehot && q_onehot0 && life_relation);
  assign     ok_storage = !cpurst_b || (
             gold_dbg_iid == gate_dbg_iid
          && gold_dbg_dst_reg == gate_dbg_dst_reg
          && gold_dbg_rel_preg == gate_dbg_rel_preg
          && gold_dbg_wb_cur_state == gate_dbg_wb_cur_state
          && gold_dbg_retire_inst0_iid_match == gate_dbg_retire_inst0_iid_match
          && gold_dbg_retire_inst1_iid_match == gate_dbg_retire_inst1_iid_match
          && gold_dbg_retire_inst2_iid_match == gate_dbg_retire_inst2_iid_match);
  assign     ok_outputs = !cpurst_b
          || (gold_x_cur_state_dealloc == gate_x_cur_state_dealloc
          &&  gold_x_dreg == gate_x_dreg
          &&  gold_x_rel_preg_expand == gate_x_rel_preg_expand
          &&  gold_x_retired_released_wb == gate_x_retired_released_wb);

  always @* begin
    if (cpurst_b) begin
      assume(create_onehot0);
    end
  end
endmodule
