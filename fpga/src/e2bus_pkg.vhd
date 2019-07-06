library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package e2bus_pkg is

  constant proto_id : std_logic_vector(31 downto 0) := x"e2b50001";

  -- Constants related to exchange of packages
  constant C_CFR_ABITS : integer := 13;
  constant C_CFR_SYS_ABITS : integer := C_CFR_ABITS-2;
  constant C_CFR_DBITS : integer := 8;  -- At this side we have byte interface
  constant C_CFR_SYS_DBITS : integer := 32;  -- At this side we have 32-bit interface
  constant C_CDESC_ABITS : integer := 5;
  constant C_CDESC_DBITS : integer := 2*C_CFR_ABITS+16;  -- We need to store start
                                                         -- and end address
  -- functions to unpack the parts of the DESC DPR word
  function cdesc2stlv (
    constant pstart, pend : std_logic_vector(C_CFR_ABITS-1 downto 0);
    constant frm_num      : std_logic_vector(15 downto 0))
    return std_logic_vector;
  function stlv2cdesc_pstart (
    constant din : std_logic_vector(C_CDESC_DBITS-1 downto 0))
    return std_logic_vector;
  function stlv2cdesc_pend (
    constant din : std_logic_vector(C_CDESC_DBITS-1 downto 0))
    return std_logic_vector;
  function stlv2cdesc_frm_num (
    constant din : std_logic_vector(C_CDESC_DBITS-1 downto 0))
    return std_logic_vector;
  
  constant C_CACK_DBITS : integer := 16;  -- We just send the full command frame number
  constant C_RACK_ABITS : integer := 7;  -- We just send the full response frame number
  constant C_RACK_DBITS : integer := 31;  -- We send the 15 bits of the full response frame
                                          -- (bit 15 is always 1), and then 16
                                          -- bits of timestamp

  constant C_RESP_ABITS : integer := 12;
  -- We assume, that each response is up to 1024 bytes (256 words) long.
  -- It means, that the number of bits used to address the responses
  -- at the system side is equal to:
  -- Number of bits for indexing 32-bit words in responses
  constant C_RESP_SYS_ABITS : integer := C_RESP_ABITS-2;
  -- Number of bits used for indexing of response frames
  constant C_RESP_SYS_FBITS : integer := C_RESP_SYS_ABITS-8;
  constant C_RESP_SYS_N : integer := 2**(C_RESP_SYS_FBITS);
  
end package e2bus_pkg;

package body e2bus_pkg is
  
  function cdesc2stlv (
    constant pstart, pend : std_logic_vector(C_CFR_ABITS-1 downto 0);
    constant frm_num      : std_logic_vector(15 downto 0))
    return std_logic_vector is
    
    variable res : std_logic_vector(C_CDESC_DBITS-1 downto 0);
    variable sp, ep  : integer  := 0;
  begin  -- function cdesc2stlv
    sp := 15 ; ep := 0;
    res(sp downto ep) := frm_num;
    ep := sp+1 ; sp := sp + C_CFR_ABITS;
    res(sp downto ep) := pend;
    ep := sp+1 ; sp := sp + C_CFR_ABITS;
    res(sp downto ep) := pstart;
    return res;
  end function cdesc2stlv;

  function stlv2cdesc_pstart (
    constant din : std_logic_vector(C_CDESC_DBITS-1 downto 0))
    return std_logic_vector is

    variable res : std_logic_vector(C_CFR_ABITS-1 downto 0);
    variable sp, ep  : integer  := 0;
  begin  -- function cdesc2stlv
    ep := 16+C_CFR_ABITS;
    sp := ep + C_CFR_ABITS-1;
    res := din(sp downto ep);
    return res;
  end function stlv2cdesc_pstart;

  function stlv2cdesc_pend (
    constant din : std_logic_vector(C_CDESC_DBITS-1 downto 0))
    return std_logic_vector is

    variable res : std_logic_vector(C_CFR_ABITS-1 downto 0);
    variable sp, ep  : integer  := 0;
  begin  -- function cdesc2stlv
    ep := 16;
    sp := ep + C_CFR_ABITS-1;
    res := din(sp downto ep);
    return res;
  end function stlv2cdesc_pend;
  
  function stlv2cdesc_frm_num (
    constant din : std_logic_vector(C_CDESC_DBITS-1 downto 0))
    return std_logic_vector is

    variable res : std_logic_vector(15 downto 0);
    variable sp, ep  : integer  := 0;
  begin  -- function cdesc2stlv
    ep := 0;
    sp := ep+16-1;
    res := din(sp downto ep);
    return res;
  end function stlv2cdesc_frm_num;
  
end package body e2bus_pkg;
