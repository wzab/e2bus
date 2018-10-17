-------------------------------------------------------------------------------
-- Title      : E2bus on 100Mbps Ethernet demo for simple Artix 7 board
-- Project    : 
-------------------------------------------------------------------------------
-- File       : a7sb_eth_top.vhd
-- Author     : Wojciech M. Zabolotny <wzab@ise.pw.edu.pl>
-- Company    : 
-- Created    : 2017-05-20
-- Last update: 2018-09-23
-- Platform   : 
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- This file shows possibility of using the IPbus protocol with FPGAs connected
-- via 100 Mbps interfaces
-- This code works with the original IPbus code available at
-- https://svnweb.cern.ch/trac/cactus
-------------------------------------------------------------------------------
-- Copyright (c) 2017
-- This is public domain code!!!
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-05-20  1.0      wzab    Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

library unisim;
use unisim.vcomponents.all;

entity a7sb_e2bus is
  port(
    sys_clk         : in    std_logic;
    ref_clk         : in    std_logic;
    phy2rmii_crs_dv : in    std_logic;
    --phy2rmii_rx_er  : in    std_logic;
    phy2rmii_rxd    : in    std_logic_vector(1 downto 0);
    rmii2phy_tx_en  : out   std_logic;
    rmii2phy_txd    : out   std_logic_vector(1 downto 0);
    phy_mdc         : out   std_logic;
    phy_mdio        : inout std_logic;
    led1            : out   std_logic;
    rst_n           : in    std_logic;
    phy_rst_n       : out   std_logic
    );
end a7sb_e2bus;

architecture beh of a7sb_e2bus is

  signal rst_p          : std_logic;
  signal phy2rmii_rx_er : std_logic;

  signal buttons, leds  : std_logic_vector(7 downto 0);
  signal clk25, ipb_clk : std_logic;

  signal s_dta_we    : std_logic;
  constant zeroes_32 : std_logic_vector(31 downto 0) := (others => '0');

  signal mac_tx_data, mac_rx_data                              : std_logic_vector(7 downto 0);
  signal mac_tx_valid, mac_tx_last, mac_tx_error, mac_tx_ready : std_logic;
  signal mac_rx_valid, mac_rx_last, mac_rx_error               : std_logic;



  component mii_to_rmii_0
    port (
      rst_n           : in  std_logic;
      ref_clk         : in  std_logic;
      mac2rmii_tx_en  : in  std_logic;
      mac2rmii_txd    : in  std_logic_vector(3 downto 0);
      mac2rmii_tx_er  : in  std_logic;
      rmii2mac_tx_clk : out std_logic;
      rmii2mac_rx_clk : out std_logic;
      rmii2mac_col    : out std_logic;
      rmii2mac_crs    : out std_logic;
      rmii2mac_rx_dv  : out std_logic;
      rmii2mac_rx_er  : out std_logic;
      rmii2mac_rxd    : out std_logic_vector(3 downto 0);
      phy2rmii_crs_dv : in  std_logic;
      phy2rmii_rx_er  : in  std_logic;
      phy2rmii_rxd    : in  std_logic_vector(1 downto 0);
      rmii2phy_txd    : out std_logic_vector(1 downto 0);
      rmii2phy_tx_en  : out std_logic
      );
  end component;

  component clk_wiz_0
    port
      (                                 -- Clock in ports
        -- Clock out ports
        clk_out1 : out std_logic;
        -- Status and control signals
        reset    : in  std_logic;
        locked   : out std_logic;
        clk_in1  : in  std_logic
        );
  end component;

  component clk_wiz_2
    port
      (                                 -- Clock in ports
        -- Clock out ports
        clk_out1 : out std_logic;
        -- Status and control signals
        reset    : in  std_logic;
        locked   : out std_logic;
        clk_in1  : in  std_logic
        );
  end component;

  signal mac2rmii_tx_en  : std_logic;
  signal mac2rmii_txd    : std_logic_vector(3 downto 0);
  signal mac2rmii_tx_er  : std_logic;
  signal rmii2mac_tx_clk : std_logic;
  signal rmii2mac_rx_clk : std_logic;
  signal rmii2mac_col    : std_logic;
  signal rmii2mac_crs    : std_logic;
  signal rmii2mac_rx_dv  : std_logic;
  signal rmii2mac_rx_er  : std_logic;
  signal rmii2mac_rxd    : std_logic_vector(3 downto 0);
  signal my_mac          : std_logic_vector(47 downto 0) := x"de_ad_ba_be_be_ef";
  signal peer_mac        : std_logic_vector(47 downto 0) :=
    -- x"14_fe_b5_c5_bc_7c";
    -- x"d8_cb_8a_1d_ab_e5";
    -- x"de_ad_be_af_be_e6";
    x"52_55_22_d1_55_01";
  signal irqs       : std_logic_vector(7 downto 0) := (others => '0');
  signal ref_clk_ok : std_logic                    := '0';
  signal syn_rst_n  : std_logic                    := '0';
  signal dbg_clk  : std_logic := '0';

