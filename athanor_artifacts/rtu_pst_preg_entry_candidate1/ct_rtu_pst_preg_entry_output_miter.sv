module ct_rtu_pst_preg_entry_output_miter(
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
  input          x_wb_vld
);
  wire          gold_x_cur_state_dealloc;
  wire  [31:0] gold_x_dreg;
  wire  [95:0] gold_x_rel_preg_expand;
  wire          gold_x_retired_released_wb;
  wire          gate_x_cur_state_dealloc;
  wire  [31:0] gate_x_dreg;
  wire  [95:0] gate_x_rel_preg_expand;
  wire          gate_x_retired_released_wb;

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
    .x_wb_vld(x_wb_vld)
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
    .x_wb_vld(x_wb_vld)
  );

  always @* begin
    if (cpurst_b) begin
      assert(gold_x_cur_state_dealloc == gate_x_cur_state_dealloc);
      assert(gold_x_dreg == gate_x_dreg);
      assert(gold_x_rel_preg_expand == gate_x_rel_preg_expand);
      assert(gold_x_retired_released_wb == gate_x_retired_released_wb);
    end
  end
endmodule
