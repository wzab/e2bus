library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wishbone_pkg.all;
use work.agwb_main_wb_pkg.all;

entity main is

  port (
    rst_n_i   : in    std_logic;
    clk_sys_i : in    std_logic;
    wb_s_in   : in    t_wishbone_slave_in;
    wb_s_out  : out   t_wishbone_slave_out;
    i2c_scl   : inout std_logic;
    i2c_sda   : inout std_logic
    );

end entity main;

architecture rtl of main is

  signal i2c_master_wb_m_o : t_wishbone_slave_in;
  signal i2c_master_wb_m_i : t_wishbone_slave_out;
  signal scl_pad_i         : std_logic_vector(0 downto 0);
  signal sda_pad_i         : std_logic_vector(0 downto 0);
  signal scl_pad_o         : std_logic_vector(0 downto 0);
  signal sda_pad_o         : std_logic_vector(0 downto 0);
  signal scl_padoen_o      : std_logic_vector(0 downto 0);
  signal sda_padoen_o      : std_logic_vector(0 downto 0);
  signal testreg           : t_testreg;

  signal dout : std_logic_vector(7 downto 0);

begin  -- architecture rtl

  agwb_main_wb_1 : entity work.agwb_main_wb
    port map (
      slave_i           => wb_s_in,
      slave_o           => wb_s_out,
      i2c_master_wb_m_o => i2c_master_wb_m_o,
      i2c_master_wb_m_i => i2c_master_wb_m_i,
      testreg_o         => testreg,
      rst_n_i           => rst_n_i,
      clk_sys_i         => clk_sys_i);

  i2c_master_1 : entity work.i2c_master_top
    generic map (
      ARST_LVL => '0',
      g_num_interfaces => 1)
    port map (
      wb_clk_i     => clk_sys_i,
      wb_rst_i     => not rst_n_i,
      arst_i       => rst_n_i,
      wb_adr_i     => i2c_master_wb_m_o.adr(2 downto 0),
      wb_dat_i     => i2c_master_wb_m_o.dat(7 downto 0),
      wb_dat_o     => dout,
      wb_we_i      => i2c_master_wb_m_o.we,
      wb_stb_i     => i2c_master_wb_m_o.stb,
      wb_cyc_i     => i2c_master_wb_m_o.cyc,
      wb_ack_o     => i2c_master_wb_m_i.ack,
      inta_o       => open,
      scl_pad_i    => scl_pad_i,
      scl_pad_o    => scl_pad_o,
      scl_padoen_o => scl_padoen_o,
      sda_pad_i    => sda_pad_i,
      sda_pad_o    => sda_pad_o,
      sda_padoen_o => sda_padoen_o);

  i2c_master_wb_m_i.dat(7 downto 0)  <= dout;
  i2c_master_wb_m_i.dat(31 downto 8) <= (others => '0');

  scl_pad_i(0) <= i2c_scl;
  i2c_scl      <= '0' when (scl_pad_o(0) = '0') and (scl_padoen_o(0) = '0') else 'Z';

  sda_pad_i(0) <= i2c_sda;
  i2c_sda      <= '0' when (sda_pad_o(0) = '0') and (sda_padoen_o(0) = '0') else 'Z';

end architecture rtl;
