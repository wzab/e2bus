-------------------------------------------------------------------------------
-- Wrapper for Altera version of the CMD ACK FIFO
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;

entity cmd_ack_fifo is
  port
    (
      rst    : in  std_logic;
      wr_clk : in  std_logic;
      rd_clk : in  std_logic;
      din    : in  std_logic_vector(15 downto 0);
      wr_en  : in  std_logic;
      rd_en  : in  std_logic;
      dout   : out std_logic_vector(15 downto 0);
      full   : out std_logic;
      empty  : out std_logic
      );
end entity cmd_ack_fifo;


architecture SYN of cmd_ack_fifo is

  component cmd_ack_fifo_alt
    port (
      aclr    : in  std_logic := '0';
      data    : in  std_logic_vector (15 downto 0);
      rdclk   : in  std_logic;
      rdreq   : in  std_logic;
      wrclk   : in  std_logic;
      wrreq   : in  std_logic;
      q       : out std_logic_vector (15 downto 0);
      rdempty : out std_logic;
      wrfull  : out std_logic
      );
  end component;


begin

  cmd_ack_fifo_alt_1 : entity work.cmd_ack_fifo_alt
    port map (
      aclr    => rst,
      data    => din,
      rdclk   => rd_clk,
      rdreq   => rd_en,
      wrclk   => wr_clk,
      wrreq   => wr_en,
      q       => dout,
      rdempty => empty,
      wrfull  => full);

end SYN;

