-------------------------------------------------------------------------------
-- Title      : wb_pkg
-- Project    : 
-------------------------------------------------------------------------------
-- File       : wb_pkg.vhd
-- Author     : Wojciech M. Zabołotny <wzab01@gmail.com>
-- Company    : 
-- Created    : 2019-07-17
-- Last update: 2019-07-17
-- Platform   :
-- License    : Public domain or CC0 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: That package encapsulates signals for 32-bit Wishbone bus
--              in records. It is simply a lite version of types provided
--              by wishbone_pkg from OHWR.
--              It allows you to simplify interface in your blocks without
--              including the huge wishbone_pkg.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2019 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-17  1.0      WZab	Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package wb_pkg is
  type t_wb_m2s is record
    adr : std_logic_vector(31 downto 0);
    dat : std_logic_vector(31 downto 0);
    sel : std_logic_vector(3 downto 0);
    stb : std_logic;
    cyc : std_logic;
    we  : std_logic;
  end record t_wb_m2s;

  type t_wb_s2m is record
    dat : std_logic_vector(31 downto 0);
    ack : std_logic;
    err : std_logic;
    rty : std_logic;
    stall  : std_logic;
  end record t_wb_s2m;
end package;
