-------------------------------------------------------------------------------
-- Title      : e2bus WB controller
-- Project    : 
-------------------------------------------------------------------------------
-- File       : cmd_exec.vhd
-- Author     : Wojciech M. Zabolotny  <wzab01@gmail.com>
-- Company    : 
-- Created    : 2018-03-10
-- Last update: 2019-07-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This is the stream driven WB controller for e2bus
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
--use work.e2bus_pkg.all;

entity wb_ctrl is

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
    wb_clk     : in  std_logic;
    -- WB optional signals
    wb_err_i   : in  std_logic;
    wb_rty_i   : in  std_logic;
    wb_stall_i : in  std_logic;

    -- Handshake interface
    exec_start : in  std_logic;
    exec_ack   : out std_logic;

    -- CMD words interface
    cmd_in  : in  std_logic_vector(31 downto 0);
    cmd_av  : in  std_logic;
    cmd_end : in  std_logic;
    cmd_ack : out std_logic;

    -- RESP words interface
    resp_out : out std_logic_vector(31 downto 0);
    resp_av  : out std_logic;
    resp_end : out std_logic;
    resp_ack : in  std_logic;

    -- Reset
    rst_p   : in std_logic;
    -- Clock
    sys_clk : in std_logic);

end entity wb_ctrl;

