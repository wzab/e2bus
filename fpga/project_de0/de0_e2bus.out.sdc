## Generated SDC file "de0_e2bus.out.sdc"

## Copyright (C) 2018  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 18.1.0 Build 625 09/12/2018 SJ Lite Edition"

## DATE    "Mon Aug  3 16:56:29 2020"

##
## DEVICE  "5CSEMA4U23C6"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {sysclk} -period 20.000 -waveform { 0.000 10.000 } [get_ports {sysclk}]
create_clock -name {rxclk} -period 8.000 -waveform { 0.000 4.000 } [get_ports {phy_rxclk}]


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]} -source [get_pins {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|refclkin}] -duty_cycle 50/1 -multiply_by 60 -divide_by 2 -master_clock {sysclk} [get_pins {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]}] 
create_generated_clock -name {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} -source [get_pins {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|vco0ph[0]}] -duty_cycle 50/1 -multiply_by 1 -divide_by 12 -master_clock {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]} [get_pins {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] 
create_generated_clock -name {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk} -source [get_pins {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|vco0ph[0]}] -duty_cycle 50/1 -multiply_by 1 -divide_by 24 -master_clock {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]} [get_pins {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] 
create_generated_clock -name {gtx_clk} -source [get_nets {pll1_1|pll1_inst|altera_pll_i|outclk_wire[0]}] -master_clock {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} [get_ports {phy_txc_gtxclk}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {rxclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {rxclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {rxclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {rxclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {rxclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {rxclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {rxclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {rxclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {sysclk}] -rise_to [get_clocks {sysclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {sysclk}] -rise_to [get_clocks {sysclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {sysclk}] -fall_to [get_clocks {sysclk}] -setup 0.080  
set_clock_uncertainty -rise_from [get_clocks {sysclk}] -fall_to [get_clocks {sysclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {sysclk}] -rise_to [get_clocks {sysclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {sysclk}] -rise_to [get_clocks {sysclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {sysclk}] -fall_to [get_clocks {sysclk}] -setup 0.080  
set_clock_uncertainty -fall_from [get_clocks {sysclk}] -fall_to [get_clocks {sysclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {rxclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {rxclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {rxclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {rxclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {rxclk}] -rise_to [get_clocks {rxclk}] -setup 0.170  
set_clock_uncertainty -rise_from [get_clocks {rxclk}] -rise_to [get_clocks {rxclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {rxclk}] -fall_to [get_clocks {rxclk}] -setup 0.170  
set_clock_uncertainty -rise_from [get_clocks {rxclk}] -fall_to [get_clocks {rxclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {rxclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {rxclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {rxclk}] -rise_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {rxclk}] -fall_to [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {rxclk}] -rise_to [get_clocks {rxclk}] -setup 0.170  
set_clock_uncertainty -fall_from [get_clocks {rxclk}] -rise_to [get_clocks {rxclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {rxclk}] -fall_to [get_clocks {rxclk}] -setup 0.170  
set_clock_uncertainty -fall_from [get_clocks {rxclk}] -fall_to [get_clocks {rxclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {gtx_clk}] -setup 0.220  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {gtx_clk}] -hold 0.210  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {gtx_clk}] -setup 0.220  
set_clock_uncertainty -rise_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {gtx_clk}] -hold 0.210  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {gtx_clk}] -setup 0.220  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {gtx_clk}] -hold 0.210  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {gtx_clk}] -setup 0.220  
set_clock_uncertainty -fall_from [get_clocks {pll1_1|pll1_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {gtx_clk}] -hold 0.210  


#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {btn[0]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {cpu_reset}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {i2c_scl}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {i2c_sda}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_col}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_crs}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_mdio}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxclk}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxctl_rxdv}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxd[0]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxd[1]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxd[2]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxd[3]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxd[4]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxd[5]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxd[6]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxd[7]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_rxer}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {phy_txclk}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {switches[0]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {switches[1]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {switches[2]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {switches[3]}]
set_input_delay -add_delay  -clock [get_clocks {rxclk}]  2.000 [get_ports {sysclk}]


#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txctl_txen}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txctl_txen}]
set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txd[0]}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txd[0]}]
set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txd[1]}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txd[1]}]
set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txd[2]}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txd[2]}]
set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txd[3]}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txd[3]}]
set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txd[4]}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txd[4]}]
set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txd[5]}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txd[5]}]
set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txd[6]}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txd[6]}]
set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txd[7]}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txd[7]}]
set_output_delay -add_delay -max -clock [get_clocks {gtx_clk}]  3.000 [get_ports {phy_txer}]
set_output_delay -add_delay -min -clock [get_clocks {gtx_clk}]  0.000 [get_ports {phy_txer}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_cells -compatibility_mode {*e2bus*|special_cmd_req_sync*}]
set_false_path -from [get_keepers {*rdptr_g*}] -to [get_keepers {*ws_dgrp|dffpipe_id9:dffpipe15|dffe16a*}]
set_false_path -from [get_keepers {*delayed_wrptr_g*}] -to [get_keepers {*rs_dgwp|dffpipe_hd9:dffpipe12|dffe13a*}]
set_false_path -to [get_cells -nocase -compatibility_mode {*sync_stlv*|*si0*}]
set_false_path -to [get_cells -nocase -compatibility_mode {*sync_stlv*|so0*}]
set_false_path -to [get_cells -compatibility_mode {*sync_stlv*|dout*}]
set_false_path -to [get_cells -compatibility_mode {*e2bus*|special_cmd*}]
set_false_path -from [get_cells -compatibility_mode {*e2bus*|special_cmd*}] 
set_false_path -to [get_cells -compatibility_mode {*e2bus*|peer_mac*}]
set_false_path -from [get_cells -compatibility_mode {*e2bus*|peer_mac*}] 


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************

set_max_delay -from [get_cells -compatibility_mode {*eth_receiver*|*r.*}] -to [get_cells -compatibility_mode {*e2bus*|peer_mac*}] 3.000


#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Max Skew
#**************************************************************

set_max_skew -from * -to [get_cells -compatibility_mode {*sync_stlv*|dout*}] 3.000 
set_max_skew -from [get_cells -compatibility_mode {*eth_receiver*|r.*}] -to [get_cells -compatibility_mode {*e2bus*|\cb0*}] 2.000 
set_max_skew -from * -to [get_cells -compatibility_mode {*e2bus*|special_cmd*}] 3.000 
