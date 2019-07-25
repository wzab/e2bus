set_property IOSTANDARD LVCMOS33 [get_ports ref_clk]
set_property IOSTANDARD LVCMOS33 [get_ports phy_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports phy2rmii_crs_dv]
set_property IOSTANDARD LVCMOS33 [get_ports {phy2rmii_rxd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy2rmii_rxd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports rmii2phy_tx_en]
set_property IOSTANDARD LVCMOS33 [get_ports {rmii2phy_txd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rmii2phy_txd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports ext_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports led1]
set_property IOSTANDARD LVCMOS33 [get_ports phy_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports phy_mdio]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_scl]
set_property PACKAGE_PIN D4 [get_ports ref_clk]
set_property PACKAGE_PIN C3 [get_ports phy_rst_n]
set_property PACKAGE_PIN G5 [get_ports {phy2rmii_rxd[1]}]
set_property PACKAGE_PIN C7 [get_ports {phy2rmii_rxd[0]}]
set_property PACKAGE_PIN B4 [get_ports {rmii2phy_txd[1]}]
set_property PACKAGE_PIN D6 [get_ports {rmii2phy_txd[0]}]
set_property PACKAGE_PIN E6 [get_ports phy2rmii_crs_dv]
set_property PACKAGE_PIN A5 [get_ports rmii2phy_tx_en]
set_property PACKAGE_PIN A8 [get_ports ext_rst_n]
set_property PACKAGE_PIN C8 [get_ports led1]
set_property PACKAGE_PIN B7 [get_ports phy_mdc]
set_property PACKAGE_PIN B6 [get_ports phy_mdio]
set_property PACKAGE_PIN N13 [get_ports i2c_sda]
set_property PACKAGE_PIN N16 [get_ports i2c_scl]
set_property PULLUP true [get_ports phy_mdio]
set_property PULLUP true [get_ports phy_mdc]
set_property PULLUP true [get_ports i2c_sda]
set_property PULLUP true [get_ports i2c_scl]
create_clock -period 20.000 -name ref_clk -waveform {0.000 10.000} [get_ports ref_clk]
create_generated_clock -name mii_to_rmii_0_1/U0/rmii2mac_rx_clk -source [get_ports ref_clk] -divide_by 2 [get_pins mii_to_rmii_0_1/U0/rmii2mac_rx_clk_bi_reg/Q]
create_generated_clock -name mii_to_rmii_0_1/U0/rmii2mac_tx_clk -source [get_ports ref_clk] -divide_by 2 [get_pins mii_to_rmii_0_1/U0/rmii2mac_tx_clk_bi_reg/Q]
create_clock -period 40.000 -name VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_rx_clk -waveform {0.000 20.000}
set_input_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports i2c_*]
set_input_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports i2c_*]
set_input_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports {phy2rmii_rxd[*]}]
set_input_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports {phy2rmii_rxd[*]}]
set_input_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports phy2rmii_crs_dv]
set_input_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports phy2rmii_crs_dv]
set_input_delay -clock [get_clocks VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_rx_clk] -min -add_delay 0.000 [get_ports ext_rst_n]
set_input_delay -clock [get_clocks VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_rx_clk] -max -add_delay 6.000 [get_ports ext_rst_n]
set_input_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports ext_rst_n]
set_input_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports ext_rst_n]
create_clock -period 40.000 -name VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_tx_clk -waveform {0.000 20.000}
set_output_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports i2c_*]
set_output_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports i2c_*]
set_output_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports {rmii2phy_txd[*]}]
set_output_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports {rmii2phy_txd[*]}]
set_output_delay -clock [get_clocks VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_tx_clk] -min -add_delay 0.000 [get_ports led1]
set_output_delay -clock [get_clocks VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_tx_clk] -max -add_delay 6.000 [get_ports led1]
set_output_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports rmii2phy_tx_en]
set_output_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports rmii2phy_tx_en]