begin  -- beh


  phy_mdc        <= '1';
  phy_mdio       <= 'Z';
  phy2rmii_rx_er <= '0';                -- Not connected in PHY :( 
  mac2rmii_tx_er <= '0';
  phy_rst_n      <= syn_rst_n;          -- We assume, that phy_rst_n does not
                             -- block clock

  led1    <= syn_rst_n;
  ipb_clk <= rmii2mac_tx_clk;           -- @!@ To be verified!
  clk25   <= rmii2mac_tx_clk;
  rst_p   <= not rst_n;

  -- Added IPbus part
  clk_wiz_0_1 : entity work.clk_wiz_0
    port map (
      clk_out1 => ref_clk_ok,
      reset    => rst_p,
      locked   => syn_rst_n,
      clk_in1  => ref_clk);

  clk_wiz_2_1 : entity work.clk_wiz_2
    port map (
      clk_out1 => dbg_clk,
      reset    => rst_p,
      locked   => open,
      clk_in1  => sys_clk);

  mii_to_rmii_0_1 : entity work.mii_to_rmii_0
    port map (
      rst_n           => syn_rst_n,
      ref_clk         => ref_clk_ok,
      mac2rmii_tx_en  => mac2rmii_tx_en,
      mac2rmii_txd    => mac2rmii_txd,
      mac2rmii_tx_er  => mac2rmii_tx_er,
      rmii2mac_tx_clk => rmii2mac_tx_clk,
      rmii2mac_rx_clk => rmii2mac_rx_clk,
      rmii2mac_col    => rmii2mac_col,
      rmii2mac_crs    => rmii2mac_crs,
      rmii2mac_rx_dv  => rmii2mac_rx_dv,
      rmii2mac_rx_er  => rmii2mac_rx_er,
      rmii2mac_rxd    => rmii2mac_rxd,
      phy2rmii_crs_dv => phy2rmii_crs_dv,
      phy2rmii_rx_er  => phy2rmii_rx_er,
      phy2rmii_rxd    => phy2rmii_rxd,
      rmii2phy_txd    => rmii2phy_txd,
      rmii2phy_tx_en  => rmii2phy_tx_en);

  e2bus_1 : entity work.e2bus
    generic map (
      PHY_DTA_WIDTH => 4)
    port map (
      irqs    => irqs,
      leds    => leds,
      my_mac  => my_mac,
      sys_clk => ipb_clk,
      rst_n   => syn_rst_n,
      --
      Rx_Clk  => rmii2mac_rx_clk,
      Rx_Er   => rmii2mac_rx_er,
      Rx_Dv   => rmii2mac_rx_dv,
      RxD     => rmii2mac_rxd,
      Tx_Clk  => rmii2mac_tx_clk,
      Tx_En   => mac2rmii_tx_en,
      TxD     => mac2rmii_txd);

end beh;
