# Scoped constraints for xpm_cdc_handshake
set source_clk  [get_clocks -quiet -of [get_ports clk_in]]
set dest_clk [get_clocks -quiet -of [get_ports clk_out]]

set source_clk_period  [get_property -quiet -min PERIOD $source_clk]
set dest_clk_period [get_property -quiet -min PERIOD $dest_clk]

#set xpm_cdc_hs_width [llength [get_cells dest_hsdata_ff_reg[*]]]
#set xpm_cdc_hs_num_s2d_dsync_ff [llength [get_cells xpm_cdc_single_src2dest_inst/syncstages_ff_reg[*]]]

if {$source_clk == ""} {
    set source_clk_period 1000
}

if {$dest_clk == ""} {
    set dest_clk_period 1001
}

if {$source_clk != $dest_clk} {
   set_false_path -to [get_cells si0*_reg*]
   set_false_path -to [get_cells so0*_reg*]
   set_max_delay -from $source_clk -to [get_cells dout*_reg*] $dest_clk_period -datapath_only
} elseif {$src_clk != "" && $dest_clk != ""} {
    common::send_msg_id "XPM_CDC_HANDSHAKE: TCL-1000" "WARNING" "The source and destination clocks are the same. \n     Instance: [current_instance .] \n  This will add unnecessary latency to the design. Please check the design for the following: \n 1) Manually instantiated XPM_CDC modules: Xilinx recommends that you remove these modules. \n 2) Xilinx IP that contains XPM_CDC modules: Verify the connections to the IP to determine whether you can safely ignore this message."
}
