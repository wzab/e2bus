-------------------------------------------------------------------------------
-- Title      : WB test slave
-- Project    : 
-------------------------------------------------------------------------------
-- File       : wb_test.vhd
-- Author     : FPGA Developer  <xl@wzab.nasz.dom>
-- Company    : 
-- Created    : 2018-04-16
-- Last update: 2019-07-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: It just allows you to check in simulation if the access is correct
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-07-26  1.0      xl      Created
-------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.wb_pkg.all;

entity wb_test_slvx is
  port (
    wb_s2m : out t_wb_s2m;
    wb_m2s : in  t_wb_m2s;
    wb_clk : in std_logic;
    wb_rst : in std_logic
    );
end wb_test_slvx;

architecture rtl of wb_test_slvx is

 
  type T_MEM is array (0 to 1023) of std_logic_vector(31 downto 0);
  signal mem         : T_MEM                 := (others => (others => '0'));
  signal tst_counter : unsigned(31 downto 0) := (others => '0');

begin
  -- At the moment we do not generate errors nor stalls
  wb_s2m.rty  <= '0';
  wb_s2m.err   <= '0';
  wb_s2m.stall <= '0';

  process (wb_clk) is
    variable v_read : std_logic_vector(31 downto 0);
  begin  -- process
    if wb_clk'event and wb_clk = '1' then  -- rising clock edge
      if wb_rst = '1' then           -- synchronous reset (active high)
        v_read      := (others => '0');
        wb_s2m.ack   <= '0';
        wb_s2m.dat   <= (others => '0');
        tst_counter <= (others => '0');
      else
        v_read := (others => '0');
        -- Decrement test counter
        if to_integer(tst_counter) /= 0 then
          tst_counter <= tst_counter - 1;
        end if;
        if(wb_m2s.stb = '1') then
          wb_s2m.ack <= '1';
          if wb_m2s.we = '1' then
            -- Write access
            if wb_m2s.adr(30) = '0' then
              -- simple memory
              mem(to_integer(unsigned(wb_m2s.adr(9 downto 0)))) <= wb_m2s.dat;
            else
              -- counter
              tst_counter <= unsigned(wb_m2s.dat);
            end if;
          else
            -- Read access
            if wb_m2s.adr(30) = '0' then
              v_read := mem(to_integer(unsigned(wb_m2s.adr(9 downto 0))));
              if wb_m2s.adr(31) = '0' then
                v_read := std_logic_vector(unsigned(v_read)+unsigned(wb_m2s.adr)+12);
              end if;
            else
              v_read := std_logic_vector(tst_counter);
            end if;
          end if;
        else
          wb_s2m.ack <= '0';
        end if;
      end if;
      wb_s2m.dat <= v_read;
    end if;
  end process;

end architecture rtl;

