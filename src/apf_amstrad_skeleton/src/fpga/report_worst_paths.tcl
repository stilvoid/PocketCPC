project_open ap_core
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 20 -detail full_path -file output_files/worst_setup_paths.rpt
delete_timing_netlist
project_close
