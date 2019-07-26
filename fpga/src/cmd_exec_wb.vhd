-------------------------------------------------------------------------------
-- Title      : e2bus controller
-- Project    : 
-------------------------------------------------------------------------------
-- File       : cmd_exec.vhd
-- Author     : Wojciech M. Zabolotny  <wzab01@gmail.com>
-- Company    : 
-- Created    : 2018-03-10
-- Last update: 2019-07-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This is the command executor of the e2bus controller
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-03-01  1.0      WZab    Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.e2bus_pkg.all;

entity cmd_exec_wb is

  port (
    -- WB bus interface

    wb_adr_o   : out std_logic_vector(31 downto 0);
    wb_dat_o   : out std_logic_vector(31 downto 0);
    wb_dat_i   : in  std_logic_vector(31 downto 0);
    wb_we_o    : out std_logic;
    wb_sel_o   : out std_logic_vector(3 downto 0);
    wb_stb_o   : out std_logic;
    wb_ack_i   : in  std_logic;
    wb_cyc_o   : out std_logic;
    wb_clk     : out std_logic;
    -- WB optional signals
    wb_err_i   : in  std_logic;
    wb_rty_i   : in  std_logic;
    wb_stall_i : in  std_logic;

    -- CMD FRAME descriptor
    desc_din      : in  std_logic_vector(C_CDESC_DBITS-1 downto 0);
    -- CMD FRAME DPR interface (it is essential, that it runs on sys_clk!)
    cmd_frame_ad  : out std_logic_vector(C_CFR_SYS_ABITS-1 downto 0);
    cmd_frame_din : in  std_logic_vector(C_CFR_SYS_DBITS-1 downto 0);
    -- RESP DPR interface (it is essential, that it runs on sys_clk!)
    resp_ad       : out std_logic_vector(C_RESP_SYS_ABITS-1 downto 0);
    resp_dout     : out std_logic_vector(31 downto 0);
    resp_wr       : out std_logic;
    -- RESP descriptors interface
    fr_full       : in  std_logic;
    fr_num        : out unsigned(14 downto 0);
    fr_length     : out unsigned(15 downto 0);
    fr_cmd_num    : out std_logic_vector(7 downto 0);
    fr_wr         : out std_logic;
    -- Handshake interface
    exec_start    : in  std_logic;
    exec_ack      : out std_logic;
    -- Reset
    rst_p         : in  std_logic;
    -- Clock
    sys_clk       : in  std_logic);


end entity cmd_exec_wb;

architecture rtl of cmd_exec_wb is

  attribute keep       : string;
  attribute mark_debug : string;

  --signal s_exec_ack  : std_logic                                     := '0';
  --signal bc_cmd_av   : std_logic                                     := '0';
  --signal bc_cmd_end  : std_logic                                     := '0';
  signal bc_cmd_ack                   : std_logic                                     := '0';
  signal bc_exec_ack                  : std_logic                                     := '0';
  attribute keep of bc_exec_ack       : signal is "true";
  attribute mark_debug of bc_exec_ack : signal is "true";
  attribute keep of bc_cmd_ack        : signal is "true";
  attribute mark_debug of bc_cmd_ack  : signal is "true";
  signal bc_cmd_in                    : std_logic_vector(31 downto 0)                 := (others => '0');
  signal bc_resp_out                  : std_logic_vector(31 downto 0)                 := (others => '0');
  signal bc_resp_av                   : std_logic                                     := '0';
  signal bc_resp_end                  : std_logic                                     := '0';
  signal s_resp_ad                    : std_logic_vector(C_RESP_SYS_ABITS-1 downto 0) := (others => '0');

  type T_CE1_STATE is (SCE1_IDLE, SCE1_START, SCE1_END, SCE1_DEL1, SCE1_DEL2);

  type T_REGS is record
    state         : T_CE1_STATE;
    bc_exec_start : std_logic;
    exec_ack      : std_logic;
    cmd_frame_ad  : unsigned(C_CFR_SYS_ABITS-1 downto 0);
  end record T_REGS;

  constant C_R_INIT : T_REGS := (
    state         => SCE1_IDLE,
    bc_exec_start => '0',
    exec_ack      => '0',
    cmd_frame_ad  => (others => '0')
    );

  signal r, r_n             : T_REGS := C_R_INIT;
  attribute keep of r       : signal is "true";
  attribute mark_debug of r : signal is "true";

  type C_COMB is record
    cmd_frame_ad : std_logic_vector(C_CFR_SYS_ABITS-1 downto 0);
    cmd_av       : std_logic;
    cmd_end      : std_logic;
  end record C_COMB;

  constant C_DEFAULT : C_COMB := (
    cmd_frame_ad => (others => '0'),
    cmd_av       => '0',
    cmd_end      => '0'
    );

  signal c : C_COMB := C_DEFAULT;

  type T_CE2_STATE is (S2_IDLE, S2_HANDLE, S2_DELAY, S2_END);

  type T_CE2_REGS is record
    state        : T_CE2_STATE;
    resp_len     : unsigned(8 downto 0);
    last         : std_logic;
    exec_ack     : std_logic;
    resp_frm_num : unsigned(14 downto 0);
    resp_wrd_ad  : unsigned(7 downto 0);
    del_cnt      : integer;
  end record T_CE2_REGS;

  constant C_R2_INIT : T_CE2_REGS := (
    state        => S2_IDLE,
    resp_len     => (others => '0'),
    exec_ack     => '0',
    last         => '0',
    resp_frm_num => (others => '0'),
    resp_wrd_ad  => (others => '0'),
    del_cnt      => 0
    );

  signal r2, r2_n            : T_CE2_REGS := C_R2_INIT;
  attribute keep of r2       : signal is "true";
  attribute mark_debug of r2 : signal is "true";


  type C2_COMB is record
    resp_wrd_ad : std_logic_vector(7 downto 0);
    resp_dout   : std_logic_vector(31 downto 0);
    resp_wr     : std_logic;
    fr_num      : unsigned(14 downto 0);
    fr_length   : unsigned(15 downto 0);
    fr_cmd_num  : std_logic_vector(7 downto 0);
    fr_wr       : std_logic;
    bc_resp_ack : std_logic;
  end record C2_COMB;

  constant C2_DEFAULT : C2_COMB := (
    resp_wrd_ad => (others => '0'),
    resp_dout   => (others => '0'),
    resp_wr     => '0',
    fr_num      => (others => '0'),
    fr_length   => (others => '0'),
    fr_cmd_num  => (others => '0'),
    fr_wr       => '0',
    bc_resp_ack => '0'
    );

  signal c2 : C2_COMB := C2_DEFAULT;