architecture rtl of wb_ctrl is

  attribute keep       : string;
  attribute mark_debug : string;

  constant C_STATUS_LEN : integer := 16;

  function cmd_is_write (
    constant cmd : std_logic_vector(31 downto 0))
    return boolean is
  begin  -- function cmd_is_write
    if cmd(31 downto 28) = "0001" then
      return true;
    else
      return false;
    end if;
  end function cmd_is_write;

  function cmd_is_read (
    constant cmd : std_logic_vector(31 downto 0))
    return boolean is
  begin  -- function cmd_is_write
    if cmd(31 downto 28) = "0010" then
      return true;
    else
      return false;
    end if;
  end function cmd_is_read;

  function cmd_is_rmw (
    constant cmd : std_logic_vector(31 downto 0))
    return boolean is
  begin  -- function cmd_is_write
    if cmd(31 downto 28) = "0011" then
      return true;
    else
      return false;
    end if;
  end function cmd_is_rmw;

  function cmd_is_rdntst (
    constant cmd : std_logic_vector(31 downto 0))
    return boolean is
  begin  -- function cmd_is_write
    if cmd(31 downto 28) = "0100" then
      return true;
    else
      return false;
    end if;
  end function cmd_is_rdntst;

  function cmd_is_multi_rdntst (
    constant cmd : std_logic_vector(31 downto 0))
    return boolean is
  begin  -- function cmd_is_write
    if cmd(31 downto 28) = "0101" then
      return true;
    else
      return false;
    end if;
  end function cmd_is_multi_rdntst;

  function cmd_is_eclr (
    constant cmd : std_logic_vector(31 downto 0))
    return boolean is
  begin  -- function cmd_is_write
    if cmd(31 downto 28) = "1111" then
      return true;
    else
      return false;
    end if;
  end function cmd_is_eclr;

  function cmd_is_end (
    constant cmd : std_logic_vector(31 downto 0))
    return boolean is
  begin  -- function cmd_is_write
    if cmd(31 downto 28) = "1110" then
      return true;
    else
      return false;
    end if;
  end function cmd_is_end;


  function wrcmd_dm (
    constant cmd : std_logic_vector(31 downto 0))
    return integer is
  begin  -- function wrcmd_dm
    return to_integer(unsigned(cmd(22 downto 21)));
  end function wrcmd_dm;

  function wrcmd_si (
    constant cmd : std_logic_vector(31 downto 0))
    return integer is
  begin  -- function wrcmd_dm
    return to_integer(unsigned(cmd(23 downto 23)));
  end function wrcmd_si;

  function wrcmd_ai (
    constant cmd : std_logic_vector(31 downto 0))
    return unsigned is
  begin  -- function wrcmd_dm
    return unsigned(cmd(20 downto 8));
  end function wrcmd_ai;

  function wrcmd_bl (
    constant cmd : std_logic_vector(31 downto 0))
    return unsigned is
  begin  -- function wrcmd_dm
    return unsigned(cmd(7 downto 0));
  end function wrcmd_bl;

  function rdcmd_sm (
    constant cmd : std_logic_vector(31 downto 0))
    return integer is
  begin  -- function wrcmd_dm
    return to_integer(unsigned(cmd(23 downto 22)));
  end function rdcmd_sm;

  function rdcmd_ai (
    constant cmd : std_logic_vector(31 downto 0))
    return unsigned is
  begin  -- function wrcmd_dm
    return unsigned(cmd(21 downto 12));
  end function rdcmd_ai;

  function rdcmd_bl (
    constant cmd : std_logic_vector(31 downto 0))
    return unsigned is
  begin  -- function wrcmd_dm
    return unsigned(cmd(11 downto 0));
  end function rdcmd_bl;

  function rmwcmd_oper (
    constant cmd : std_logic_vector(31 downto 0))
    return integer is
  begin  -- function wrcmd_dm
    return to_integer(unsigned(cmd(23 downto 20)));
  end function rmwcmd_oper;

  function rmwcmd_resp (
    constant cmd : std_logic_vector(31 downto 0))
    return boolean is
    variable res : boolean := false;
  begin  -- function wrcmd_dm
    if cmd(19) = '1' then
      res := true;
    else
      res := false;
    end if;
    return res;
  end function rmwcmd_resp;

  function rtstcmd_oper (
    constant cmd : std_logic_vector(31 downto 0))
    return integer is
  begin  -- function wrcmd_dm
    return to_integer(unsigned(cmd(23 downto 21)));
  end function rtstcmd_oper;

  function rtstcmd_delay (
    constant cmd : std_logic_vector(31 downto 0))
    return unsigned is
    variable res : unsigned(31 downto 0);
    variable pow : integer range 0 to 15;
  begin  -- function wrcmd_dm
    res             := (others => '0');
    res(5 downto 0) := unsigned(cmd(5 downto 0));
    pow             := to_integer(unsigned(cmd(9 downto 6)));
    res             := shift_left(res, pow);
    return res;
  end function rtstcmd_delay;

  function rtstcmd_repeat (
    constant cmd : std_logic_vector(31 downto 0))
    return unsigned is
    variable res : unsigned(11 downto 0);
  begin  -- function wrcmd_dm
    res              := (others => '0');
    res(10 downto 0) := unsigned(cmd(20 downto 10));
    return res;
  end function rtstcmd_repeat;

  type T_SBC_STATE is (SBC_IDLE, SBC_START, SBC_WRITE0, SBC_READ0, SBC_RMW0,
                       SBC_RTST0, SBC_RTST1, SBC_RTST2, SBC_RTST3, SBC_RTST4,
                       SBC_MRTST0, SBC_MRTST1, SBC_MRTST2, SBC_MRTST3, SBC_MRTST4, SBC_MRTST5,
                       SBC_DELAY,
                       SBC_WRITE1, SBC_WRITE2, SBC_WRITE3, SBC_END, SBC_END2,
                       SBC_READ1, SBC_READ1b, SBC_READ2,
                       SBC_RMW1, SBC_RMW2, SBC_RMW3, SBC_RMW4, SBC_RMW5);
  type T_SBC_REGS is record
    state     : T_SBC_STATE;
    command   : std_logic_vector(31 downto 0);
    bus_ad    : unsigned(31 downto 0);
    bus_dout  : std_logic_vector(31 downto 0);
    wreg      : std_logic_vector(31 downto 0);
    wreg2     : std_logic_vector(31 downto 0);
    delay_cnt : unsigned(31 downto 0);
    resp_dout : std_logic_vector(31 downto 0);
    resp_av   : std_logic;
    wb_stb_o  : std_logic;
    wb_cyc_o  : std_logic;
    wb_we_o   : std_logic;
    in_error  : boolean;
    cycle_cnt : unsigned(11 downto 0);
    status    : unsigned(C_STATUS_LEN -1 downto 0);
    exec_ack  : std_logic;
    cmd_cnt   : unsigned(10 downto 0);
  end record T_SBC_REGS;

  constant C_SBC_REGS_INIT : T_SBC_REGS := (
    state     => SBC_IDLE,
    command   => (others => '0'),
    bus_ad    => (others => '0'),
    bus_dout  => (others => '0'),
    wreg      => (others => '0'),
    wreg2     => (others => '0'),
    delay_cnt => (others => '0'),
    resp_dout => (others => '0'),
    resp_av   => '0',
    wb_stb_o  => '0',
    wb_cyc_o  => '0',
    wb_we_o   => '0',
    in_error  => false,
    cycle_cnt => (others => '0'),
    status    => (others => '0'),
    exec_ack  => '0',
    cmd_cnt   => (others => '0')
    );

  type T_SBC_COMB is record
    cmd_ack  : std_logic;
    resp_end : std_logic;
  end record T_SBC_COMB;

  constant C_SBC_COMB_DEFAULT : T_SBC_COMB := (
    cmd_ack  => '0',
    resp_end => '0'
    );

  signal r, r_n             : T_SBC_REGS := C_SBC_REGS_INIT;
  attribute keep of r       : signal is "true";
  attribute mark_debug of r : signal is "true";
  signal c                  : T_SBC_COMB := C_SBC_COMB_DEFAULT;
  signal exec_start_sync    : std_logic  := '0';

