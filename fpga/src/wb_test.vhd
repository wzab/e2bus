-------------------------------------------------------------------------------
-- Title      : WB test slave
-- Project    : 
-------------------------------------------------------------------------------
-- File       : wb_test.vhd
-- Author     : FPGA Developer  <xl@wzab.nasz.dom>
-- Company    : 
-- Created    : 2018-04-16
-- Last update: 2018-09-03
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

entity wb_test_slvx is
  port (
    slv_clk_i   : in  std_logic;
    slv_rst_i   : in  std_logic;
    slv_dat_i   : in  std_logic_vector(31 downto 0);
    slv_dat_o   : out std_logic_vector(31 downto 0);
    slv_adr_i   : in  std_logic_vector(31 downto 0);
    slv_cyc_i   : in  std_logic;
    slv_lock_i  : in  std_logic;
    slv_sel_i   : in  std_logic;
    slv_we_i    : in  std_logic;
    slv_ack_o   : out std_logic;
    slv_err_o   : out std_logic;
    slv_rty_o   : out std_logic;
    slv_stall_o : out std_logic;
    slv_stb_i   : in  std_logic
    );
end wb_test_slvx;

architecture rtl of wb_test_slvx is

  type T_MEM is array (0 to 1023) of std_logic_vector(31 downto 0);
  signal mem         : T_MEM                 := (others => (others => '0'));
  signal tst_counter : unsigned(31 downto 0) := (others => '0');

begin
  -- At the moment we do not generate errors nor stalls
  slv_rty_o   <= '0';
  slv_err_o   <= '0';
  slv_stall_o <= '0';

  process (slv_clk_i) is
    variable v_read : std_logic_vector(31 downto 0);
  begin  -- process
    if slv_clk_i'event and slv_clk_i = '1' then  -- rising clock edge
      if slv_rst_i = '1' then           -- synchronous reset (active high)
        v_read      := (others => '0');
        slv_ack_o   <= '0';
        slv_dat_o   <= (others => '0');
        tst_counter <= (others => '0');
      else
        v_read := (others => '0');
        -- Decrement test counter
        if to_integer(tst_counter) /= 0 then
          tst_counter <= tst_counter - 1;
        end if;
        if(slv_stb_i = '1') then
          slv_ack_o <= '1';
          if slv_we_i = '1' then
            -- Write access
            if slv_adr_i(30) = '0' then
              -- simple memory
              mem(to_integer(unsigned(slv_adr_i(9 downto 0)))) <= slv_dat_i;
            else
              -- counter
              tst_counter <= unsigned(slv_dat_i);
            end if;
          else
            -- Read access
            if slv_adr_i(30) = '0' then
              v_read := mem(to_integer(unsigned(slv_adr_i(9 downto 0))));
              if slv_adr_i(31) = '0' then
                v_read := std_logic_vector(unsigned(v_read)+unsigned(slv_adr_i)+12);
              end if;
            else
              v_read := std_logic_vector(tst_counter);
            end if;
          end if;
        else
          slv_ack_o <= '0';
        end if;
      end if;
      slv_dat_o <= v_read;
    end if;
  end process;

end architecture rtl;

