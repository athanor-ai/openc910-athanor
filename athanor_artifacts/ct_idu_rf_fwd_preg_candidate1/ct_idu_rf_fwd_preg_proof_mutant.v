module ct_idu_rf_fwd_preg(
  iu_idu_ex1_pipe0_fwd_preg,
  iu_idu_ex1_pipe0_fwd_preg_data,
  iu_idu_ex1_pipe0_fwd_preg_vld,
  iu_idu_ex1_pipe1_fwd_preg,
  iu_idu_ex1_pipe1_fwd_preg_data,
  iu_idu_ex1_pipe1_fwd_preg_vld,
  iu_idu_ex2_pipe0_wb_preg,
  iu_idu_ex2_pipe0_wb_preg_data,
  iu_idu_ex2_pipe0_wb_preg_vld,
  iu_idu_ex2_pipe1_wb_preg,
  iu_idu_ex2_pipe1_wb_preg_data,
  iu_idu_ex2_pipe1_wb_preg_vld,
  lsu_idu_da_pipe3_fwd_preg,
  lsu_idu_da_pipe3_fwd_preg_data,
  lsu_idu_da_pipe3_fwd_preg_vld,
  lsu_idu_wb_pipe3_wb_preg,
  lsu_idu_wb_pipe3_wb_preg_data,
  lsu_idu_wb_pipe3_wb_preg_vld,
  x_src_data,
  x_src_no_fwd,
  x_src_reg
);
input [6:0] iu_idu_ex1_pipe0_fwd_preg;
input [63:0] iu_idu_ex1_pipe0_fwd_preg_data;
input iu_idu_ex1_pipe0_fwd_preg_vld;
input [6:0] iu_idu_ex1_pipe1_fwd_preg;
input [63:0] iu_idu_ex1_pipe1_fwd_preg_data;
input iu_idu_ex1_pipe1_fwd_preg_vld;
input [6:0] iu_idu_ex2_pipe0_wb_preg;
input [63:0] iu_idu_ex2_pipe0_wb_preg_data;
input iu_idu_ex2_pipe0_wb_preg_vld;
input [6:0] iu_idu_ex2_pipe1_wb_preg;
input [63:0] iu_idu_ex2_pipe1_wb_preg_data;
input iu_idu_ex2_pipe1_wb_preg_vld;
input [6:0] lsu_idu_da_pipe3_fwd_preg;
input [63:0] lsu_idu_da_pipe3_fwd_preg_data;
input lsu_idu_da_pipe3_fwd_preg_vld;
input [6:0] lsu_idu_wb_pipe3_wb_preg;
input [63:0] lsu_idu_wb_pipe3_wb_preg_data;
input lsu_idu_wb_pipe3_wb_preg_vld;
output [63:0] x_src_data;
output x_src_no_fwd;
input [6:0] x_src_reg;
wire [5:0] fwd_src_sel;
assign fwd_src_sel[0] = iu_idu_ex1_pipe0_fwd_preg_vld && (x_src_reg[6:0] == iu_idu_ex1_pipe0_fwd_preg[6:0]);
assign fwd_src_sel[1] = iu_idu_ex2_pipe0_wb_preg_vld && (x_src_reg[6:0] == iu_idu_ex2_pipe0_wb_preg[6:0]);
assign fwd_src_sel[2] = iu_idu_ex1_pipe1_fwd_preg_vld && (x_src_reg[6:0] == iu_idu_ex1_pipe1_fwd_preg[6:0]);
assign fwd_src_sel[3] = iu_idu_ex2_pipe1_wb_preg_vld && (x_src_reg[6:0] == iu_idu_ex2_pipe1_wb_preg[6:0]);
assign fwd_src_sel[4] = lsu_idu_da_pipe3_fwd_preg_vld && (x_src_reg[6:0] == lsu_idu_da_pipe3_fwd_preg[6:0]);
assign fwd_src_sel[5] = lsu_idu_wb_pipe3_wb_preg_vld && (x_src_reg[6:0] == lsu_idu_wb_pipe3_wb_preg[6:0]);
assign x_src_no_fwd = !(|fwd_src_sel[5:0]);
assign x_src_data[63:0] =
    ({64{fwd_src_sel[0]}} & iu_idu_ex1_pipe0_fwd_preg_data[63:0])
  |
    ({64{fwd_src_sel[1]}} & iu_idu_ex1_pipe0_fwd_preg_data[63:0])
  |
    ({64{fwd_src_sel[2]}} & iu_idu_ex1_pipe1_fwd_preg_data[63:0])
  |
    ({64{fwd_src_sel[3]}} & iu_idu_ex2_pipe1_wb_preg_data[63:0])
  |
    ({64{fwd_src_sel[4]}} & lsu_idu_da_pipe3_fwd_preg_data[63:0])
  |
    ({64{fwd_src_sel[5]}} & lsu_idu_wb_pipe3_wb_preg_data[63:0])
  ;
endmodule
