-------------------------------------------------------------------------------
-- Title      : synchronizer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : sync_stlv.vhd
-- Author     : Wojciech Zabolotny  <xl@wzab.nasz.dom>
-- Company    : 
-- Created    : 2018-03-11
-- Last update: 2019-07-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-03-11  1.0      xl	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

entity sync_stlv is
  
  generic (
    width : integer := 8);

  port (
    din    : in  std_logic_vector(width-1 downto 0);
    clk_in : in  std_logic;
    dout   : out std_logic_vector(width-1 downto 0);
    clk_out : in std_logic;
    rst_p : in std_logic
    );

end entity sync_stlv;

architecture rtl of sync_stlv is

  signal si0,si1,si2,si3,so1,so2,so0,so3  : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of si0, si1, si2, si3, so0, so1, so2, so3: signal is "TRUE";
  signal rst_in_0, rst_in_p, rst_out_0, rst_out_p  : std_logic := '1';
  signal sig_x : std_logic_vector(width-1 downto 0) := (others => '0');
  
begin  -- architecture rtl

  -- Synchronization of reset for clk_in
  r1: process (clk_in, rst_p) is
  begin  -- process r1
    if rst_p = '1' then                 -- asynchronous reset (active high)
      rst_in_0 <= '1';
      rst_in_p <= '1';
    elsif clk_in'event and clk_in = '1' then  -- rising clock edge
      rst_in_p <= rst_in_0;
      rst_in_0 <= rst_p;
    end if;
  end process r1;

  -- Synchronization of reset for clk_out
  r2: process (clk_out, rst_p) is
  begin  -- process r1
    if rst_p = '1' then                 -- asynchronous reset (active high)
      rst_out_0 <= '1';
      rst_out_p <= '1';
    elsif clk_out'event and clk_out = '1' then  -- rising clock edge
      rst_out_p <= rst_out_0;
      rst_out_0 <= rst_p;
    end if;
  end process r2;

  -- First stage of synchronization - with reverse clock
  process (clk_in) is
  begin  -- process
    if clk_in'event and clk_in = '0' then  -- rising clock edge
      if rst_in_p = '1' then           -- synchronous reset (active high)
        si0 <= '0';
      else
        si0 <= so3;
      end if;
    end if;
  end process;
  
  
  -- Sampling of input signal
  s1: process (clk_in) is
  begin  -- process s1
    if clk_in'event and clk_in = '1' then  -- rising clock edge
      if rst_in_p = '1' then            -- synchronous reset (active high)
        si1 <= '0';
        si2 <= '0';
        si3 <= '0';
      else
        if si2 = si3 then
          sig_x <= din;
          si3 <= not si3;
        end if;
        si1 <= si0;
        si2 <= si1;
      end if;
    end if;
  end process s1;

  -- First stage of synchronization - with reverse clock
  process (clk_out) is
  begin  -- process
    if clk_out'event and clk_out = '0' then  -- rising clock edge
      if rst_out_p = '1' then           -- synchronous reset (active high)
        so0 <= '0';
      else
        so0 <= si3;
      end if;
    end if;
  end process;
  
  -- Transferring the signal to the output
  process (clk_out) is
  begin  -- process
    if clk_out'event and clk_out = '1' then  -- rising clock edge
      if rst_out_p = '1' then           -- synchronous reset (active high)
        so1 <= '0';
        so2 <= '0';
        so3 <= '0';
      else
        so1 <= so0;
        so2 <= so1;
        so3 <= so2;
        if so3 /= so2 then
          dout <= sig_x;
        end if;
      end if;
    end if;
  end process;
end architecture rtl;