begin  -- architecture rtl

  wb_adr_o <= std_logic_vector(r.bus_ad);
  wb_dat_o <= r.bus_dout;
  wb_stb_o <= r.wb_stb_o;
  wb_cyc_o <= r.wb_cyc_o;
  wb_we_o  <= r.wb_we_o;
  wb_sel_o <= (others => '1');

  resp_av  <= r.resp_av;
  resp_out <= r.resp_dout;
  resp_end <= c.resp_end;

  cmd_ack  <= c.cmd_ack;
  exec_ack <= r.exec_ack;

  -- Main state machine
  -- We must ensure that the read words are counted (for error handling)
  p1 : process (cmd_av, cmd_end, cmd_in, exec_start_sync, r, resp_ack,
                wb_ack_i, wb_dat_i, wb_err_i) is

    variable verror : integer := 0;
    procedure start_wr is
    begin  -- procedure start_wr
      r_n.wb_stb_o <= '1';
      r_n.wb_cyc_o <= '1';
      r_n.wb_we_o  <= '1';
    end procedure start_wr;

    procedure start_rd is
    begin  -- procedure start_wr
      r_n.wb_stb_o <= '1';
      r_n.wb_cyc_o <= '1';
      r_n.wb_we_o  <= '0';
    end procedure start_rd;

    procedure stop_all is
    begin  -- procedure start_wr
      r_n.wb_stb_o <= '0';
      r_n.wb_cyc_o <= '0';
      r_n.wb_we_o  <= '0';
    end procedure stop_all;

    procedure set_error (
      constant code : in integer) is
    begin  -- procedure set_error
      r_n.status   <= to_unsigned(code, C_STATUS_LEN);
      -- remember, that we are in error state
      r_n.in_error <= true;
      -- After that we just go to the END state
      r_n.state    <= SBC_END;
    end procedure set_error;

  begin  -- process p1
    c   <= C_SBC_COMB_DEFAULT;
    r_n <= r;
    case r.state is
      when SBC_IDLE =>
        if exec_start_sync /= r.exec_ack then
          -- Prepare for execution,
          -- clear the command counter:
          r_n.cmd_cnt <= (others => '0');
          -- clear the error status
          r_n.status  <= (others => '0');
          r_n.state   <= SBC_START;
        end if;
      when SBC_START =>
        if cmd_av = '1' then
          -- New command is available
          -- Analyze the command
          r_n.command <= cmd_in;
          -- If we are in error state, then the only acceptable command is
          -- Error Clear (it must be at the begining of the command frame!)
          if r.in_error then
            if cmd_is_eclr(cmd_in) then
              r_n.in_error <= false;
              c.cmd_ack    <= '1';
            else
              set_error(1);
            end if;
          else
            if cmd_is_write(cmd_in) then
              r_n.state <= SBC_WRITE0;
              c.cmd_ack <= '1';
            elsif cmd_is_read(cmd_in) then
              r_n.state <= SBC_READ0;
              c.cmd_ack <= '1';
            elsif cmd_is_rmw(cmd_in) then
              r_n.state <= SBC_RMW0;
              c.cmd_ack <= '1';
            elsif cmd_is_rdntst(cmd_in) then
              r_n.state <= SBC_RTST0;
              c.cmd_ack <= '1';
            elsif cmd_is_multi_rdntst(cmd_in) then
              r_n.state <= SBC_MRTST0;
              c.cmd_ack <= '1';
            elsif cmd_is_end(cmd_in) then
              r_n.state <= SBC_END;
              c.cmd_ack <= '1';
            else
              -- Unknown command, generate error condition!
              set_error(2);
            end if;
          end if;
        elsif cmd_end = '1' then
          r_n.state <= SBC_END;
        end if;
      when SBC_WRITE0 =>
        if cmd_av = '1' then
          -- Read the start address
          r_n.bus_ad                <= unsigned(cmd_in);
          c.cmd_ack                 <= '1';
          -- Program the cycle counter (write uses shorter counter!)
          r_n.cycle_cnt             <= (others => '0');
          r_n.cycle_cnt(7 downto 0) <= wrcmd_bl(r.command);
          r_n.state                 <= SBC_WRITE1;
        elsif cmd_end = '1' then
          -- error
          stop_all;
          set_error(3);
        end if;
      when SBC_WRITE1 =>
        if cmd_av = '1' then
          r_n.bus_dout <= cmd_in;
          start_wr;
          r_n.state    <= SBC_WRITE2;
          c.cmd_ack    <= '1';
        elsif cmd_end = '1' then
          stop_all;
          set_error(4);
        end if;
      when SBC_WRITE2 =>
        -- Wait for end of the cycle (we do not support wb_rty_i (yet?))
        if wb_ack_i = '1' then
          -- Cycle ended normally
          stop_all;
          r_n.state <= SBC_WRITE3;
        elsif wb_err_i = '1' then
          stop_all;
          set_error(5);
        end if;
      when SBC_WRITE3 =>
        -- Decrease the cycle count;
        if to_integer(r.cycle_cnt) /= 0 then
          r_n.cycle_cnt <= r.cycle_cnt - 1;
        end if;
        -- Now we must decide if the whole transfer is done
        if to_integer(r.cycle_cnt) = 0 then
          r_n.state <= SBC_START;
        else
          if wrcmd_dm(r.command) = 1 then
            r_n.bus_ad <= r.bus_ad + wrcmd_ai(r.command);
          elsif wrcmd_dm(r.command) = 2 then
            r_n.bus_ad <= r.bus_ad - wrcmd_ai(r.command);
          end if;
          -- Check if we need to read the next word to write
          if wrcmd_si(r.command) = 1 then
            if cmd_av = '1' then
              r_n.bus_dout <= cmd_in;
              c.cmd_ack    <= '1';
              start_wr;
              r_n.state    <= SBC_WRITE2;
            elsif cmd_end = '1' then
              stop_all;
              set_error(6);
            end if;
          else
            r_n.state <= SBC_WRITE2;
          end if;
        end if;
      when SBC_READ0 =>
        if cmd_av = '1' then
          -- Read the start address
          r_n.bus_ad    <= unsigned(cmd_in);
          c.cmd_ack     <= '1';
          -- Program the cycle counter
          r_n.cycle_cnt <= rdcmd_bl(r.command);
          start_rd;
          r_n.state     <= SBC_READ1;
        elsif cmd_end = '1' then
          -- error!
          stop_all;
          set_error(7);
        end if;
      when SBC_READ1 =>
        -- Wait for end of the cycle (we do not support wb_rty_i (yet?))
        if wb_ack_i = '1' then
          -- Cycle ended normally and we can read the data
          r_n.resp_dout <= wb_dat_i;
          r_n.resp_av   <= '1';
          stop_all;
          r_n.state     <= SBC_READ1b;
        elsif wb_err_i = '1' then
          stop_all;
          set_error(8);
        end if;
      when SBC_READ1b =>
        -- Wait until data is accepted
        if resp_ack = '1' then
          r_n.resp_av <= '0';
          r_n.state   <= SBC_READ2;
        end if;
      when SBC_READ2 =>
        if to_integer(r.cycle_cnt) /= 0 then
          r_n.cycle_cnt <= r.cycle_cnt - 1;
        end if;
        -- Now we must decide if the whole transfer is done
        if to_integer(r.cycle_cnt) = 0 then
          r_n.state <= SBC_START;
        else
          if rdcmd_sm(r.command) = 1 then
            r_n.bus_ad <= r.bus_ad + rdcmd_ai(r.command);
          elsif rdcmd_sm(r.command) = 2 then
            r_n.bus_ad <= r.bus_ad - rdcmd_ai(r.command);
          end if;
          start_rd;
          r_n.state <= SBC_READ1;
        end if;
      when SBC_RMW0 =>
        if cmd_av = '1' then
          -- Read the tested address
          r_n.bus_ad <= unsigned(cmd_in);
          c.cmd_ack  <= '1';
          start_rd;
          -- depending on the operation read the second argument
          case rmwcmd_oper(r.command) is
            when 2 to 6 =>
              -- We must read the second argument
              r_n.state <= SBC_RMW1;
            when 0 | 1 | 7 =>
              r_n.state <= SBC_RMW2;
            when others =>
              stop_all;
              set_error(9);
          end case;
        elsif cmd_end = '1' then
          -- error!
          stop_all;
          set_error(10);
        end if;
      when SBC_RMW1 =>
        if cmd_av = '1' then
          r_n.wreg  <= cmd_in;
          c.cmd_ack <= '1';
          r_n.state <= SBC_RMW2;
        elsif cmd_end = '1' then
          stop_all;
          set_error(11);
        end if;
      when SBC_RMW2 =>
        if wb_ack_i = '1' then
          case rmwcmd_oper(r.command) is
            when 0 =>
              r_n.bus_dout <= std_logic_vector(unsigned(wb_dat_i)+1);
            when 1 =>
              r_n.bus_dout <= std_logic_vector(unsigned(wb_dat_i)-1);
            when 2 =>
              r_n.bus_dout <= std_logic_vector(unsigned(wb_dat_i)+unsigned(r.wreg));
            when 3 =>
              r_n.bus_dout <= std_logic_vector(unsigned(wb_dat_i)-unsigned(r.wreg));
            when 4 =>
              r_n.bus_dout <= wb_dat_i and r.wreg;
            when 5 =>
              r_n.bus_dout <= wb_dat_i or r.wreg;
            when 6 =>
              r_n.bus_dout <= wb_dat_i xor r.wreg;
            when 7 =>
              r_n.bus_dout <= not wb_dat_i;
            when others =>
              r_n.bus_dout <= (others => '0');
          end case;
          r_n.wreg     <= wb_dat_i;  -- For possible writing to the response.
          r_n.wb_stb_o <= '0';          -- We don't release CYC_O!
          r_n.state    <= SBC_RMW3;
        end if;
      when SBC_RMW3 =>
        start_wr;
        r_n.state <= SBC_RMW4;
      when SBC_RMW4 =>
        if wb_ack_i = '1' then
          stop_all;
          if rmwcmd_resp(r.command) then
            -- Cycle ended normally and we can write the original data
            r_n.resp_dout <= r.wreg;
            r_n.resp_av   <= '1';
            r_n.state     <= SBC_RMW5;
          else
            r_n.state <= SBC_START;
          end if;
        elsif wb_err_i = '1' then
          stop_all;
          set_error(12);
        end if;
      when SBC_RMW5 =>
        -- Wait until data is accepted
        if resp_ack = '1' then
          r_n.resp_av <= '0';
          r_n.state   <= SBC_START;
        end if;
      when SBC_RTST0 =>
        if cmd_av = '1' then
          -- Read the tested address
          r_n.bus_ad <= unsigned(cmd_in);
          c.cmd_ack  <= '1';
          start_rd;
          -- Read the second argument
          r_n.state  <= SBC_RTST1;
        elsif cmd_end = '1' then
          -- error!
          stop_all;
          set_error(13);
        end if;
      when SBC_RTST1 =>
        if cmd_av = '1' then
          r_n.wreg  <= cmd_in;
          c.cmd_ack <= '1';
          -- depending on the operation read the third argument
          case rtstcmd_oper(r.command) is
            when 5 to 6 =>
              -- We must read the second argument
              r_n.state <= SBC_RTST2;
            when 0 to 4 =>
              r_n.state <= SBC_RTST3;
            when others =>
              stop_all;
              set_error(9);
          end case;
        elsif cmd_end = '1' then
          stop_all;
          set_error(14);
        end if;
      when SBC_RTST2 =>
        if cmd_av = '1' then
          r_n.wreg2 <= cmd_in;
          c.cmd_ack <= '1';
          -- depending on the operation read the third argument
          r_n.state <= SBC_RTST3;
        elsif cmd_end = '1' then
          stop_all;
          set_error(15);
        end if;
      when SBC_RTST3 =>
        if wb_ack_i = '1' then
          case rtstcmd_oper(r.command) is
            when 0 =>
              -- Signed less than
              if signed(wb_dat_i) < signed(r.wreg) then
                verror := 0;
              else
                verror := 16;
              end if;
            when 1 =>
              -- Unsigned less than
              if unsigned(wb_dat_i) < unsigned(r.wreg) then
                verror := 0;
              else
                verror := 17;
              end if;
            when 2 =>
              -- Signed greater than
              if signed(wb_dat_i) > signed(r.wreg) then
                verror := 0;
              else
                verror := 18;
              end if;
            when 3 =>
              -- Unsigned greater than
              if signed(wb_dat_i) > signed(r.wreg) then
                verror := 0;
              else
                verror := 19;
              end if;
            when 4 =>
              -- Compare
              if wb_dat_i = r.wreg then
                verror := 0;
              else
                verror := 20;
              end if;
            when 5 =>
              -- And with mask and compare
              if (wb_dat_i and r.wreg) = r.wreg2 then
                verror := 0;
              else
                verror := 21;
              end if;
            when 6 =>
              -- Or with mask and compare
              if (wb_dat_i or r.wreg) = r.wreg2 then
                verror := 0;
              else
                verror := 22;
              end if;
            when others =>
              verror := 23;
          end case;
          if verror = 0 then
            -- Test executed correctly
            stop_all;
            r_n.state <= SBC_START;
          else
            -- Test failed, we need to write the read value
            r_n.resp_dout <= wb_dat_i;
            r_n.resp_av   <= '1';
            set_error(verror);
            -- We overwrite the change of state done by set_error!
            r_n.state     <= SBC_RTST4;
          end if;
        end if;
      when SBC_RTST4 =>
        -- Wait until data is accepted
        if resp_ack = '1' then
          r_n.resp_av <= '0';
          r_n.state   <= SBC_END;
        end if;
      when SBC_MRTST0 =>
        if cmd_av = '1' then
          -- Read the tested address
          r_n.bus_ad <= unsigned(cmd_in);
          c.cmd_ack  <= '1';
          start_rd;
          -- Read the second argument
          r_n.state  <= SBC_MRTST1;
        elsif cmd_end = '1' then
          -- error!
          stop_all;
          set_error(25);
        end if;
      when SBC_MRTST1 =>
        if cmd_av = '1' then
          r_n.wreg      <= cmd_in;
          c.cmd_ack     <= '1';
          -- Initialize the repeat counter from the command
          r_n.cycle_cnt <= rtstcmd_repeat(r.command);
          -- depending on the operation read the third argument
          case rtstcmd_oper(r.command) is
            when 5 to 6 =>
              -- We must read the second argument
              r_n.state <= SBC_MRTST2;
            when 0 to 4 =>
              r_n.state <= SBC_MRTST3;
            when others =>
              stop_all;
              set_error(26);
          end case;
        elsif cmd_end = '1' then
          stop_all;
          set_error(27);
        end if;
      when SBC_MRTST2 =>
        if cmd_av = '1' then
          r_n.wreg2 <= cmd_in;
          c.cmd_ack <= '1';
          -- depending on the operation read the third argument
          r_n.state <= SBC_MRTST3;
        elsif cmd_end = '1' then
          stop_all;
          set_error(28);
        end if;
      when SBC_MRTST3 =>
        if wb_ack_i = '1' then
          case rtstcmd_oper(r.command) is
            when 0 =>
              -- Signed less than
              if signed(wb_dat_i) < signed(r.wreg) then
                verror := 0;
              else
                verror := 29;
              end if;
            when 1 =>
              -- Unsigned less than
              if unsigned(wb_dat_i) < unsigned(r.wreg) then
                verror := 0;
              else
                verror := 30;
              end if;
            when 2 =>
              -- Signed greater than
              if signed(wb_dat_i) > signed(r.wreg) then
                verror := 0;
              else
                verror := 31;
              end if;
            when 3 =>
              -- Unsigned greater than
              if signed(wb_dat_i) > signed(r.wreg) then
                verror := 0;
              else
                verror := 32;
              end if;
            when 4 =>
              -- Compare
              if wb_dat_i = r.wreg then
                verror := 0;
              else
                verror := 33;
              end if;
            when 5 =>
              -- And with mask and compare
              if (wb_dat_i and r.wreg) = r.wreg2 then
                verror := 0;
              else
                verror := 34;
              end if;
            when 6 =>
              -- Or with mask and compare
              if (wb_dat_i or r.wreg) = r.wreg2 then
                verror := 0;
              else
                verror := 35;
              end if;
            when others =>
              verror := 36;
          end case;
          if verror = 0 then
            -- Test executed correctly
            stop_all;
            -- Write the loop counter;
            r_n.resp_dout                    <= (others => '0');
            r_n.resp_dout(r.cycle_cnt'range) <= std_logic_vector(r.cycle_cnt);
            r_n.resp_av                      <= '1';
            r_n.state                        <= SBC_MRTST5;
          else
            -- Test failed
            if to_integer(r.cycle_cnt) /= 0 then
              -- We need to retry the test. Go to delay state
              r_n.cycle_cnt <= r.cycle_cnt - 1;
              stop_all;
              -- Initialize the delay counter from the command
              r_n.delay_cnt <= rtstcmd_delay(r.command);
              r_n.state     <= SBC_DELAY;
            else
              --we need to write the read value
              r_n.resp_dout <= wb_dat_i;
              r_n.resp_av   <= '1';
              set_error(verror);
              -- We overwrite the change of the state done by set_error!
              r_n.state     <= SBC_MRTST4;
            end if;
          end if;
        end if;
      when SBC_MRTST4 =>
        -- Wait until data is accepted
        if resp_ack = '1' then
          r_n.resp_av <= '0';
          r_n.state   <= SBC_END;
        end if;
      when SBC_MRTST5 =>
        -- Wait until data is accepted
        if resp_ack = '1' then
          r_n.resp_av <= '0';
          r_n.state   <= SBC_START;
        end if;
      when SBC_DELAY =>
        if to_integer(r.delay_cnt) > 0 then
          r_n.delay_cnt <= r.delay_cnt - 1;
        else
          start_rd;
          r_n.state <= SBC_MRTST3;
        end if;
      when SBC_END =>
        -- Set the bus in inactive state
        stop_all;
        -- We immediately end servicing of the command
        r_n.resp_dout <= std_logic_vector(r.status) & std_logic_vector(to_unsigned(to_integer(r.cmd_cnt), 16));
        r_n.resp_av   <= '1';
        r_n.state     <= SBC_END2;
      when SBC_END2 =>
        c.resp_end <= '1';
        -- Wait until data is accepted
        if resp_ack = '1' then
          r_n.resp_av  <= '0';
          r_n.exec_ack <= exec_start_sync;
          r_n.state    <= SBC_IDLE;
        end if;
      when others => null;
    end case;
  end process p1;

  ps1 : process (sys_clk) is
  begin  -- process ps1
    if sys_clk'event and sys_clk = '1' then  -- rising clock edge
      if rst_p = '1' then                    -- synchronous reset (active high)
        r               <= C_SBC_REGS_INIT;
        exec_start_sync <= '0';
      else
        r <= r_n;
        -- Independently we handle the command counter
        -- It is not the most elegant solution, but simplifies the code
        if c.cmd_ack = '1' then
          r.cmd_cnt <= r_n.cmd_cnt + 1;
        end if;
        exec_start_sync <= exec_start;
      end if;
    end if;
  end process ps1;

end architecture rtl;
