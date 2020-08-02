-------------------------------------------------------------------------------
-- Wrapper for CMD FRM DPR IP core
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity cmd_frm_dpr is
  port
    (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(12 downto 0);
      dina  : in  std_logic_vector(7 downto 0);
      douta : out std_logic_vector(7 downto 0);
      clkb  : in  std_logic;
      web   : in  std_logic_vector(0 downto 0);
      addrb : in  std_logic_vector(10 downto 0);
      dinb  : in  std_logic_vector(31 downto 0);
      doutb : out std_logic_vector(31 downto 0)
      );
end entity cmd_frm_dpr;


architecture SYN of cmd_frm_dpr is

  component cmd_frm_dpr_alt is
    port
      (
        address_a : in  std_logic_vector (12 downto 0);
        address_b : in  std_logic_vector (10 downto 0);
        clock_a   : in  std_logic := '1';
        clock_b   : in  std_logic;
        data_a    : in  std_logic_vector (7 downto 0);
        data_b    : in  std_logic_vector (31 downto 0);
        wren_a    : in  std_logic := '0';
        wren_b    : in  std_logic := '0';
        q_a       : out std_logic_vector (7 downto 0);
        q_b       : out std_logic_vector (31 downto 0)
        );
  end component cmd_frm_dpr_alt;


begin

  cmd_frm_dpr_alt_1 : entity work.cmd_frm_dpr_alt
    port map (
      address_a => addra,
      address_b => addrb,
      clock_a   => clka,
      clock_b   => clkb,
      data_a    => dina,
      data_b    => dinb,
      wren_a    => wea(0),
      wren_b    => web(0),
      q_a       => douta,
      q_b       => doutb);

end SYN;
