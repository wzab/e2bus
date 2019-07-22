-------------------------------------------------------------------------------
-- Title      : wishbone_wb_pkg.vhd
-- Project    : 
-------------------------------------------------------------------------------
-- File       : wishbone_wb_pkg.vhd
-- Author     : Wojciech M. Zabolotny  <wzab01@gmail.com>
-- Company    :
-- Lincense   : Public Domain or CC0
-- Created    : 2019-07-17
-- Last update: 2019-07-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This package defines functions for translating between
--              32-bit version of wishbone signals defined in OHWR
--              wishbone_pkg.vhd and the "lite" version defined in wb_pkg.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2019 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-17  1.0      WZab    Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
use work.wb_pkg.all;

package wishbone_wb_pkg is
  function wishbone2wb_m2s (
    constant in_m2s : t_wishbone_master_out)
    return t_wb_m2s;
  function wb2wishbone_m2s (
    constant in_m2s : t_wb_m2s)
    return t_wishbone_master_out;
  function wishbone2wb_s2m (
    constant in_s2m : t_wishbone_master_in)
    return t_wb_s2m;
  function wb2wishbone_s2m (
    constant in_s2m : t_wb_s2m)
    return t_wishbone_master_in;

end package wishbone_wb_pkg;

package body wishbone_wb_pkg is

  function wishbone2wb_m2s (
    constant in_m2s : t_wishbone_master_out)
    return t_wb_m2s is
    variable res : t_wb_m2s;
  begin
    res.adr := in_m2s.adr;
    res.dat := in_m2s.dat;
    res.sel := in_m2s.sel;
    res.stb := in_m2s.stb;
    res.cyc := in_m2s.cyc;
    res.we  := in_m2s.we;
    res.stb := in_m2s.stb;
    return res;
  end function wishbone2wb_m2s;

  function wb2wishbone_m2s (
    constant in_m2s : t_wb_m2s)
    return t_wishbone_master_out is
    variable res : t_wishbone_master_out;
  begin
    res.adr := in_m2s.adr;
    res.dat := in_m2s.dat;
    res.stb := in_m2s.stb;
    res.cyc := in_m2s.cyc;
    res.we  := in_m2s.we;
    res.sel := in_m2s.sel;
    return res;
  end function wb2wishbone_m2s;

  function wishbone2wb_s2m (
    constant in_s2m : t_wishbone_master_in)
    return t_wb_s2m is
    variable res : t_wb_s2m;
  begin
    res.dat   := in_s2m.dat;
    res.ack   := in_s2m.ack;
    res.err   := in_s2m.err;
    res.rty   := in_s2m.rty;
    res.stall := in_s2m.stall;
    return res;
  end function wishbone2wb_s2m;

  function wb2wishbone_s2m (
    constant in_s2m : t_wb_s2m)
    return t_wishbone_master_in is
    variable res : t_wishbone_master_in;
  begin
    res.dat   := in_s2m.dat;
    res.ack   := in_s2m.ack;
    res.err   := in_s2m.err;
    res.rty   := in_s2m.rty;
    res.stall := in_s2m.stall;
    return res;
  end function wb2wishbone_s2m;
  
end wishbone_wb_pkg;
