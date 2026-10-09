# Inspect the worst setup paths of the framework's HDMI clock on the finished compile (analysis only, no rebuild).
# Run: quartus_sta -t tools/report_hdmi_paths.tcl
project_open Arcade-Sauro
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 6 -detail summary -panel_name "hdmi setup" -to_clock [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}] -file output_files/hdmi_setup_paths.rpt
delete_timing_netlist
project_close
