-------------------------------------------------------------------------------
-- Wrapper for CMD FRM DPR IP core
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity cmd_desc_dpr is
  port
    (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(4 downto 0);
      dina  : in  std_logic_vector(41 downto 0);
      douta : out std_logic_vector(41 downto 0);
      clkb  : in  std_logic;
      web   : in  std_logic_vector(0 downto 0);
      addrb : in  std_logic_vector(4 downto 0);
      dinb  : in  std_logic_vector(41 downto 0);
      doutb : out std_logic_vector(41 downto 0)
      );
end entity cmd_desc_dpr;


architecture SYN of cmd_desc_dpr is

  component cmd_desc_dpr_alt is
    port (
      address_a : IN  STD_LOGIC_VECTOR (4 DOWNTO 0);
      address_b : IN  STD_LOGIC_VECTOR (4 DOWNTO 0);
      clock_a   : IN  STD_LOGIC := '1';
      clock_b   : IN  STD_LOGIC;
      data_a    : IN  STD_LOGIC_VECTOR (41 DOWNTO 0);
      data_b    : IN  STD_LOGIC_VECTOR (41 DOWNTO 0);
      wren_a    : IN  STD_LOGIC := '0';
      wren_b    : IN  STD_LOGIC := '0';
      q_a       : OUT STD_LOGIC_VECTOR (41 DOWNTO 0);
      q_b       : OUT STD_LOGIC_VECTOR (41 DOWNTO 0));
  end component cmd_desc_dpr_alt;

begin

  cmd_desc_dpr_alt_1 : entity work.cmd_desc_dpr_alt
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