set_property MARK_DEBUG true [get_nets {e2bus_1/eth_receiver_1/RxD4_0[0]}]
set_property MARK_DEBUG true [get_nets {e2bus_1/eth_receiver_1/RxD4_0[2]}]
set_property MARK_DEBUG true [get_nets {e2bus_1/eth_receiver_1/RxD4_0[1]}]
set_property MARK_DEBUG true [get_nets {e2bus_1/eth_receiver_1/RxD4_0[3]}]

set_property DRIVE 8 [get_ports phy_mdc]
set_property DRIVE 8 [get_ports phy_mdio]
set_property DRIVE 8 [get_ports led1]
set_property DRIVE 8 [get_ports phy_rst_n]

set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
set_property PACKAGE_PIN N11 [get_ports sys_clk]





create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 1 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list mii_to_rmii_0_1/U0/rmii2mac_rx_clk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 5 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {e2bus_2/eth_receiver_1/dbg_state[0]} {e2bus_2/eth_receiver_1/dbg_state[1]} {e2bus_2/eth_receiver_1/dbg_state[2]} {e2bus_2/eth_receiver_1/dbg_state[3]} {e2bus_2/eth_receiver_1/dbg_state[4]}]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 1 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list mii_to_rmii_0_1/U0/rmii2mac_tx_clk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 32 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {wb_m2s[adr][0]} {wb_m2s[adr][1]} {wb_m2s[adr][2]} {wb_m2s[adr][3]} {wb_m2s[adr][4]} {wb_m2s[adr][5]} {wb_m2s[adr][6]} {wb_m2s[adr][7]} {wb_m2s[adr][8]} {wb_m2s[adr][9]} {wb_m2s[adr][10]} {wb_m2s[adr][11]} {wb_m2s[adr][12]} {wb_m2s[adr][13]} {wb_m2s[adr][14]} {wb_m2s[adr][15]} {wb_m2s[adr][16]} {wb_m2s[adr][17]} {wb_m2s[adr][18]} {wb_m2s[adr][19]} {wb_m2s[adr][20]} {wb_m2s[adr][21]} {wb_m2s[adr][22]} {wb_m2s[adr][23]} {wb_m2s[adr][24]} {wb_m2s[adr][25]} {wb_m2s[adr][26]} {wb_m2s[adr][27]} {wb_m2s[adr][28]} {wb_m2s[adr][29]} {wb_m2s[adr][30]} {wb_m2s[adr][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {e2bus_2/eth_receiver_1/dbg_crc32[0]} {e2bus_2/eth_receiver_1/dbg_crc32[1]} {e2bus_2/eth_receiver_1/dbg_crc32[2]} {e2bus_2/eth_receiver_1/dbg_crc32[3]} {e2bus_2/eth_receiver_1/dbg_crc32[4]} {e2bus_2/eth_receiver_1/dbg_crc32[5]} {e2bus_2/eth_receiver_1/dbg_crc32[6]} {e2bus_2/eth_receiver_1/dbg_crc32[7]} {e2bus_2/eth_receiver_1/dbg_crc32[8]} {e2bus_2/eth_receiver_1/dbg_crc32[9]} {e2bus_2/eth_receiver_1/dbg_crc32[10]} {e2bus_2/eth_receiver_1/dbg_crc32[11]} {e2bus_2/eth_receiver_1/dbg_crc32[12]} {e2bus_2/eth_receiver_1/dbg_crc32[13]} {e2bus_2/eth_receiver_1/dbg_crc32[14]} {e2bus_2/eth_receiver_1/dbg_crc32[15]} {e2bus_2/eth_receiver_1/dbg_crc32[16]} {e2bus_2/eth_receiver_1/dbg_crc32[17]} {e2bus_2/eth_receiver_1/dbg_crc32[18]} {e2bus_2/eth_receiver_1/dbg_crc32[19]} {e2bus_2/eth_receiver_1/dbg_crc32[20]} {e2bus_2/eth_receiver_1/dbg_crc32[21]} {e2bus_2/eth_receiver_1/dbg_crc32[22]} {e2bus_2/eth_receiver_1/dbg_crc32[23]} {e2bus_2/eth_receiver_1/dbg_crc32[24]} {e2bus_2/eth_receiver_1/dbg_crc32[25]} {e2bus_2/eth_receiver_1/dbg_crc32[26]} {e2bus_2/eth_receiver_1/dbg_crc32[27]} {e2bus_2/eth_receiver_1/dbg_crc32[28]} {e2bus_2/eth_receiver_1/dbg_crc32[29]} {e2bus_2/eth_receiver_1/dbg_crc32[30]} {e2bus_2/eth_receiver_1/dbg_crc32[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 8 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {e2bus_2/eth_receiver_1/RxD_0[0]} {e2bus_2/eth_receiver_1/RxD_0[1]} {e2bus_2/eth_receiver_1/RxD_0[2]} {e2bus_2/eth_receiver_1/RxD_0[3]} {e2bus_2/eth_receiver_1/RxD_0[4]} {e2bus_2/eth_receiver_1/RxD_0[5]} {e2bus_2/eth_receiver_1/RxD_0[6]} {e2bus_2/eth_receiver_1/RxD_0[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list e2bus_2/cb1.cmd_exec_1/bc_cmd_ack]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list e2bus_2/eth_receiver_1/Rx_Dv_0]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 3 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r[state][0]} {e2bus_2/cb1.cmd_exec_1/r[state][1]} {e2bus_2/cb1.cmd_exec_1/r[state][2]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 11 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][0]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][1]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][2]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][3]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][4]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][5]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][6]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][7]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][8]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][9]} {e2bus_2/cb1.cmd_exec_1/r[cmd_frame_ad][10]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 2 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r2[state][0]} {e2bus_2/cb1.cmd_exec_1/r2[state][1]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 8 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r2[resp_wrd_ad][0]} {e2bus_2/cb1.cmd_exec_1/r2[resp_wrd_ad][1]} {e2bus_2/cb1.cmd_exec_1/r2[resp_wrd_ad][2]} {e2bus_2/cb1.cmd_exec_1/r2[resp_wrd_ad][3]} {e2bus_2/cb1.cmd_exec_1/r2[resp_wrd_ad][4]} {e2bus_2/cb1.cmd_exec_1/r2[resp_wrd_ad][5]} {e2bus_2/cb1.cmd_exec_1/r2[resp_wrd_ad][6]} {e2bus_2/cb1.cmd_exec_1/r2[resp_wrd_ad][7]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
set_property port_width 9 [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r2[resp_len][0]} {e2bus_2/cb1.cmd_exec_1/r2[resp_len][1]} {e2bus_2/cb1.cmd_exec_1/r2[resp_len][2]} {e2bus_2/cb1.cmd_exec_1/r2[resp_len][3]} {e2bus_2/cb1.cmd_exec_1/r2[resp_len][4]} {e2bus_2/cb1.cmd_exec_1/r2[resp_len][5]} {e2bus_2/cb1.cmd_exec_1/r2[resp_len][6]} {e2bus_2/cb1.cmd_exec_1/r2[resp_len][7]} {e2bus_2/cb1.cmd_exec_1/r2[resp_len][8]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
set_property port_width 15 [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][0]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][1]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][2]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][3]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][4]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][5]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][6]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][7]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][8]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][9]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][10]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][11]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][12]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][13]} {e2bus_2/cb1.cmd_exec_1/r2[resp_frm_num][14]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
set_property port_width 13 [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list {e2bus_2/r1[cmd_frame_rd_ptr][0]} {e2bus_2/r1[cmd_frame_rd_ptr][1]} {e2bus_2/r1[cmd_frame_rd_ptr][2]} {e2bus_2/r1[cmd_frame_rd_ptr][3]} {e2bus_2/r1[cmd_frame_rd_ptr][4]} {e2bus_2/r1[cmd_frame_rd_ptr][5]} {e2bus_2/r1[cmd_frame_rd_ptr][6]} {e2bus_2/r1[cmd_frame_rd_ptr][7]} {e2bus_2/r1[cmd_frame_rd_ptr][8]} {e2bus_2/r1[cmd_frame_rd_ptr][9]} {e2bus_2/r1[cmd_frame_rd_ptr][10]} {e2bus_2/r1[cmd_frame_rd_ptr][11]} {e2bus_2/r1[cmd_frame_rd_ptr][12]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
set_property port_width 16 [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list {e2bus_2/r1[exp_pkt_num][0]} {e2bus_2/r1[exp_pkt_num][1]} {e2bus_2/r1[exp_pkt_num][2]} {e2bus_2/r1[exp_pkt_num][3]} {e2bus_2/r1[exp_pkt_num][4]} {e2bus_2/r1[exp_pkt_num][5]} {e2bus_2/r1[exp_pkt_num][6]} {e2bus_2/r1[exp_pkt_num][7]} {e2bus_2/r1[exp_pkt_num][8]} {e2bus_2/r1[exp_pkt_num][9]} {e2bus_2/r1[exp_pkt_num][10]} {e2bus_2/r1[exp_pkt_num][11]} {e2bus_2/r1[exp_pkt_num][12]} {e2bus_2/r1[exp_pkt_num][13]} {e2bus_2/r1[exp_pkt_num][14]} {e2bus_2/r1[exp_pkt_num][15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
set_property port_width 3 [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list {e2bus_2/r1[state][0]} {e2bus_2/r1[state][1]} {e2bus_2/r1[state][2]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe10]
set_property port_width 32 [get_debug_ports u_ila_1/probe10]
connect_debug_port u_ila_1/probe10 [get_nets [list {wb_s2m[dat][0]} {wb_s2m[dat][1]} {wb_s2m[dat][2]} {wb_s2m[dat][3]} {wb_s2m[dat][4]} {wb_s2m[dat][5]} {wb_s2m[dat][6]} {wb_s2m[dat][7]} {wb_s2m[dat][8]} {wb_s2m[dat][9]} {wb_s2m[dat][10]} {wb_s2m[dat][11]} {wb_s2m[dat][12]} {wb_s2m[dat][13]} {wb_s2m[dat][14]} {wb_s2m[dat][15]} {wb_s2m[dat][16]} {wb_s2m[dat][17]} {wb_s2m[dat][18]} {wb_s2m[dat][19]} {wb_s2m[dat][20]} {wb_s2m[dat][21]} {wb_s2m[dat][22]} {wb_s2m[dat][23]} {wb_s2m[dat][24]} {wb_s2m[dat][25]} {wb_s2m[dat][26]} {wb_s2m[dat][27]} {wb_s2m[dat][28]} {wb_s2m[dat][29]} {wb_s2m[dat][30]} {wb_s2m[dat][31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe11]
set_property port_width 32 [get_debug_ports u_ila_1/probe11]
connect_debug_port u_ila_1/probe11 [get_nets [list {wb_m2s[dat][0]} {wb_m2s[dat][1]} {wb_m2s[dat][2]} {wb_m2s[dat][3]} {wb_m2s[dat][4]} {wb_m2s[dat][5]} {wb_m2s[dat][6]} {wb_m2s[dat][7]} {wb_m2s[dat][8]} {wb_m2s[dat][9]} {wb_m2s[dat][10]} {wb_m2s[dat][11]} {wb_m2s[dat][12]} {wb_m2s[dat][13]} {wb_m2s[dat][14]} {wb_m2s[dat][15]} {wb_m2s[dat][16]} {wb_m2s[dat][17]} {wb_m2s[dat][18]} {wb_m2s[dat][19]} {wb_m2s[dat][20]} {wb_m2s[dat][21]} {wb_m2s[dat][22]} {wb_m2s[dat][23]} {wb_m2s[dat][24]} {wb_m2s[dat][25]} {wb_m2s[dat][26]} {wb_m2s[dat][27]} {wb_m2s[dat][28]} {wb_m2s[dat][29]} {wb_m2s[dat][30]} {wb_m2s[dat][31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe12]
set_property port_width 4 [get_debug_ports u_ila_1/probe12]
connect_debug_port u_ila_1/probe12 [get_nets [list {e2bus_2/resp_busy[0]} {e2bus_2/resp_busy[1]} {e2bus_2/resp_busy[2]} {e2bus_2/resp_busy[3]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe13]
set_property port_width 16 [get_debug_ports u_ila_1/probe13]
connect_debug_port u_ila_1/probe13 [get_nets [list {e2bus_2/resp_len[0][0]} {e2bus_2/resp_len[0][1]} {e2bus_2/resp_len[0][2]} {e2bus_2/resp_len[0][3]} {e2bus_2/resp_len[0][4]} {e2bus_2/resp_len[0][5]} {e2bus_2/resp_len[0][6]} {e2bus_2/resp_len[0][7]} {e2bus_2/resp_len[0][8]} {e2bus_2/resp_len[0][9]} {e2bus_2/resp_len[0][10]} {e2bus_2/resp_len[0][11]} {e2bus_2/resp_len[0][12]} {e2bus_2/resp_len[0][13]} {e2bus_2/resp_len[0][14]} {e2bus_2/resp_len[0][15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe14]
set_property port_width 16 [get_debug_ports u_ila_1/probe14]
connect_debug_port u_ila_1/probe14 [get_nets [list {e2bus_2/resp_len[1][0]} {e2bus_2/resp_len[1][1]} {e2bus_2/resp_len[1][2]} {e2bus_2/resp_len[1][3]} {e2bus_2/resp_len[1][4]} {e2bus_2/resp_len[1][5]} {e2bus_2/resp_len[1][6]} {e2bus_2/resp_len[1][7]} {e2bus_2/resp_len[1][8]} {e2bus_2/resp_len[1][9]} {e2bus_2/resp_len[1][10]} {e2bus_2/resp_len[1][11]} {e2bus_2/resp_len[1][12]} {e2bus_2/resp_len[1][13]} {e2bus_2/resp_len[1][14]} {e2bus_2/resp_len[1][15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe15]
set_property port_width 16 [get_debug_ports u_ila_1/probe15]
connect_debug_port u_ila_1/probe15 [get_nets [list {e2bus_2/resp_len[2][0]} {e2bus_2/resp_len[2][1]} {e2bus_2/resp_len[2][2]} {e2bus_2/resp_len[2][3]} {e2bus_2/resp_len[2][4]} {e2bus_2/resp_len[2][5]} {e2bus_2/resp_len[2][6]} {e2bus_2/resp_len[2][7]} {e2bus_2/resp_len[2][8]} {e2bus_2/resp_len[2][9]} {e2bus_2/resp_len[2][10]} {e2bus_2/resp_len[2][11]} {e2bus_2/resp_len[2][12]} {e2bus_2/resp_len[2][13]} {e2bus_2/resp_len[2][14]} {e2bus_2/resp_len[2][15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe16]
set_property port_width 16 [get_debug_ports u_ila_1/probe16]
connect_debug_port u_ila_1/probe16 [get_nets [list {e2bus_2/resp_len[3][0]} {e2bus_2/resp_len[3][1]} {e2bus_2/resp_len[3][2]} {e2bus_2/resp_len[3][3]} {e2bus_2/resp_len[3][4]} {e2bus_2/resp_len[3][5]} {e2bus_2/resp_len[3][6]} {e2bus_2/resp_len[3][7]} {e2bus_2/resp_len[3][8]} {e2bus_2/resp_len[3][9]} {e2bus_2/resp_len[3][10]} {e2bus_2/resp_len[3][11]} {e2bus_2/resp_len[3][12]} {e2bus_2/resp_len[3][13]} {e2bus_2/resp_len[3][14]} {e2bus_2/resp_len[3][15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe17]
set_property port_width 15 [get_debug_ports u_ila_1/probe17]
connect_debug_port u_ila_1/probe17 [get_nets [list {e2bus_2/resp_num[0][0]} {e2bus_2/resp_num[0][1]} {e2bus_2/resp_num[0][2]} {e2bus_2/resp_num[0][3]} {e2bus_2/resp_num[0][4]} {e2bus_2/resp_num[0][5]} {e2bus_2/resp_num[0][6]} {e2bus_2/resp_num[0][7]} {e2bus_2/resp_num[0][8]} {e2bus_2/resp_num[0][9]} {e2bus_2/resp_num[0][10]} {e2bus_2/resp_num[0][11]} {e2bus_2/resp_num[0][12]} {e2bus_2/resp_num[0][13]} {e2bus_2/resp_num[0][14]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe18]
set_property port_width 15 [get_debug_ports u_ila_1/probe18]
connect_debug_port u_ila_1/probe18 [get_nets [list {e2bus_2/resp_num[1][0]} {e2bus_2/resp_num[1][1]} {e2bus_2/resp_num[1][2]} {e2bus_2/resp_num[1][3]} {e2bus_2/resp_num[1][4]} {e2bus_2/resp_num[1][5]} {e2bus_2/resp_num[1][6]} {e2bus_2/resp_num[1][7]} {e2bus_2/resp_num[1][8]} {e2bus_2/resp_num[1][9]} {e2bus_2/resp_num[1][10]} {e2bus_2/resp_num[1][11]} {e2bus_2/resp_num[1][12]} {e2bus_2/resp_num[1][13]} {e2bus_2/resp_num[1][14]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe19]
set_property port_width 15 [get_debug_ports u_ila_1/probe19]
connect_debug_port u_ila_1/probe19 [get_nets [list {e2bus_2/resp_num[2][0]} {e2bus_2/resp_num[2][1]} {e2bus_2/resp_num[2][2]} {e2bus_2/resp_num[2][3]} {e2bus_2/resp_num[2][4]} {e2bus_2/resp_num[2][5]} {e2bus_2/resp_num[2][6]} {e2bus_2/resp_num[2][7]} {e2bus_2/resp_num[2][8]} {e2bus_2/resp_num[2][9]} {e2bus_2/resp_num[2][10]} {e2bus_2/resp_num[2][11]} {e2bus_2/resp_num[2][12]} {e2bus_2/resp_num[2][13]} {e2bus_2/resp_num[2][14]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe20]
set_property port_width 15 [get_debug_ports u_ila_1/probe20]
connect_debug_port u_ila_1/probe20 [get_nets [list {e2bus_2/resp_num[3][0]} {e2bus_2/resp_num[3][1]} {e2bus_2/resp_num[3][2]} {e2bus_2/resp_num[3][3]} {e2bus_2/resp_num[3][4]} {e2bus_2/resp_num[3][5]} {e2bus_2/resp_num[3][6]} {e2bus_2/resp_num[3][7]} {e2bus_2/resp_num[3][8]} {e2bus_2/resp_num[3][9]} {e2bus_2/resp_num[3][10]} {e2bus_2/resp_num[3][11]} {e2bus_2/resp_num[3][12]} {e2bus_2/resp_num[3][13]} {e2bus_2/resp_num[3][14]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe21]
set_property port_width 32 [get_debug_ports u_ila_1/probe21]
connect_debug_port u_ila_1/probe21 [get_nets [list {e2bus_2/sys_cmd_frame_dout[0]} {e2bus_2/sys_cmd_frame_dout[1]} {e2bus_2/sys_cmd_frame_dout[2]} {e2bus_2/sys_cmd_frame_dout[3]} {e2bus_2/sys_cmd_frame_dout[4]} {e2bus_2/sys_cmd_frame_dout[5]} {e2bus_2/sys_cmd_frame_dout[6]} {e2bus_2/sys_cmd_frame_dout[7]} {e2bus_2/sys_cmd_frame_dout[8]} {e2bus_2/sys_cmd_frame_dout[9]} {e2bus_2/sys_cmd_frame_dout[10]} {e2bus_2/sys_cmd_frame_dout[11]} {e2bus_2/sys_cmd_frame_dout[12]} {e2bus_2/sys_cmd_frame_dout[13]} {e2bus_2/sys_cmd_frame_dout[14]} {e2bus_2/sys_cmd_frame_dout[15]} {e2bus_2/sys_cmd_frame_dout[16]} {e2bus_2/sys_cmd_frame_dout[17]} {e2bus_2/sys_cmd_frame_dout[18]} {e2bus_2/sys_cmd_frame_dout[19]} {e2bus_2/sys_cmd_frame_dout[20]} {e2bus_2/sys_cmd_frame_dout[21]} {e2bus_2/sys_cmd_frame_dout[22]} {e2bus_2/sys_cmd_frame_dout[23]} {e2bus_2/sys_cmd_frame_dout[24]} {e2bus_2/sys_cmd_frame_dout[25]} {e2bus_2/sys_cmd_frame_dout[26]} {e2bus_2/sys_cmd_frame_dout[27]} {e2bus_2/sys_cmd_frame_dout[28]} {e2bus_2/sys_cmd_frame_dout[29]} {e2bus_2/sys_cmd_frame_dout[30]} {e2bus_2/sys_cmd_frame_dout[31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe22]
set_property port_width 11 [get_debug_ports u_ila_1/probe22]
connect_debug_port u_ila_1/probe22 [get_nets [list {e2bus_2/sys_cmd_frame_ad[0]} {e2bus_2/sys_cmd_frame_ad[1]} {e2bus_2/sys_cmd_frame_ad[2]} {e2bus_2/sys_cmd_frame_ad[3]} {e2bus_2/sys_cmd_frame_ad[4]} {e2bus_2/sys_cmd_frame_ad[5]} {e2bus_2/sys_cmd_frame_ad[6]} {e2bus_2/sys_cmd_frame_ad[7]} {e2bus_2/sys_cmd_frame_ad[8]} {e2bus_2/sys_cmd_frame_ad[9]} {e2bus_2/sys_cmd_frame_ad[10]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe23]
set_property port_width 42 [get_debug_ports u_ila_1/probe23]
connect_debug_port u_ila_1/probe23 [get_nets [list {e2bus_2/sys_desc_dout[0]} {e2bus_2/sys_desc_dout[1]} {e2bus_2/sys_desc_dout[2]} {e2bus_2/sys_desc_dout[3]} {e2bus_2/sys_desc_dout[4]} {e2bus_2/sys_desc_dout[5]} {e2bus_2/sys_desc_dout[6]} {e2bus_2/sys_desc_dout[7]} {e2bus_2/sys_desc_dout[8]} {e2bus_2/sys_desc_dout[9]} {e2bus_2/sys_desc_dout[10]} {e2bus_2/sys_desc_dout[11]} {e2bus_2/sys_desc_dout[12]} {e2bus_2/sys_desc_dout[13]} {e2bus_2/sys_desc_dout[14]} {e2bus_2/sys_desc_dout[15]} {e2bus_2/sys_desc_dout[16]} {e2bus_2/sys_desc_dout[17]} {e2bus_2/sys_desc_dout[18]} {e2bus_2/sys_desc_dout[19]} {e2bus_2/sys_desc_dout[20]} {e2bus_2/sys_desc_dout[21]} {e2bus_2/sys_desc_dout[22]} {e2bus_2/sys_desc_dout[23]} {e2bus_2/sys_desc_dout[24]} {e2bus_2/sys_desc_dout[25]} {e2bus_2/sys_desc_dout[26]} {e2bus_2/sys_desc_dout[27]} {e2bus_2/sys_desc_dout[28]} {e2bus_2/sys_desc_dout[29]} {e2bus_2/sys_desc_dout[30]} {e2bus_2/sys_desc_dout[31]} {e2bus_2/sys_desc_dout[32]} {e2bus_2/sys_desc_dout[33]} {e2bus_2/sys_desc_dout[34]} {e2bus_2/sys_desc_dout[35]} {e2bus_2/sys_desc_dout[36]} {e2bus_2/sys_desc_dout[37]} {e2bus_2/sys_desc_dout[38]} {e2bus_2/sys_desc_dout[39]} {e2bus_2/sys_desc_dout[40]} {e2bus_2/sys_desc_dout[41]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe24]
set_property port_width 5 [get_debug_ports u_ila_1/probe24]
connect_debug_port u_ila_1/probe24 [get_nets [list {e2bus_2/sys_desc_ad[0]} {e2bus_2/sys_desc_ad[1]} {e2bus_2/sys_desc_ad[2]} {e2bus_2/sys_desc_ad[3]} {e2bus_2/sys_desc_ad[4]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe25]
set_property port_width 32 [get_debug_ports u_ila_1/probe25]
connect_debug_port u_ila_1/probe25 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][0]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][1]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][2]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][3]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][4]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][5]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][6]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][7]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][8]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][9]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][10]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][11]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][12]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][13]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][14]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][15]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][16]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][17]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][18]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][19]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][20]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][21]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][22]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][23]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][24]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][25]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][26]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][27]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][28]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][29]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][30]} {e2bus_2/cb1.cmd_exec_1/r2[del_cnt][31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe26]
set_property port_width 1 [get_debug_ports u_ila_1/probe26]
connect_debug_port u_ila_1/probe26 [get_nets [list e2bus_2/cb1.cmd_exec_1/bc_exec_ack]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe27]
set_property port_width 1 [get_debug_ports u_ila_1/probe27]
connect_debug_port u_ila_1/probe27 [get_nets [list {e2bus_2/r1[exec_start]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe28]
set_property port_width 1 [get_debug_ports u_ila_1/probe28]
connect_debug_port u_ila_1/probe28 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r2[exec_ack]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe29]
set_property port_width 1 [get_debug_ports u_ila_1/probe29]
connect_debug_port u_ila_1/probe29 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r2[last]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe30]
set_property port_width 1 [get_debug_ports u_ila_1/probe30]
connect_debug_port u_ila_1/probe30 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r[bc_exec_start]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe31]
set_property port_width 1 [get_debug_ports u_ila_1/probe31]
connect_debug_port u_ila_1/probe31 [get_nets [list {e2bus_2/cb1.cmd_exec_1/r[exec_ack]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe32]
set_property port_width 1 [get_debug_ports u_ila_1/probe32]
connect_debug_port u_ila_1/probe32 [get_nets [list {wb_m2s[cyc]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe33]
set_property port_width 1 [get_debug_ports u_ila_1/probe33]
connect_debug_port u_ila_1/probe33 [get_nets [list {wb_m2s[stb]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe34]
set_property port_width 1 [get_debug_ports u_ila_1/probe34]
connect_debug_port u_ila_1/probe34 [get_nets [list {wb_m2s[we]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe35]
set_property port_width 1 [get_debug_ports u_ila_1/probe35]
connect_debug_port u_ila_1/probe35 [get_nets [list {wb_s2m[ack]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe36]
set_property port_width 1 [get_debug_ports u_ila_1/probe36]
connect_debug_port u_ila_1/probe36 [get_nets [list {wb_s2m[err]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe37]
set_property port_width 1 [get_debug_ports u_ila_1/probe37]
connect_debug_port u_ila_1/probe37 [get_nets [list {wb_s2m[stall]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ipb_clk]
