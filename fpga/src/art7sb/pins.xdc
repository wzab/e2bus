set_property IOSTANDARD LVCMOS33 [get_ports ref_clk]
set_property IOSTANDARD LVCMOS33 [get_ports phy_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports phy2rmii_crs_dv]
set_property IOSTANDARD LVCMOS33 [get_ports {phy2rmii_rxd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy2rmii_rxd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports rmii2phy_tx_en]
set_property IOSTANDARD LVCMOS33 [get_ports {rmii2phy_txd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rmii2phy_txd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports led1]
set_property IOSTANDARD LVCMOS33 [get_ports phy_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports phy_mdio]
set_property PACKAGE_PIN D4 [get_ports ref_clk]
set_property PACKAGE_PIN C3 [get_ports phy_rst_n]
set_property PACKAGE_PIN G5 [get_ports {phy2rmii_rxd[1]}]
set_property PACKAGE_PIN C7 [get_ports {phy2rmii_rxd[0]}]
set_property PACKAGE_PIN B4 [get_ports {rmii2phy_txd[1]}]
set_property PACKAGE_PIN D6 [get_ports {rmii2phy_txd[0]}]
set_property PACKAGE_PIN E6 [get_ports phy2rmii_crs_dv]
set_property PACKAGE_PIN A5 [get_ports rmii2phy_tx_en]
set_property PACKAGE_PIN A8 [get_ports rst_n]
set_property PACKAGE_PIN C8 [get_ports led1]
set_property PACKAGE_PIN B7 [get_ports phy_mdc]
set_property PACKAGE_PIN B6 [get_ports phy_mdio]
set_property PULLUP true [get_ports phy_mdio]
set_property PULLUP true [get_ports phy_mdc]
create_clock -period 20.000 -name ref_clk -waveform {0.000 10.000} [get_ports ref_clk]
create_generated_clock -name mii_to_rmii_0_1/U0/rmii2mac_rx_clk -source [get_ports ref_clk] -divide_by 2 [get_pins mii_to_rmii_0_1/U0/rmii2mac_rx_clk_bi_reg/Q]
create_generated_clock -name mii_to_rmii_0_1/U0/rmii2mac_tx_clk -source [get_ports ref_clk] -divide_by 2 [get_pins mii_to_rmii_0_1/U0/rmii2mac_tx_clk_bi_reg/Q]
create_clock -period 40.000 -name VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_rx_clk -waveform {0.000 20.000}
set_input_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports {phy2rmii_rxd[*]}]
set_input_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports {phy2rmii_rxd[*]}]
set_input_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports phy2rmii_crs_dv]
set_input_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports phy2rmii_crs_dv]
set_input_delay -clock [get_clocks VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_rx_clk] -min -add_delay 0.000 [get_ports rst_n]
set_input_delay -clock [get_clocks VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_rx_clk] -max -add_delay 6.000 [get_ports rst_n]
set_input_delay -clock [get_clocks ref_clk] -min -add_delay 0.000 [get_ports rst_n]
set_input_delay -clock [get_clocks ref_clk] -max -add_delay 6.000 [get_ports rst_n]
create_clock -period 40.000 -name VIRTUAL_mii_to_rmii_0_1/U0/rmii2mac_tx_clk -waveform {0.000 20.000}
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

set_property OFFCHIP_TERM NONE [get_ports rmii2phy_txd[0]]
set_property OFFCHIP_TERM NONE [get_ports rmii2phy_txd[1]]
