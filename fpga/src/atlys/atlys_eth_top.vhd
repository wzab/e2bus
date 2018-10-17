-------------------------------------------------------------------------------
-- Title      : E2Bus demo for Digilent Atlys board
-- Project    : 
-------------------------------------------------------------------------------
-- File       : atlys_eth_top.vhd
-- Author     : Wojciech M. Zabolotny <wzab@ise.pw.edu.pl>
-- License    : BSD License
-- Company    : 
-- Created    : 2010-08-03
-- Last update: 2018-09-23
-- Platform   : 
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- This file implements the top entity, integrating all component
-------------------------------------------------------------------------------
-- Copyright (c) 2012
-- This is public domain code!!!
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2010-08-03  1.0      wzab    Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

entity atlys_eth is
  
  port (
    cpu_reset : in std_logic;
    btn        : in    std_logic_vector(3 downto 0);
    switches       : in    std_logic_vector(7 downto 0);
    gpio_led       : out   std_logic_vector(7 downto 0);
    -- PHY interface
    phy_col        : in    std_logic;
    phy_crs        : in    std_logic;
    phy_int        : in    std_logic;
    phy_mdc        : out   std_logic;
    phy_mdio       : inout std_logic;
    phy_reset      : out   std_logic;
    phy_rxclk      : in    std_logic;
    phy_rxctl_rxdv : in    std_logic;
    phy_rxd        : in    std_logic_vector(7 downto 0);
    phy_rxer       : in    std_logic;
    phy_txclk      : in    std_logic;
    phy_txctl_txen : out   std_logic;
    phy_txc_gtxclk : out   std_logic;
    phy_txd        : out   std_logic_vector(7 downto 0);
    phy_txer       : out   std_logic;
    sysclk         : in    std_logic
    );

end atlys_eth;

architecture beh of atlys_eth is

  component dp_ram_scl
    generic (
      DATA_WIDTH : integer;
      ADDR_WIDTH : integer);
    port (
      clk_a  : in  std_logic;
      we_a   : in  std_logic;
      addr_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      data_a : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      q_a    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      clk_b  : in  std_logic;
      we_b   : in  std_logic;
      addr_b : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      data_b : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      q_b    : out std_logic_vector(DATA_WIDTH-1 downto 0));
  end component;

  component dcm1
    port (
      CLK_IN1  : in  std_logic;
      CLK_OUT1 : out std_logic;
      CLK_OUT2 : out std_logic;
      CLK_OUT3 : out std_logic;
      RESET    : in  std_logic;
      LOCKED   : out std_logic);
  end component;


 
  signal my_mac          : std_logic_vector(47 downto 0);
  signal peer_mac          : std_logic_vector(47 downto 0) :=
    -- x"14_fe_b5_c5_bc_7c";
    -- x"d8_cb_8a_1d_ab_e5";
    -- x"de_ad_be_af_be_e6";
	 x"52_55_22_d1_55_01";
	 
  signal restart         : std_logic;

  signal nwr, nrd, rst_n, dcm_locked : std_logic;
  signal not_cpu_reset, rst_del             : std_logic;

  signal tx_valid : std_logic := '0';
  signal tx_last : std_logic := '0';
  signal tx_error : std_logic := '0';
  signal tx_ready : std_logic := '0';
  signal tx_data : std_logic_vector(7 downto 0) := (others => '0');

  
  signal rx_error : std_logic := '0';
  signal rx_valid : std_logic := '0';
  signal rx_last : std_logic := '0';
  signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
  
  signal irqs : std_logic_vector(7 downto 0) := (others => '0');


  signal dbg : std_logic_vector(3 downto 0);

  -- signal tx_counter         : integer                       := 10000;
  -- signal Reset              : std_logic;
  signal Clk_125M           : std_logic;
  signal Clk_user           : std_logic;
  signal Clk_reg            : std_logic;
  signal Rx_clk             : std_logic;
  signal Tx_clk             : std_logic;
  
begin  -- beh

  -- Allow selection of MAC with the DIP switch to allow testing
  -- with multiple boards!
  with switches(1 downto 0) select
    my_mac <=
    x"de_ad_ba_be_be_ef" when "00",
    x"de_ad_ba_be_be_e1" when "01",
    x"de_ad_ba_be_be_e2" when "10",
    x"de_ad_ba_be_be_e3" when "11";

  irqs(3 downto 0) <= btn;

  not_cpu_reset <= not cpu_reset;


  tx_clk <= Clk_125M;
  rx_clk <= phy_rxclk;

  e2bus_1: entity work.e2bus
    generic map (
      PHY_DTA_WIDTH  => 8
      )
    port map (
      irqs => irqs,
      leds => gpio_led,
      my_mac => my_mac,
      sys_clk => clk_user,
      rst_n => rst_n,
      --
      Rx_Clk => phy_rxclk,
      Rx_Er  => phy_rxer,
      Rx_Dv  => phy_rxctl_rxdv,
      RxD    => phy_rxd,
      Tx_Clk => tx_clk,
      Tx_En  => phy_txctl_txen,
      TxD    => phy_txd);
  
  dcm1_1 : dcm1
    port map (
      CLK_IN1  => sysclk,
      CLK_OUT1 => Clk_125M,
      CLK_OUT2 => Clk_user,
      CLK_OUT3 => Clk_reg,
      RESET    => not_cpu_reset,
      LOCKED   => dcm_locked);

  process (Clk_user, not_cpu_reset)
  begin  -- process
    if not_cpu_reset = '1' then         -- asynchronous reset (active low)
      rst_n   <= '0';
      rst_del <= '0';
    elsif Clk_user'event and Clk_user = '1' then  -- rising clock edge
      if restart = '1' then
        rst_n   <= '0';
        rst_del <= '0';
      else
        if dcm_locked = '1' then
          rst_del <= '1';
          rst_n   <= rst_del;
        end if;
      end if;
    end if;
  end process;

  -- reset

  phy_reset <= rst_n;

  -- Connection of MDI
  --s_Mdi    <= PHY_MDIO;
  --PHY_MDIO <= 'Z' when s_MdoEn = '0' else s_Mdo;

  phy_txer <= '0';
  phy_mdio <= 'Z';
  phy_mdc <= '0';

  phy_txc_gtxclk <= tx_clk;

end beh;