begin  -- architecture rtl

  wb_ctrl_1 : entity work.wb_ctrl
    port map (
      wb_adr_o   => wb_adr_o,
      wb_dat_o   => wb_dat_o,
      wb_dat_i   => wb_dat_i,
      wb_we_o    => wb_we_o,
      wb_sel_o   => wb_sel_o,
      wb_stb_o   => wb_stb_o,
      wb_ack_i   => wb_ack_i,
      wb_cyc_o   => wb_cyc_o,
      wb_clk     => sys_clk,
      wb_err_i   => wb_err_i,
      wb_rty_i   => wb_rty_i,
      wb_stall_i => wb_stall_i,
      exec_start => r.bc_exec_start,
      exec_ack   => bc_exec_ack,
      cmd_in     => bc_cmd_in,
      cmd_av     => c.cmd_av,
      cmd_end    => c.cmd_end,
      cmd_ack    => bc_cmd_ack,
      resp_out   => bc_resp_out,
      resp_av    => bc_resp_av,
      resp_end   => bc_resp_end,
      resp_ack   => c2.bc_resp_ack,
      rst_p      => rst_p,
      sys_clk    => sys_clk);

  wb_clk                                 <= sys_clk;
  cmd_frame_ad                           <= std_logic_vector(c.cmd_frame_ad);
  s_resp_ad(C_RESP_SYS_ABITS-1 downto 8) <= std_logic_vector(r2.resp_frm_num(C_RESP_SYS_FBITS-1 downto 0));
  s_resp_ad(7 downto 0)                  <= std_logic_vector(c2.resp_wrd_ad);
  exec_ack                               <= r.exec_ack;
  resp_ad                                <= s_resp_ad;
  resp_wr                                <= c2.resp_wr;
  resp_dout                              <= c2.resp_dout;
  bc_cmd_in                              <= cmd_frame_din;
  fr_num                                 <= c2.fr_num;
  fr_wr                                  <= c2.fr_wr;
  fr_cmd_num                             <= c2.fr_cmd_num;
  fr_length                              <= c2.fr_length;

  cp1 : process (bc_cmd_ack, bc_exec_ack, desc_din, exec_start, r) is
    variable v_cmd_frame_ad     : std_logic_vector(C_CFR_ABITS-1 downto 0) := (others => '0');
    variable v_cmd_frame_sys_ad : unsigned(C_CFR_SYS_ABITS-1 downto 0)     := (others => '0');
  begin  -- process cp1
    r_n            <= r;
    c              <= C_DEFAULT;
    c.cmd_frame_ad <= std_logic_vector(r.cmd_frame_ad);
    case r.state is
      when SCE1_IDLE =>
        if exec_start /= r.exec_ack then
          -- We prepare for processing of data
          v_cmd_frame_ad     := stlv2cdesc_pstart(desc_din);
          v_cmd_frame_sys_ad := unsigned(v_cmd_frame_ad(v_cmd_frame_ad'left downto 2))+1;
          -- We add 1 to skip the header!
          r_n.cmd_frame_ad   <= v_cmd_frame_sys_ad;
          -- Speed up exposing the address
          c.cmd_frame_ad     <= std_logic_vector(v_cmd_frame_sys_ad);
          -- Start the bus controller
          r_n.bc_exec_start  <= not r.bc_exec_start;
          r_n.state          <= SCE1_START;
        end if;
      when SCE1_START =>
        c.cmd_av <= '1';
        if bc_exec_ack = r.bc_exec_start then
          -- Here we handle premature end of bus controller execution (e.g. due
          -- to error, or END command)
          r_n.state <= SCE1_END;
        elsif bc_cmd_ack = '1' then
          v_cmd_frame_ad     := stlv2cdesc_pend(desc_din);
          v_cmd_frame_sys_ad := unsigned(v_cmd_frame_ad(v_cmd_frame_ad'left downto 2));
          if r.cmd_frame_ad = v_cmd_frame_sys_ad then
            -- Handle the end of data condition
            r_n.state <= SCE1_END;
          else
            r_n.cmd_frame_ad <= r.cmd_frame_ad + 1;
            c.cmd_frame_ad   <= std_logic_vector(r.cmd_frame_ad + 1);
          end if;
        end if;
      when SCE1_END =>
        c.cmd_end <= '1';
        -- Currently we will wait until the bus controller finishes its operation
        -- (It should be checked if it is really necessary!)
        r_n.state <= SCE1_DEL1;
      when SCE1_DEL1 =>
        c.cmd_end <= '1';
        r_n.state <= SCE1_DEL2;
      when SCE1_DEL2 =>
        if bc_exec_ack = r.bc_exec_start then
          r_n.exec_ack <= exec_start;
        end if;
        r_n.state <= SCE1_IDLE;
      when others => null;
    end case;
  end process cp1;

  ps1 : process (sys_clk) is
  begin  -- process ps1
    if sys_clk'event and sys_clk = '1' then  -- rising clock edge
      if rst_p = '1' then                    -- synchronous reset (active high)
        r <= C_R_INIT;
      else
        r <= r_n;
      end if;
    end if;
  end process ps1;

  -- Process responsible for handling responses
  cp2 : process (bc_resp_av, bc_resp_end, bc_resp_out, desc_din, fr_full, r2) is
  begin  -- process cp2
    r2_n           <= r2;
    c2             <= C2_DEFAULT;
    c2.resp_wrd_ad <= std_logic_vector(r2.resp_wrd_ad);
    c2.fr_num      <= r2.resp_frm_num;
    case r2.state is
      when S2_IDLE =>
        -- We start with no response frame open
        -- First we need to create such a frame
        if fr_full = '0' then
          -- There is a free response frame
          -- Write the frame number
          c2.resp_wrd_ad      <= (others => '0');
          c2.resp_dout        <= '0' & std_logic_vector(r2.resp_frm_num) & x"4321";
          c2.resp_wr          <= '1';
          -- Prepare writing of new words
          r2_n.resp_wrd_ad    <= (others => '0');
          r2_n.resp_wrd_ad(0) <= '1';
          r2_n.resp_len       <= to_unsigned(1, r2_n.resp_len'left+1);
          r2_n.state          <= S2_HANDLE;
        end if;
      when S2_HANDLE =>
        if bc_resp_av = '1' then
          c2.resp_dout   <= bc_resp_out;
          c2.resp_wr     <= '1';
          c2.bc_resp_ack <= '1';
          -- Check if we need to write the response
          if (bc_resp_end = '1') then
            r2_n.last  <= '1';
            r2_n.state <= S2_END;
          elsif (r2.resp_len > 250) then
            r2_n.last  <= '0';
            r2_n.state <= S2_END;
          else
            r2_n.resp_wrd_ad <= r2.resp_wrd_ad + 1;
            r2_n.resp_len    <= r2.resp_len + 1;
          end if;
        end if;
      when S2_END =>
        c2.resp_wrd_ad <= (others => '0');
        c2.resp_dout   <= '0' & std_logic_vector(r2.resp_frm_num) & std_logic_vector(to_unsigned(to_integer(r2.resp_len), 16));
        if r2.last = '1' then
          c2.resp_dout(31) <= '1';
        end if;
        c2.resp_wr        <= '1';
        r2_n.resp_frm_num <= r2.resp_frm_num + 1;
        c2.fr_length      <= to_unsigned(4*to_integer(r2.resp_len), 16);
        c2.fr_num         <= r2.resp_frm_num;
        c2.fr_cmd_num     <= stlv2cdesc_frm_num(desc_din)(7 downto 0);
        c2.fr_wr          <= '1';
        r2_n.del_cnt      <= 3;
        r2_n.state        <= S2_DELAY;
      when S2_DELAY =>
        -- Delay to stabilize fr_full flag?
        if r2.del_cnt = 0 then
          r2_n.state <= S2_IDLE;
        else
          r2_n.del_cnt <= r2.del_cnt - 1;
        end if;
      when others => null;
    end case;
  end process cp2;

  ps2 : process (sys_clk) is
  begin  -- process ps1
    if sys_clk'event and sys_clk = '1' then  -- rising clock edge
      if rst_p = '1' then                    -- synchronous reset (active high)
        r2 <= C_R2_INIT;
      else
        r2 <= r2_n;
      end if;
    end if;
  end process ps2;

end architecture rtl;
