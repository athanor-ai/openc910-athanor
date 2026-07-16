read_liberty {sky130_fd_sc_hd__tt_025C_1v80.lib}
read_verilog {ct_fadd_onehot_sel_h_gate.mapped.v}
link_design ct_fadd_onehot_sel_h
create_clock -period 10.0 -name virtual_clk
foreach p [all_inputs] { set_input_delay 0.0 -clock virtual_clk $p }
foreach p [all_outputs] { set_output_delay 0.0 -clock virtual_clk $p }
set_power_activity -global -activity 0.1 -duty 0.5
report_checks -path_delay max -format full_clock_expanded
report_tns
report_wns
report_power
exit
