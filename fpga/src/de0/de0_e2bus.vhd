-------------------------------------------------------------------------------
-- Title      : E2Bus demo for DE0 Nano SoC board with ACM8211 1Gb/s Ethernet board
-- Project    : 
-------------------------------------------------------------------------------
-- File       : de0_e2bus.vhd
-- Author     : Wojciech M. Zabolotny <wzab@ise.pw.edu.pl>
-- License    : BSD License
-- Company    : 
-- Created    : 2010-08-03
-- Last update: 2020-08-02
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
use work.wb_pkg.all;
use work.wishbone_pkg.all;
use work.wishbone_wb_pkg.all;
library pll1;

entity de0_e2bus is

  port (
    cpu_reset      : in    std_logic;
    btn            : in    std_logic_vector(3 downto 0);
    switches       : in    std_logic_vector(7 downto 0);
    gpio_led       : out   std_logic_vector(7 downto 0);
    -- I2C interface
    i2c_scl        : inout std_logic;
    i2c_sda        : inout std_logic;
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

end de0_e2bus;

architecture beh of de0_e2bus is

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



  signal my_mac   : std_logic_vector(47 downto 0);
  signal peer_mac : std_logic_vector(47 downto 0) :=
    -- x"14_fe_b5_c5_bc_7c";
    -- x"d8_cb_8a_1d_ab_e5";
    -- x"de_ad_be_af_be_e6";
    x"52_55_22_d1_55_01";

  signal restart : std_logic;

  signal nwr, nrd, rst_n, dcm_locked : std_logic;
  signal not_cpu_reset, rst_del      : std_logic;

  signal tx_valid : std_logic                    := '0';
  signal tx_last  : std_logic                    := '0';
  signal tx_error : std_logic                    := '0';
  signal tx_ready : std_logic                    := '0';
  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');


  signal rx_error : std_logic                    := '0';
  signal rx_valid : std_logic                    := '0';
  signal rx_last  : std_logic                    := '0';
  signal rx_data  : std_logic_vector(7 downto 0) := (others => '0');

  signal irqs : std_logic_vector(7 downto 0) := (others => '0');


  signal dbg : std_logic_vector(3 downto 0);

  -- signal tx_counter         : integer                       := 10000;
  -- signal Reset              : std_logic;
  signal Clk_125M : std_logic;
  signal Clk_user : std_logic;
  signal Clk_reg  : std_logic;
  signal Rx_clk   : std_logic;
  signal Tx_clk   : std_logic;

  signal phy_rxctl_rxdv_d : std_logic;
  signal phy_rxd_d        : std_logic_vector(7 downto 0);
  signal phy_rxer_d       : std_logic;

  signal wb_m2s   : t_wb_m2s;
  signal wb_s2m   : t_wb_s2m;
  signal wb_s_in  : t_wishbone_slave_in;
  signal wb_s_out : t_wishbone_slave_out;

begin  -- beh

  -- Allow selection of MAC with the DIP switch to allow testing
  -- with multiple boards!
  with switches(1 downto 0) select
    my_mac <=
    x"0e_68_61_2d_d4_7e" when "00",
    x"0e_68_61_2d_d4_7e" when "01",
    x"0e_68_61_2d_d4_7e" when "10",
    x"0e_68_61_2d_d4_7e" when "11";

  irqs(3 downto 0) <= btn;

  not_cpu_reset <= not cpu_reset;


  tx_clk <= Clk_125M;
  rx_clk <= phy_rxclk;

  e2bus_2 : entity work.e2bus
    generic map (
      PHY_DTA_WIDTH => 8)
    port map (
      leds    => gpio_led,
      irqs    => irqs,
      my_mac  => my_mac,
      sys_clk => clk_user,
      rst_n   => rst_n,
      wb_m2s  => wb_m2s,
      wb_s2m  => wb_s2m,
      wb_clk  => clk_user,
      Rx_Clk  => phy_rxclk,
      Rx_Er   => phy_rxer_d,
      Rx_Dv   => phy_rxctl_rxdv_d,
      RxD     => phy_rxd_d,
      Tx_Clk  => tx_clk,
      Tx_En   => phy_txctl_txen,
      TxD     => phy_txd);

  pll1_1 : entity pll1.pll1
    port map (
      refclk   => sysclk,
      outclk_0 => Clk_125M,
      outclk_1 => Clk_user,
      outclk_2 => Clk_reg,
      rst      => not_cpu_reset,
      locked   => dcm_locked);

  -- Delay RX signals to improve timing
  process(phy_rxclk)
  begin
    if rising_edge(phy_rxclk) then
      phy_rxer_d       <= phy_rxer;
      phy_rxctl_rxdv_d <= phy_rxctl_rxdv;
      phy_rxd_d        <= phy_rxd;
    end if;
  end process;

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

  main_1 : entity work.main
    port map (
      rst_n_i   => rst_n,
      clk_sys_i => clk_user,
      wb_s_in   => wb_s_in,
      wb_s_out  => wb_s_out,
      i2c_scl   => i2c_scl,
      i2c_sda   => i2c_sda);

  wb_s_in <= wb2wishbone_m2s(wb_m2s);
  wb_s2m  <= wishbone2wb_s2m(wb_s_out);

  -- reset

  phy_reset <= rst_n;

  -- Connection of MDI
  --s_Mdi    <= PHY_MDIO;
  --PHY_MDIO <= 'Z' when s_MdoEn = '0' else s_Mdo;

  phy_txer <= '0';
  phy_mdio <= 'Z';
  phy_mdc  <= '0';

  phy_txc_gtxclk <= tx_clk;

end beh;
