module ct_lsu_vb_output_miter(
  input [4  :0] biu_lsu_b_id,
  input biu_lsu_b_vld,
  input bus_arb_vb_aw_grnt,
  input bus_arb_vb_w_grnt,
  input cp0_lsu_icg_en,
  input cp0_yy_clk_en,
  input cpurst_b,
  input dcache_arb_vb_ld_grnt,
  input dcache_arb_vb_st_grnt,
  input [33 :0] icc_vb_addr_tto6,
  input icc_vb_create_dp_vld,
  input icc_vb_create_gateclk_en,
  input icc_vb_create_req,
  input icc_vb_create_vld,
  input icc_vb_inv,
  input ld_da_vb_snq_data_reissue,
  input [33 :0] lfb_vb_addr_tto6,
  input lfb_vb_create_dp_vld,
  input lfb_vb_create_gateclk_en,
  input lfb_vb_create_req,
  input lfb_vb_create_vld,
  input [2  :0] lfb_vb_id,
  input lsu_special_clk,
  input pad_yy_icg_scan_en,
  input [39 :0] pfu_biu_req_addr,
  input [39 :0] rb_biu_req_addr,
  input [33 :0] snq_bypass_addr_tto6,
  input [39 :0] snq_create_addr,
  input [1  :0] snq_depd_vb_id,
  input snq_vb_bypass_check,
  input st_da_dcache_dirty,
  input st_da_dcache_hit,
  input st_da_dcache_miss,
  input st_da_dcache_replace_dirty,
  input st_da_dcache_replace_valid,
  input st_da_dcache_replace_way,
  input st_da_dcache_way,
  input st_da_vb_ecc_err,
  input st_da_vb_ecc_stall,
  input [25 :0] st_da_vb_feedback_addr_tto14,
  input st_da_vb_tag_reissue,
  input [1  :0] vb_data_entry_addr_id_0,
  input [1  :0] vb_data_entry_addr_id_1,
  input [1  :0] vb_data_entry_addr_id_2,
  input [2  :0] vb_data_entry_biu_req,
  input [2  :0] vb_data_entry_bypass_pop,
  input [2  :0] vb_data_entry_dirty,
  input [2  :0] vb_data_entry_inv,
  input [2  :0] vb_data_entry_lfb_create,
  input [2  :0] vb_data_entry_normal_pop,
  input [2  :0] vb_data_entry_req_success,
  input [2  :0] vb_data_entry_vld,
  input [2  :0] vb_data_entry_wd_sm_req,
  input [127:0] vb_data_entry_write_data128_0,
  input [127:0] vb_data_entry_write_data128_1,
  input [127:0] vb_data_entry_write_data128_2,
  input [2  :0] vb_sdb_data_entry_vld,
  input [33 :0] wmb_vb_addr_tto6,
  input wmb_vb_create_dp_vld,
  input wmb_vb_create_gateclk_en,
  input wmb_vb_create_req,
  input wmb_vb_create_vld,
  input wmb_vb_inv,
  input wmb_vb_set_way_mode,
  input [2  :0] wmb_write_ptr_encode,
  input [39 :0] wmb_write_req_addr
);
  wire [1  :0] gold_lsu_had_vb_addr_entry_vld;
  wire [1  :0] gate_lsu_had_vb_addr_entry_vld;
  wire [2  :0] gold_lsu_had_vb_data_entry_vld;
  wire [2  :0] gate_lsu_had_vb_data_entry_vld;
  wire [3  :0] gold_lsu_had_vb_rcl_sm_state;
  wire [3  :0] gate_lsu_had_vb_rcl_sm_state;
  wire [2  :0] gold_snq_data_bypass_hit;
  wire [2  :0] gate_snq_data_bypass_hit;
  wire [39 :0] gold_vb_biu_aw_addr;
  wire [39 :0] gate_vb_biu_aw_addr;
  wire [1  :0] gold_vb_biu_aw_bar;
  wire [1  :0] gate_vb_biu_aw_bar;
  wire [1  :0] gold_vb_biu_aw_burst;
  wire [1  :0] gate_vb_biu_aw_burst;
  wire [3  :0] gold_vb_biu_aw_cache;
  wire [3  :0] gate_vb_biu_aw_cache;
  wire [1  :0] gold_vb_biu_aw_domain;
  wire [1  :0] gate_vb_biu_aw_domain;
  wire gold_vb_biu_aw_dp_req;
  wire gate_vb_biu_aw_dp_req;
  wire [4  :0] gold_vb_biu_aw_id;
  wire [4  :0] gate_vb_biu_aw_id;
  wire [1  :0] gold_vb_biu_aw_len;
  wire [1  :0] gate_vb_biu_aw_len;
  wire gold_vb_biu_aw_lock;
  wire gate_vb_biu_aw_lock;
  wire [2  :0] gold_vb_biu_aw_prot;
  wire [2  :0] gate_vb_biu_aw_prot;
  wire gold_vb_biu_aw_req;
  wire gate_vb_biu_aw_req;
  wire gold_vb_biu_aw_req_gateclk_en;
  wire gate_vb_biu_aw_req_gateclk_en;
  wire [2  :0] gold_vb_biu_aw_size;
  wire [2  :0] gate_vb_biu_aw_size;
  wire [2  :0] gold_vb_biu_aw_snoop;
  wire [2  :0] gate_vb_biu_aw_snoop;
  wire gold_vb_biu_aw_unique;
  wire gate_vb_biu_aw_unique;
  wire gold_vb_biu_aw_user;
  wire gate_vb_biu_aw_user;
  wire [127:0] gold_vb_biu_w_data;
  wire [127:0] gate_vb_biu_w_data;
  wire [4  :0] gold_vb_biu_w_id;
  wire [4  :0] gate_vb_biu_w_id;
  wire gold_vb_biu_w_last;
  wire gate_vb_biu_w_last;
  wire gold_vb_biu_w_req;
  wire gate_vb_biu_w_req;
  wire [15 :0] gold_vb_biu_w_strb;
  wire [15 :0] gate_vb_biu_w_strb;
  wire gold_vb_biu_w_vld;
  wire gate_vb_biu_w_vld;
  wire [2  :0] gold_vb_data_entry_biu_req_success;
  wire [2  :0] gate_vb_data_entry_biu_req_success;
  wire [2  :0] gold_vb_data_entry_create_dp_vld;
  wire [2  :0] gate_vb_data_entry_create_dp_vld;
  wire [2  :0] gold_vb_data_entry_create_gateclk_en;
  wire [2  :0] gate_vb_data_entry_create_gateclk_en;
  wire [2  :0] gold_vb_data_entry_create_vld;
  wire [2  :0] gate_vb_data_entry_create_vld;
  wire [2  :0] gold_vb_data_entry_wd_sm_grnt;
  wire [2  :0] gate_vb_data_entry_wd_sm_grnt;
  wire [39 :0] gold_vb_dcache_arb_borrow_addr;
  wire [39 :0] gate_vb_dcache_arb_borrow_addr;
  wire gold_vb_dcache_arb_data_way;
  wire gate_vb_dcache_arb_data_way;
  wire gold_vb_dcache_arb_dcache_replace;
  wire gate_vb_dcache_arb_dcache_replace;
  wire gold_vb_dcache_arb_ld_borrow_req;
  wire gate_vb_dcache_arb_ld_borrow_req;
  wire gold_vb_dcache_arb_ld_borrow_req_gate;
  wire gate_vb_dcache_arb_ld_borrow_req_gate;
  wire [7  :0] gold_vb_dcache_arb_ld_data_gateclk_en;
  wire [7  :0] gate_vb_dcache_arb_ld_data_gateclk_en;
  wire [10 :0] gold_vb_dcache_arb_ld_data_idx;
  wire [10 :0] gate_vb_dcache_arb_ld_data_idx;
  wire gold_vb_dcache_arb_ld_req;
  wire gate_vb_dcache_arb_ld_req;
  wire gold_vb_dcache_arb_ld_tag_gateclk_en;
  wire gate_vb_dcache_arb_ld_tag_gateclk_en;
  wire [8  :0] gold_vb_dcache_arb_ld_tag_idx;
  wire [8  :0] gate_vb_dcache_arb_ld_tag_idx;
  wire gold_vb_dcache_arb_ld_tag_req;
  wire gate_vb_dcache_arb_ld_tag_req;
  wire [1  :0] gold_vb_dcache_arb_ld_tag_wen;
  wire [1  :0] gate_vb_dcache_arb_ld_tag_wen;
  wire gold_vb_dcache_arb_serial_req;
  wire gate_vb_dcache_arb_serial_req;
  wire gold_vb_dcache_arb_set_way_mode;
  wire gate_vb_dcache_arb_set_way_mode;
  wire gold_vb_dcache_arb_st_borrow_req;
  wire gate_vb_dcache_arb_st_borrow_req;
  wire [6  :0] gold_vb_dcache_arb_st_dirty_din;
  wire [6  :0] gate_vb_dcache_arb_st_dirty_din;
  wire gold_vb_dcache_arb_st_dirty_gateclk_en;
  wire gate_vb_dcache_arb_st_dirty_gateclk_en;
  wire gold_vb_dcache_arb_st_dirty_gwen;
  wire gate_vb_dcache_arb_st_dirty_gwen;
  wire [8  :0] gold_vb_dcache_arb_st_dirty_idx;
  wire [8  :0] gate_vb_dcache_arb_st_dirty_idx;
  wire gold_vb_dcache_arb_st_dirty_req;
  wire gate_vb_dcache_arb_st_dirty_req;
  wire [6  :0] gold_vb_dcache_arb_st_dirty_wen;
  wire [6  :0] gate_vb_dcache_arb_st_dirty_wen;
  wire gold_vb_dcache_arb_st_req;
  wire gate_vb_dcache_arb_st_req;
  wire gold_vb_dcache_arb_st_tag_gateclk_en;
  wire gate_vb_dcache_arb_st_tag_gateclk_en;
  wire [8  :0] gold_vb_dcache_arb_st_tag_idx;
  wire [8  :0] gate_vb_dcache_arb_st_tag_idx;
  wire gold_vb_dcache_arb_st_tag_req;
  wire gate_vb_dcache_arb_st_tag_req;
  wire gold_vb_empty;
  wire gate_vb_empty;
  wire gold_vb_icc_create_grnt;
  wire gate_vb_icc_create_grnt;
  wire gold_vb_invalid_vld;
  wire gate_vb_invalid_vld;
  wire [7  :0] gold_vb_lfb_addr_entry_rcl_done;
  wire [7  :0] gate_vb_lfb_addr_entry_rcl_done;
  wire gold_vb_lfb_create_grnt;
  wire gate_vb_lfb_create_grnt;
  wire gold_vb_lfb_dcache_dirty;
  wire gate_vb_lfb_dcache_dirty;
  wire gold_vb_lfb_dcache_hit;
  wire gate_vb_lfb_dcache_hit;
  wire gold_vb_lfb_dcache_way;
  wire gate_vb_lfb_dcache_way;
  wire gold_vb_lfb_rcl_done;
  wire gate_vb_lfb_rcl_done;
  wire gold_vb_lfb_vb_req_hit_idx;
  wire gate_vb_lfb_vb_req_hit_idx;
  wire gold_vb_pfu_biu_req_hit_idx;
  wire gate_vb_pfu_biu_req_hit_idx;
  wire gold_vb_rb_biu_req_hit_idx;
  wire gate_vb_rb_biu_req_hit_idx;
  wire [1  :0] gold_vb_rcl_sm_addr_id;
  wire [1  :0] gate_vb_rcl_sm_addr_id;
  wire gold_vb_rcl_sm_data_dcache_dirty;
  wire gate_vb_rcl_sm_data_dcache_dirty;
  wire [2  :0] gold_vb_rcl_sm_data_id;
  wire [2  :0] gate_vb_rcl_sm_data_id;
  wire [2  :0] gold_vb_rcl_sm_data_set_data_done;
  wire [2  :0] gate_vb_rcl_sm_data_set_data_done;
  wire gold_vb_rcl_sm_inv;
  wire gate_vb_rcl_sm_inv;
  wire gold_vb_rcl_sm_lfb_create;
  wire gate_vb_rcl_sm_lfb_create;
  wire [2  :0] gold_vb_snq_bypass_db_id;
  wire [2  :0] gate_vb_snq_bypass_db_id;
  wire gold_vb_snq_bypass_hit;
  wire gate_vb_snq_bypass_hit;
  wire [1  :0] gold_vb_snq_depd;
  wire [1  :0] gate_vb_snq_depd;
  wire [1  :0] gold_vb_snq_depd_remove;
  wire [1  :0] gate_vb_snq_depd_remove;
  wire gold_vb_snq_start_hit_idx;
  wire gate_vb_snq_start_hit_idx;
  wire [1  :0] gold_vb_snq_wait_remove;
  wire [1  :0] gate_vb_snq_wait_remove;
  wire [1  :0] gold_vb_snq_wait_vb_id;
  wire [1  :0] gate_vb_snq_wait_vb_id;
  wire [3  :0] gold_vb_wd_sm_data_bias;
  wire [3  :0] gate_vb_wd_sm_data_bias;
  wire [2  :0] gold_vb_wd_sm_data_pop_req;
  wire [2  :0] gate_vb_wd_sm_data_pop_req;
  wire gold_vb_wmb_create_grnt;
  wire gate_vb_wmb_create_grnt;
  wire gold_vb_wmb_empty;
  wire gate_vb_wmb_empty;
  wire [7  :0] gold_vb_wmb_entry_rcl_done;
  wire [7  :0] gate_vb_wmb_entry_rcl_done;
  wire gold_vb_wmb_write_req_hit_idx;
  wire gate_vb_wmb_write_req_hit_idx;
  wire [33 :0] gold_victim_addr;
  wire [33 :0] gate_victim_addr;
  ct_lsu_vb gold_i (
    .biu_lsu_b_id(biu_lsu_b_id),
    .biu_lsu_b_vld(biu_lsu_b_vld),
    .bus_arb_vb_aw_grnt(bus_arb_vb_aw_grnt),
    .bus_arb_vb_w_grnt(bus_arb_vb_w_grnt),
    .cp0_lsu_icg_en(cp0_lsu_icg_en),
    .cp0_yy_clk_en(cp0_yy_clk_en),
    .cpurst_b(cpurst_b),
    .dcache_arb_vb_ld_grnt(dcache_arb_vb_ld_grnt),
    .dcache_arb_vb_st_grnt(dcache_arb_vb_st_grnt),
    .icc_vb_addr_tto6(icc_vb_addr_tto6),
    .icc_vb_create_dp_vld(icc_vb_create_dp_vld),
    .icc_vb_create_gateclk_en(icc_vb_create_gateclk_en),
    .icc_vb_create_req(icc_vb_create_req),
    .icc_vb_create_vld(icc_vb_create_vld),
    .icc_vb_inv(icc_vb_inv),
    .ld_da_vb_snq_data_reissue(ld_da_vb_snq_data_reissue),
    .lfb_vb_addr_tto6(lfb_vb_addr_tto6),
    .lfb_vb_create_dp_vld(lfb_vb_create_dp_vld),
    .lfb_vb_create_gateclk_en(lfb_vb_create_gateclk_en),
    .lfb_vb_create_req(lfb_vb_create_req),
    .lfb_vb_create_vld(lfb_vb_create_vld),
    .lfb_vb_id(lfb_vb_id),
    .lsu_special_clk(lsu_special_clk),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .pfu_biu_req_addr(pfu_biu_req_addr),
    .rb_biu_req_addr(rb_biu_req_addr),
    .snq_bypass_addr_tto6(snq_bypass_addr_tto6),
    .snq_create_addr(snq_create_addr),
    .snq_depd_vb_id(snq_depd_vb_id),
    .snq_vb_bypass_check(snq_vb_bypass_check),
    .st_da_dcache_dirty(st_da_dcache_dirty),
    .st_da_dcache_hit(st_da_dcache_hit),
    .st_da_dcache_miss(st_da_dcache_miss),
    .st_da_dcache_replace_dirty(st_da_dcache_replace_dirty),
    .st_da_dcache_replace_valid(st_da_dcache_replace_valid),
    .st_da_dcache_replace_way(st_da_dcache_replace_way),
    .st_da_dcache_way(st_da_dcache_way),
    .st_da_vb_ecc_err(st_da_vb_ecc_err),
    .st_da_vb_ecc_stall(st_da_vb_ecc_stall),
    .st_da_vb_feedback_addr_tto14(st_da_vb_feedback_addr_tto14),
    .st_da_vb_tag_reissue(st_da_vb_tag_reissue),
    .vb_data_entry_addr_id_0(vb_data_entry_addr_id_0),
    .vb_data_entry_addr_id_1(vb_data_entry_addr_id_1),
    .vb_data_entry_addr_id_2(vb_data_entry_addr_id_2),
    .vb_data_entry_biu_req(vb_data_entry_biu_req),
    .vb_data_entry_bypass_pop(vb_data_entry_bypass_pop),
    .vb_data_entry_dirty(vb_data_entry_dirty),
    .vb_data_entry_inv(vb_data_entry_inv),
    .vb_data_entry_lfb_create(vb_data_entry_lfb_create),
    .vb_data_entry_normal_pop(vb_data_entry_normal_pop),
    .vb_data_entry_req_success(vb_data_entry_req_success),
    .vb_data_entry_vld(vb_data_entry_vld),
    .vb_data_entry_wd_sm_req(vb_data_entry_wd_sm_req),
    .vb_data_entry_write_data128_0(vb_data_entry_write_data128_0),
    .vb_data_entry_write_data128_1(vb_data_entry_write_data128_1),
    .vb_data_entry_write_data128_2(vb_data_entry_write_data128_2),
    .vb_sdb_data_entry_vld(vb_sdb_data_entry_vld),
    .wmb_vb_addr_tto6(wmb_vb_addr_tto6),
    .wmb_vb_create_dp_vld(wmb_vb_create_dp_vld),
    .wmb_vb_create_gateclk_en(wmb_vb_create_gateclk_en),
    .wmb_vb_create_req(wmb_vb_create_req),
    .wmb_vb_create_vld(wmb_vb_create_vld),
    .wmb_vb_inv(wmb_vb_inv),
    .wmb_vb_set_way_mode(wmb_vb_set_way_mode),
    .wmb_write_ptr_encode(wmb_write_ptr_encode),
    .wmb_write_req_addr(wmb_write_req_addr),
    .lsu_had_vb_addr_entry_vld(gold_lsu_had_vb_addr_entry_vld),
    .lsu_had_vb_data_entry_vld(gold_lsu_had_vb_data_entry_vld),
    .lsu_had_vb_rcl_sm_state(gold_lsu_had_vb_rcl_sm_state),
    .snq_data_bypass_hit(gold_snq_data_bypass_hit),
    .vb_biu_aw_addr(gold_vb_biu_aw_addr),
    .vb_biu_aw_bar(gold_vb_biu_aw_bar),
    .vb_biu_aw_burst(gold_vb_biu_aw_burst),
    .vb_biu_aw_cache(gold_vb_biu_aw_cache),
    .vb_biu_aw_domain(gold_vb_biu_aw_domain),
    .vb_biu_aw_dp_req(gold_vb_biu_aw_dp_req),
    .vb_biu_aw_id(gold_vb_biu_aw_id),
    .vb_biu_aw_len(gold_vb_biu_aw_len),
    .vb_biu_aw_lock(gold_vb_biu_aw_lock),
    .vb_biu_aw_prot(gold_vb_biu_aw_prot),
    .vb_biu_aw_req(gold_vb_biu_aw_req),
    .vb_biu_aw_req_gateclk_en(gold_vb_biu_aw_req_gateclk_en),
    .vb_biu_aw_size(gold_vb_biu_aw_size),
    .vb_biu_aw_snoop(gold_vb_biu_aw_snoop),
    .vb_biu_aw_unique(gold_vb_biu_aw_unique),
    .vb_biu_aw_user(gold_vb_biu_aw_user),
    .vb_biu_w_data(gold_vb_biu_w_data),
    .vb_biu_w_id(gold_vb_biu_w_id),
    .vb_biu_w_last(gold_vb_biu_w_last),
    .vb_biu_w_req(gold_vb_biu_w_req),
    .vb_biu_w_strb(gold_vb_biu_w_strb),
    .vb_biu_w_vld(gold_vb_biu_w_vld),
    .vb_data_entry_biu_req_success(gold_vb_data_entry_biu_req_success),
    .vb_data_entry_create_dp_vld(gold_vb_data_entry_create_dp_vld),
    .vb_data_entry_create_gateclk_en(gold_vb_data_entry_create_gateclk_en),
    .vb_data_entry_create_vld(gold_vb_data_entry_create_vld),
    .vb_data_entry_wd_sm_grnt(gold_vb_data_entry_wd_sm_grnt),
    .vb_dcache_arb_borrow_addr(gold_vb_dcache_arb_borrow_addr),
    .vb_dcache_arb_data_way(gold_vb_dcache_arb_data_way),
    .vb_dcache_arb_dcache_replace(gold_vb_dcache_arb_dcache_replace),
    .vb_dcache_arb_ld_borrow_req(gold_vb_dcache_arb_ld_borrow_req),
    .vb_dcache_arb_ld_borrow_req_gate(gold_vb_dcache_arb_ld_borrow_req_gate),
    .vb_dcache_arb_ld_data_gateclk_en(gold_vb_dcache_arb_ld_data_gateclk_en),
    .vb_dcache_arb_ld_data_idx(gold_vb_dcache_arb_ld_data_idx),
    .vb_dcache_arb_ld_req(gold_vb_dcache_arb_ld_req),
    .vb_dcache_arb_ld_tag_gateclk_en(gold_vb_dcache_arb_ld_tag_gateclk_en),
    .vb_dcache_arb_ld_tag_idx(gold_vb_dcache_arb_ld_tag_idx),
    .vb_dcache_arb_ld_tag_req(gold_vb_dcache_arb_ld_tag_req),
    .vb_dcache_arb_ld_tag_wen(gold_vb_dcache_arb_ld_tag_wen),
    .vb_dcache_arb_serial_req(gold_vb_dcache_arb_serial_req),
    .vb_dcache_arb_set_way_mode(gold_vb_dcache_arb_set_way_mode),
    .vb_dcache_arb_st_borrow_req(gold_vb_dcache_arb_st_borrow_req),
    .vb_dcache_arb_st_dirty_din(gold_vb_dcache_arb_st_dirty_din),
    .vb_dcache_arb_st_dirty_gateclk_en(gold_vb_dcache_arb_st_dirty_gateclk_en),
    .vb_dcache_arb_st_dirty_gwen(gold_vb_dcache_arb_st_dirty_gwen),
    .vb_dcache_arb_st_dirty_idx(gold_vb_dcache_arb_st_dirty_idx),
    .vb_dcache_arb_st_dirty_req(gold_vb_dcache_arb_st_dirty_req),
    .vb_dcache_arb_st_dirty_wen(gold_vb_dcache_arb_st_dirty_wen),
    .vb_dcache_arb_st_req(gold_vb_dcache_arb_st_req),
    .vb_dcache_arb_st_tag_gateclk_en(gold_vb_dcache_arb_st_tag_gateclk_en),
    .vb_dcache_arb_st_tag_idx(gold_vb_dcache_arb_st_tag_idx),
    .vb_dcache_arb_st_tag_req(gold_vb_dcache_arb_st_tag_req),
    .vb_empty(gold_vb_empty),
    .vb_icc_create_grnt(gold_vb_icc_create_grnt),
    .vb_invalid_vld(gold_vb_invalid_vld),
    .vb_lfb_addr_entry_rcl_done(gold_vb_lfb_addr_entry_rcl_done),
    .vb_lfb_create_grnt(gold_vb_lfb_create_grnt),
    .vb_lfb_dcache_dirty(gold_vb_lfb_dcache_dirty),
    .vb_lfb_dcache_hit(gold_vb_lfb_dcache_hit),
    .vb_lfb_dcache_way(gold_vb_lfb_dcache_way),
    .vb_lfb_rcl_done(gold_vb_lfb_rcl_done),
    .vb_lfb_vb_req_hit_idx(gold_vb_lfb_vb_req_hit_idx),
    .vb_pfu_biu_req_hit_idx(gold_vb_pfu_biu_req_hit_idx),
    .vb_rb_biu_req_hit_idx(gold_vb_rb_biu_req_hit_idx),
    .vb_rcl_sm_addr_id(gold_vb_rcl_sm_addr_id),
    .vb_rcl_sm_data_dcache_dirty(gold_vb_rcl_sm_data_dcache_dirty),
    .vb_rcl_sm_data_id(gold_vb_rcl_sm_data_id),
    .vb_rcl_sm_data_set_data_done(gold_vb_rcl_sm_data_set_data_done),
    .vb_rcl_sm_inv(gold_vb_rcl_sm_inv),
    .vb_rcl_sm_lfb_create(gold_vb_rcl_sm_lfb_create),
    .vb_snq_bypass_db_id(gold_vb_snq_bypass_db_id),
    .vb_snq_bypass_hit(gold_vb_snq_bypass_hit),
    .vb_snq_depd(gold_vb_snq_depd),
    .vb_snq_depd_remove(gold_vb_snq_depd_remove),
    .vb_snq_start_hit_idx(gold_vb_snq_start_hit_idx),
    .vb_snq_wait_remove(gold_vb_snq_wait_remove),
    .vb_snq_wait_vb_id(gold_vb_snq_wait_vb_id),
    .vb_wd_sm_data_bias(gold_vb_wd_sm_data_bias),
    .vb_wd_sm_data_pop_req(gold_vb_wd_sm_data_pop_req),
    .vb_wmb_create_grnt(gold_vb_wmb_create_grnt),
    .vb_wmb_empty(gold_vb_wmb_empty),
    .vb_wmb_entry_rcl_done(gold_vb_wmb_entry_rcl_done),
    .vb_wmb_write_req_hit_idx(gold_vb_wmb_write_req_hit_idx),
    .victim_addr(gold_victim_addr)
  );
  ct_lsu_vb_gate gate_i (
    .biu_lsu_b_id(biu_lsu_b_id),
    .biu_lsu_b_vld(biu_lsu_b_vld),
    .bus_arb_vb_aw_grnt(bus_arb_vb_aw_grnt),
    .bus_arb_vb_w_grnt(bus_arb_vb_w_grnt),
    .cp0_lsu_icg_en(cp0_lsu_icg_en),
    .cp0_yy_clk_en(cp0_yy_clk_en),
    .cpurst_b(cpurst_b),
    .dcache_arb_vb_ld_grnt(dcache_arb_vb_ld_grnt),
    .dcache_arb_vb_st_grnt(dcache_arb_vb_st_grnt),
    .icc_vb_addr_tto6(icc_vb_addr_tto6),
    .icc_vb_create_dp_vld(icc_vb_create_dp_vld),
    .icc_vb_create_gateclk_en(icc_vb_create_gateclk_en),
    .icc_vb_create_req(icc_vb_create_req),
    .icc_vb_create_vld(icc_vb_create_vld),
    .icc_vb_inv(icc_vb_inv),
    .ld_da_vb_snq_data_reissue(ld_da_vb_snq_data_reissue),
    .lfb_vb_addr_tto6(lfb_vb_addr_tto6),
    .lfb_vb_create_dp_vld(lfb_vb_create_dp_vld),
    .lfb_vb_create_gateclk_en(lfb_vb_create_gateclk_en),
    .lfb_vb_create_req(lfb_vb_create_req),
    .lfb_vb_create_vld(lfb_vb_create_vld),
    .lfb_vb_id(lfb_vb_id),
    .lsu_special_clk(lsu_special_clk),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
    .pfu_biu_req_addr(pfu_biu_req_addr),
    .rb_biu_req_addr(rb_biu_req_addr),
    .snq_bypass_addr_tto6(snq_bypass_addr_tto6),
    .snq_create_addr(snq_create_addr),
    .snq_depd_vb_id(snq_depd_vb_id),
    .snq_vb_bypass_check(snq_vb_bypass_check),
    .st_da_dcache_dirty(st_da_dcache_dirty),
    .st_da_dcache_hit(st_da_dcache_hit),
    .st_da_dcache_miss(st_da_dcache_miss),
    .st_da_dcache_replace_dirty(st_da_dcache_replace_dirty),
    .st_da_dcache_replace_valid(st_da_dcache_replace_valid),
    .st_da_dcache_replace_way(st_da_dcache_replace_way),
    .st_da_dcache_way(st_da_dcache_way),
    .st_da_vb_ecc_err(st_da_vb_ecc_err),
    .st_da_vb_ecc_stall(st_da_vb_ecc_stall),
    .st_da_vb_feedback_addr_tto14(st_da_vb_feedback_addr_tto14),
    .st_da_vb_tag_reissue(st_da_vb_tag_reissue),
    .vb_data_entry_addr_id_0(vb_data_entry_addr_id_0),
    .vb_data_entry_addr_id_1(vb_data_entry_addr_id_1),
    .vb_data_entry_addr_id_2(vb_data_entry_addr_id_2),
    .vb_data_entry_biu_req(vb_data_entry_biu_req),
    .vb_data_entry_bypass_pop(vb_data_entry_bypass_pop),
    .vb_data_entry_dirty(vb_data_entry_dirty),
    .vb_data_entry_inv(vb_data_entry_inv),
    .vb_data_entry_lfb_create(vb_data_entry_lfb_create),
    .vb_data_entry_normal_pop(vb_data_entry_normal_pop),
    .vb_data_entry_req_success(vb_data_entry_req_success),
    .vb_data_entry_vld(vb_data_entry_vld),
    .vb_data_entry_wd_sm_req(vb_data_entry_wd_sm_req),
    .vb_data_entry_write_data128_0(vb_data_entry_write_data128_0),
    .vb_data_entry_write_data128_1(vb_data_entry_write_data128_1),
    .vb_data_entry_write_data128_2(vb_data_entry_write_data128_2),
    .vb_sdb_data_entry_vld(vb_sdb_data_entry_vld),
    .wmb_vb_addr_tto6(wmb_vb_addr_tto6),
    .wmb_vb_create_dp_vld(wmb_vb_create_dp_vld),
    .wmb_vb_create_gateclk_en(wmb_vb_create_gateclk_en),
    .wmb_vb_create_req(wmb_vb_create_req),
    .wmb_vb_create_vld(wmb_vb_create_vld),
    .wmb_vb_inv(wmb_vb_inv),
    .wmb_vb_set_way_mode(wmb_vb_set_way_mode),
    .wmb_write_ptr_encode(wmb_write_ptr_encode),
    .wmb_write_req_addr(wmb_write_req_addr),
    .lsu_had_vb_addr_entry_vld(gate_lsu_had_vb_addr_entry_vld),
    .lsu_had_vb_data_entry_vld(gate_lsu_had_vb_data_entry_vld),
    .lsu_had_vb_rcl_sm_state(gate_lsu_had_vb_rcl_sm_state),
    .snq_data_bypass_hit(gate_snq_data_bypass_hit),
    .vb_biu_aw_addr(gate_vb_biu_aw_addr),
    .vb_biu_aw_bar(gate_vb_biu_aw_bar),
    .vb_biu_aw_burst(gate_vb_biu_aw_burst),
    .vb_biu_aw_cache(gate_vb_biu_aw_cache),
    .vb_biu_aw_domain(gate_vb_biu_aw_domain),
    .vb_biu_aw_dp_req(gate_vb_biu_aw_dp_req),
    .vb_biu_aw_id(gate_vb_biu_aw_id),
    .vb_biu_aw_len(gate_vb_biu_aw_len),
    .vb_biu_aw_lock(gate_vb_biu_aw_lock),
    .vb_biu_aw_prot(gate_vb_biu_aw_prot),
    .vb_biu_aw_req(gate_vb_biu_aw_req),
    .vb_biu_aw_req_gateclk_en(gate_vb_biu_aw_req_gateclk_en),
    .vb_biu_aw_size(gate_vb_biu_aw_size),
    .vb_biu_aw_snoop(gate_vb_biu_aw_snoop),
    .vb_biu_aw_unique(gate_vb_biu_aw_unique),
    .vb_biu_aw_user(gate_vb_biu_aw_user),
    .vb_biu_w_data(gate_vb_biu_w_data),
    .vb_biu_w_id(gate_vb_biu_w_id),
    .vb_biu_w_last(gate_vb_biu_w_last),
    .vb_biu_w_req(gate_vb_biu_w_req),
    .vb_biu_w_strb(gate_vb_biu_w_strb),
    .vb_biu_w_vld(gate_vb_biu_w_vld),
    .vb_data_entry_biu_req_success(gate_vb_data_entry_biu_req_success),
    .vb_data_entry_create_dp_vld(gate_vb_data_entry_create_dp_vld),
    .vb_data_entry_create_gateclk_en(gate_vb_data_entry_create_gateclk_en),
    .vb_data_entry_create_vld(gate_vb_data_entry_create_vld),
    .vb_data_entry_wd_sm_grnt(gate_vb_data_entry_wd_sm_grnt),
    .vb_dcache_arb_borrow_addr(gate_vb_dcache_arb_borrow_addr),
    .vb_dcache_arb_data_way(gate_vb_dcache_arb_data_way),
    .vb_dcache_arb_dcache_replace(gate_vb_dcache_arb_dcache_replace),
    .vb_dcache_arb_ld_borrow_req(gate_vb_dcache_arb_ld_borrow_req),
    .vb_dcache_arb_ld_borrow_req_gate(gate_vb_dcache_arb_ld_borrow_req_gate),
    .vb_dcache_arb_ld_data_gateclk_en(gate_vb_dcache_arb_ld_data_gateclk_en),
    .vb_dcache_arb_ld_data_idx(gate_vb_dcache_arb_ld_data_idx),
    .vb_dcache_arb_ld_req(gate_vb_dcache_arb_ld_req),
    .vb_dcache_arb_ld_tag_gateclk_en(gate_vb_dcache_arb_ld_tag_gateclk_en),
    .vb_dcache_arb_ld_tag_idx(gate_vb_dcache_arb_ld_tag_idx),
    .vb_dcache_arb_ld_tag_req(gate_vb_dcache_arb_ld_tag_req),
    .vb_dcache_arb_ld_tag_wen(gate_vb_dcache_arb_ld_tag_wen),
    .vb_dcache_arb_serial_req(gate_vb_dcache_arb_serial_req),
    .vb_dcache_arb_set_way_mode(gate_vb_dcache_arb_set_way_mode),
    .vb_dcache_arb_st_borrow_req(gate_vb_dcache_arb_st_borrow_req),
    .vb_dcache_arb_st_dirty_din(gate_vb_dcache_arb_st_dirty_din),
    .vb_dcache_arb_st_dirty_gateclk_en(gate_vb_dcache_arb_st_dirty_gateclk_en),
    .vb_dcache_arb_st_dirty_gwen(gate_vb_dcache_arb_st_dirty_gwen),
    .vb_dcache_arb_st_dirty_idx(gate_vb_dcache_arb_st_dirty_idx),
    .vb_dcache_arb_st_dirty_req(gate_vb_dcache_arb_st_dirty_req),
    .vb_dcache_arb_st_dirty_wen(gate_vb_dcache_arb_st_dirty_wen),
    .vb_dcache_arb_st_req(gate_vb_dcache_arb_st_req),
    .vb_dcache_arb_st_tag_gateclk_en(gate_vb_dcache_arb_st_tag_gateclk_en),
    .vb_dcache_arb_st_tag_idx(gate_vb_dcache_arb_st_tag_idx),
    .vb_dcache_arb_st_tag_req(gate_vb_dcache_arb_st_tag_req),
    .vb_empty(gate_vb_empty),
    .vb_icc_create_grnt(gate_vb_icc_create_grnt),
    .vb_invalid_vld(gate_vb_invalid_vld),
    .vb_lfb_addr_entry_rcl_done(gate_vb_lfb_addr_entry_rcl_done),
    .vb_lfb_create_grnt(gate_vb_lfb_create_grnt),
    .vb_lfb_dcache_dirty(gate_vb_lfb_dcache_dirty),
    .vb_lfb_dcache_hit(gate_vb_lfb_dcache_hit),
    .vb_lfb_dcache_way(gate_vb_lfb_dcache_way),
    .vb_lfb_rcl_done(gate_vb_lfb_rcl_done),
    .vb_lfb_vb_req_hit_idx(gate_vb_lfb_vb_req_hit_idx),
    .vb_pfu_biu_req_hit_idx(gate_vb_pfu_biu_req_hit_idx),
    .vb_rb_biu_req_hit_idx(gate_vb_rb_biu_req_hit_idx),
    .vb_rcl_sm_addr_id(gate_vb_rcl_sm_addr_id),
    .vb_rcl_sm_data_dcache_dirty(gate_vb_rcl_sm_data_dcache_dirty),
    .vb_rcl_sm_data_id(gate_vb_rcl_sm_data_id),
    .vb_rcl_sm_data_set_data_done(gate_vb_rcl_sm_data_set_data_done),
    .vb_rcl_sm_inv(gate_vb_rcl_sm_inv),
    .vb_rcl_sm_lfb_create(gate_vb_rcl_sm_lfb_create),
    .vb_snq_bypass_db_id(gate_vb_snq_bypass_db_id),
    .vb_snq_bypass_hit(gate_vb_snq_bypass_hit),
    .vb_snq_depd(gate_vb_snq_depd),
    .vb_snq_depd_remove(gate_vb_snq_depd_remove),
    .vb_snq_start_hit_idx(gate_vb_snq_start_hit_idx),
    .vb_snq_wait_remove(gate_vb_snq_wait_remove),
    .vb_snq_wait_vb_id(gate_vb_snq_wait_vb_id),
    .vb_wd_sm_data_bias(gate_vb_wd_sm_data_bias),
    .vb_wd_sm_data_pop_req(gate_vb_wd_sm_data_pop_req),
    .vb_wmb_create_grnt(gate_vb_wmb_create_grnt),
    .vb_wmb_empty(gate_vb_wmb_empty),
    .vb_wmb_entry_rcl_done(gate_vb_wmb_entry_rcl_done),
    .vb_wmb_write_req_hit_idx(gate_vb_wmb_write_req_hit_idx),
    .victim_addr(gate_victim_addr)
  );
  always @(*) begin
    if (cpurst_b) begin
      assert(gold_lsu_had_vb_addr_entry_vld == gate_lsu_had_vb_addr_entry_vld);
      assert(gold_lsu_had_vb_data_entry_vld == gate_lsu_had_vb_data_entry_vld);
      assert(gold_lsu_had_vb_rcl_sm_state == gate_lsu_had_vb_rcl_sm_state);
      assert(gold_snq_data_bypass_hit == gate_snq_data_bypass_hit);
      assert(gold_vb_biu_aw_addr == gate_vb_biu_aw_addr);
      assert(gold_vb_biu_aw_bar == gate_vb_biu_aw_bar);
      assert(gold_vb_biu_aw_burst == gate_vb_biu_aw_burst);
      assert(gold_vb_biu_aw_cache == gate_vb_biu_aw_cache);
      assert(gold_vb_biu_aw_domain == gate_vb_biu_aw_domain);
      assert(gold_vb_biu_aw_dp_req == gate_vb_biu_aw_dp_req);
      assert(gold_vb_biu_aw_id == gate_vb_biu_aw_id);
      assert(gold_vb_biu_aw_len == gate_vb_biu_aw_len);
      assert(gold_vb_biu_aw_lock == gate_vb_biu_aw_lock);
      assert(gold_vb_biu_aw_prot == gate_vb_biu_aw_prot);
      assert(gold_vb_biu_aw_req == gate_vb_biu_aw_req);
      assert(gold_vb_biu_aw_req_gateclk_en == gate_vb_biu_aw_req_gateclk_en);
      assert(gold_vb_biu_aw_size == gate_vb_biu_aw_size);
      assert(gold_vb_biu_aw_snoop == gate_vb_biu_aw_snoop);
      assert(gold_vb_biu_aw_unique == gate_vb_biu_aw_unique);
      assert(gold_vb_biu_aw_user == gate_vb_biu_aw_user);
      assert(gold_vb_biu_w_data == gate_vb_biu_w_data);
      assert(gold_vb_biu_w_id == gate_vb_biu_w_id);
      assert(gold_vb_biu_w_last == gate_vb_biu_w_last);
      assert(gold_vb_biu_w_req == gate_vb_biu_w_req);
      assert(gold_vb_biu_w_strb == gate_vb_biu_w_strb);
      assert(gold_vb_biu_w_vld == gate_vb_biu_w_vld);
      assert(gold_vb_data_entry_biu_req_success == gate_vb_data_entry_biu_req_success);
      assert(gold_vb_data_entry_create_dp_vld == gate_vb_data_entry_create_dp_vld);
      assert(gold_vb_data_entry_create_gateclk_en == gate_vb_data_entry_create_gateclk_en);
      assert(gold_vb_data_entry_create_vld == gate_vb_data_entry_create_vld);
      assert(gold_vb_data_entry_wd_sm_grnt == gate_vb_data_entry_wd_sm_grnt);
      assert(gold_vb_dcache_arb_borrow_addr == gate_vb_dcache_arb_borrow_addr);
      assert(gold_vb_dcache_arb_data_way == gate_vb_dcache_arb_data_way);
      assert(gold_vb_dcache_arb_dcache_replace == gate_vb_dcache_arb_dcache_replace);
      assert(gold_vb_dcache_arb_ld_borrow_req == gate_vb_dcache_arb_ld_borrow_req);
      assert(gold_vb_dcache_arb_ld_borrow_req_gate == gate_vb_dcache_arb_ld_borrow_req_gate);
      assert(gold_vb_dcache_arb_ld_data_gateclk_en == gate_vb_dcache_arb_ld_data_gateclk_en);
      assert(gold_vb_dcache_arb_ld_data_idx == gate_vb_dcache_arb_ld_data_idx);
      assert(gold_vb_dcache_arb_ld_req == gate_vb_dcache_arb_ld_req);
      assert(gold_vb_dcache_arb_ld_tag_gateclk_en == gate_vb_dcache_arb_ld_tag_gateclk_en);
      assert(gold_vb_dcache_arb_ld_tag_idx == gate_vb_dcache_arb_ld_tag_idx);
      assert(gold_vb_dcache_arb_ld_tag_req == gate_vb_dcache_arb_ld_tag_req);
      assert(gold_vb_dcache_arb_ld_tag_wen == gate_vb_dcache_arb_ld_tag_wen);
      assert(gold_vb_dcache_arb_serial_req == gate_vb_dcache_arb_serial_req);
      assert(gold_vb_dcache_arb_set_way_mode == gate_vb_dcache_arb_set_way_mode);
      assert(gold_vb_dcache_arb_st_borrow_req == gate_vb_dcache_arb_st_borrow_req);
      assert(gold_vb_dcache_arb_st_dirty_din == gate_vb_dcache_arb_st_dirty_din);
      assert(gold_vb_dcache_arb_st_dirty_gateclk_en == gate_vb_dcache_arb_st_dirty_gateclk_en);
      assert(gold_vb_dcache_arb_st_dirty_gwen == gate_vb_dcache_arb_st_dirty_gwen);
      assert(gold_vb_dcache_arb_st_dirty_idx == gate_vb_dcache_arb_st_dirty_idx);
      assert(gold_vb_dcache_arb_st_dirty_req == gate_vb_dcache_arb_st_dirty_req);
      assert(gold_vb_dcache_arb_st_dirty_wen == gate_vb_dcache_arb_st_dirty_wen);
      assert(gold_vb_dcache_arb_st_req == gate_vb_dcache_arb_st_req);
      assert(gold_vb_dcache_arb_st_tag_gateclk_en == gate_vb_dcache_arb_st_tag_gateclk_en);
      assert(gold_vb_dcache_arb_st_tag_idx == gate_vb_dcache_arb_st_tag_idx);
      assert(gold_vb_dcache_arb_st_tag_req == gate_vb_dcache_arb_st_tag_req);
      assert(gold_vb_empty == gate_vb_empty);
      assert(gold_vb_icc_create_grnt == gate_vb_icc_create_grnt);
      assert(gold_vb_invalid_vld == gate_vb_invalid_vld);
      assert(gold_vb_lfb_addr_entry_rcl_done == gate_vb_lfb_addr_entry_rcl_done);
      assert(gold_vb_lfb_create_grnt == gate_vb_lfb_create_grnt);
      assert(gold_vb_lfb_dcache_dirty == gate_vb_lfb_dcache_dirty);
      assert(gold_vb_lfb_dcache_hit == gate_vb_lfb_dcache_hit);
      assert(gold_vb_lfb_dcache_way == gate_vb_lfb_dcache_way);
      assert(gold_vb_lfb_rcl_done == gate_vb_lfb_rcl_done);
      assert(gold_vb_lfb_vb_req_hit_idx == gate_vb_lfb_vb_req_hit_idx);
      assert(gold_vb_pfu_biu_req_hit_idx == gate_vb_pfu_biu_req_hit_idx);
      assert(gold_vb_rb_biu_req_hit_idx == gate_vb_rb_biu_req_hit_idx);
      assert(gold_vb_rcl_sm_addr_id == gate_vb_rcl_sm_addr_id);
      assert(gold_vb_rcl_sm_data_dcache_dirty == gate_vb_rcl_sm_data_dcache_dirty);
      assert(gold_vb_rcl_sm_data_id == gate_vb_rcl_sm_data_id);
      assert(gold_vb_rcl_sm_data_set_data_done == gate_vb_rcl_sm_data_set_data_done);
      assert(gold_vb_rcl_sm_inv == gate_vb_rcl_sm_inv);
      assert(gold_vb_rcl_sm_lfb_create == gate_vb_rcl_sm_lfb_create);
      assert(gold_vb_snq_bypass_db_id == gate_vb_snq_bypass_db_id);
      assert(gold_vb_snq_bypass_hit == gate_vb_snq_bypass_hit);
      assert(gold_vb_snq_depd == gate_vb_snq_depd);
      assert(gold_vb_snq_depd_remove == gate_vb_snq_depd_remove);
      assert(gold_vb_snq_start_hit_idx == gate_vb_snq_start_hit_idx);
      assert(gold_vb_snq_wait_remove == gate_vb_snq_wait_remove);
      assert(gold_vb_snq_wait_vb_id == gate_vb_snq_wait_vb_id);
      assert(gold_vb_wd_sm_data_bias == gate_vb_wd_sm_data_bias);
      assert(gold_vb_wd_sm_data_pop_req == gate_vb_wd_sm_data_pop_req);
      assert(gold_vb_wmb_create_grnt == gate_vb_wmb_create_grnt);
      assert(gold_vb_wmb_empty == gate_vb_wmb_empty);
      assert(gold_vb_wmb_entry_rcl_done == gate_vb_wmb_entry_rcl_done);
      assert(gold_vb_wmb_write_req_hit_idx == gate_vb_wmb_write_req_hit_idx);
      assert(gold_victim_addr == gate_victim_addr);
    end
  end
endmodule
