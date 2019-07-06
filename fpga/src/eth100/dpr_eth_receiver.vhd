-------------------------------------------------------------------------------
-- Title      : FPGA Ethernet interface - block receiving packets from MII PHY
-- Project    : 
-------------------------------------------------------------------------------
-- File       : dpr_eth_receiver.vhd
-- Author     : Wojciech M. Zabolotny (wzab@ise.pw.edu.pl)
-- License    : Dual LGPL/BSD License
-- Company    : 
-- Created    : 2014-11-10
-- Last update: 2019-07-04
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Description: This blocks receives packets from PHY, and puts only the
-- complete packets with correct CRC to the FIFO
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-11-10  1.0      WZab      Created
-- 2018-03-01  1.2      WZab - Essential rework for control interface
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.e2bus_pkg.all;
use work.pkg_newcrc32_d8.all;

entity eth_receiver is

  port (
    my_mac                   : in  std_logic_vector(47 downto 0);
    received_peer_mac        : out std_logic_vector(47 downto 0);
    -- SPECIAL COMMANDS INTERFACE
    special_cmd              : out std_logic_vector(7 downto 0);
    special_cmd_req          : out std_logic;
    special_cmd_ack          : in  std_logic;
    -- CMD FRAME DPR INTERFACE
    cmd_frame_dpr_ad         : out std_logic_vector(C_CFR_ABITS-1 downto 0);
    cmd_frame_dpr_dout       : out std_logic_vector(C_CFR_DBITS-1 downto 0);
    cmd_frame_dpr_din        : in  std_logic_vector(C_CFR_DBITS-1 downto 0);
    cmd_frame_dpr_wr         : out std_logic;
    cmd_frame_dpr_clk        : out std_logic;
    cmd_frame_wr_ptr         : out std_logic_vector(C_CFR_ABITS-1 downto 0);
    cmd_frame_rd_ptr         : in  std_logic_vector(C_CFR_ABITS-1 downto 0);
    -- CMD DESC INTERFACE
    cmd_desc_dpr_ad          : out std_logic_vector(C_CDESC_ABITS-1 downto 0);
    cmd_desc_dpr_dout        : out std_logic_vector(C_CDESC_DBITS-1 downto 0);
    cmd_desc_dpr_din         : in  std_logic_vector(C_CDESC_DBITS-1 downto 0);
    cmd_desc_dpr_wr          : out std_logic;
    cmd_desc_dpr_clk         : out std_logic;
    cmd_last_processed_frame : in  std_logic_vector(15 downto 0);
    -- CMD ACK FIFO INTERFACE
    cmd_ack_fifo_full        : in  std_logic;
    cmd_ack_fifo_dout        : out std_logic_vector(C_CACK_DBITS-1 downto 0);
    cmd_ack_fifo_wr          : out std_logic;
    cmd_ack_fifo_clk         : out std_logic;
    -- RESP ACK DPR INTERFACE
    resp_ack_dpr_dout        : out std_logic_vector(C_RACK_DBITS-1 downto 0);
    resp_ack_dpr_din         : in  std_logic_vector(C_RACK_DBITS-1 downto 0);
    resp_ack_dpr_ad          : out std_logic_vector(C_RACK_ABITS-1 downto 0);
    resp_ack_dpr_wr          : out std_logic;
    resp_ack_dpr_clk         : out std_logic;
    resp_ack_wr_ptr          : out std_logic_vector(C_RACK_ABITS-1 downto 0);
    resp_ack_rd_ptr          : in  std_logic_vector(C_RACK_ABITS-1 downto 0);
    -- System interface
    clk                      : in  std_logic;
    rst_n                    : in  std_logic;
    ready                    : out std_logic;
    -- MAC interface
    Rx_Clk                   : in  std_logic;
    Rx_Er                    : in  std_logic;
    Rx_Dv                    : in  std_logic;
    RxD                      : in  std_logic_vector(3 downto 0);
    leds                     : out std_logic_vector(3 downto 0)
    );

end eth_receiver;


architecture beh1 of eth_receiver is

  attribute keep       : string;
  attribute mark_debug : string;

  type T_STATE is (ST_RCV_IDLE, ST_RCV_INIT_0, ST_RCV_INIT_1,
                   ST_RCV_PREAMB, ST_RCV_DEST, ST_RCV_SOURCE, ST_RCV_PROTO,
                   ST_RCV_ACK0, ST_RCV_ACK1, ST_RCV_ACK2, ST_RCV_IGNORE,
                   ST_RCV_PACKET_0, ST_RCV_PACKET_1, ST_RCV_PACKET_2,
                   ST_RCV_SPECIAL_CMD_1, ST_RCV_SPECIAL_CMD_2, ST_RCV_SPECIAL_CMD_3, ST_RCV_SPECIAL_CMD_4,
                   ST_RCV_WAIT_IDLE);

  type T_RD_STATE is (SRD_IDLE, SRD_RECV0, SRD_RECV1, SRD_WAIT, SRD_WAIT1);
  constant DELAY_TIME : integer    := 10;
  signal delay        : integer range 0 to DELAY_TIME;
  signal rd_state     : T_RD_STATE := SRD_IDLE;

  function rev(a : in std_logic_vector)
    return std_logic_vector is
    variable result : std_logic_vector(a'range);
    alias aa        : std_logic_vector(a'reverse_range) is a;
  begin
    for i in aa'range loop
      result(i) := aa(i);
    end loop;
    return result;
  end;  -- function reverse_any_bus

  constant DPR_AWDTH : integer := 12;

  type T_RCV_REGS is record
    state           : T_STATE;
    transmit_data   : std_logic;
    restart         : std_logic;
    cmd_start       : unsigned(C_CFR_ABITS-1 downto 0);
    cmd_wr_ptr      : unsigned(C_CFR_ABITS-1 downto 0);
    cmd_frame_num   : unsigned(15 downto 0);
    cmd_desc_dpr_ad : unsigned(C_CDESC_ABITS-1 downto 0);
    resp_ack_wr_ptr : unsigned(C_RACK_ABITS-1 downto 0);
    resp_ack_start  : unsigned(C_RACK_ABITS-1 downto 0);
    ack_byte0       : std_logic_vector(7 downto 0);
    ack_byte1       : std_logic_vector(7 downto 0);
    ack_byte2       : std_logic_vector(7 downto 0);
    frnum_is_bigger : std_logic;
    update_flag     : std_logic;
    ready           : std_logic;
    in_pkt          : std_logic;
    count           : integer range 0 to 256;
    dbg             : std_logic_vector(3 downto 0);
    crc32           : std_logic_vector(31 downto 0);
    cmd             : std_logic_vector(63 downto 0);
    mac_addr        : std_logic_vector(47 downto 0);
    peer_mac        : std_logic_vector(47 downto 0);
  end record;

  constant RCV_REGS_INI : T_RCV_REGS := (
    state           => ST_RCV_INIT_0,
    transmit_data   => '0',
    restart         => '0',
    cmd_start       => (others => '0'),
    cmd_wr_ptr      => (others => '0'),
    cmd_frame_num   => (others => '0'),
    cmd_desc_dpr_ad => (others => '0'),
    resp_ack_wr_ptr => (others => '0'),
    resp_ack_start  => (others => '0'),
    ack_byte0       => (others => '0'),
    ack_byte1       => (others => '0'),
    ack_byte2       => (others => '0'),
    frnum_is_bigger => '0',
    update_flag     => '0',
    ready           => '0',
    in_pkt          => '0',
    count           => 0,
    dbg             => (others => '0'),
    crc32           => (others => '0'),
    cmd             => (others => '0'),
    mac_addr        => (others => '0'),
    peer_mac        => (others => '0')
    );

  signal r, r_n : T_RCV_REGS := RCV_REGS_INI;

  signal dbg_state                  : T_STATE;
  attribute keep of dbg_state       : signal is "true";
  attribute mark_debug of dbg_state : signal is "true";
  signal dbg_crc32                  : std_logic_vector(31 downto 0);
  attribute keep of dbg_crc32       : signal is "true";
  attribute mark_debug of dbg_crc32 : signal is "true";




  type T_RCV_COMB is record
    special_cmd     : std_logic_vector(7 downto 0);
    special_cmd_req : std_logic;
    cmd_wr          : std_logic;
    cmd_in          : std_logic_vector(C_CFR_DBITS-1 downto 0);
    cmd_addr        : std_logic_vector(C_CFR_ABITS-1 downto 0);

    cmd_desc_dpr_wr   : std_logic;
    cmd_desc_dpr_ad   : std_logic_vector(C_CDESC_ABITS-1 downto 0);
    cmd_desc_dpr_dout : std_logic_vector(C_CDESC_DBITS-1 downto 0);
    cmd_ack_fifo_dout : std_logic_vector(C_CACK_DBITS-1 downto 0);
    cmd_ack_fifo_wr   : std_logic;
    resp_ack_dpr_ad   : std_logic_vector(C_RACK_ABITS-1 downto 0);
    resp_ack_dpr_dout : std_logic_vector(C_RACK_DBITS-1 downto 0);
    resp_ack_dpr_wr   : std_logic;
    Rx_mac_rd         : std_logic;
    restart           : std_logic;
  end record;

  constant RCV_COMB_DEFAULT : T_RCV_COMB := (
    special_cmd     => (others => '0'),
    special_cmd_req => '0',

    cmd_wr   => '0',
    cmd_addr => (others => '0'),
    cmd_in   => (others => '0'),

    cmd_desc_dpr_wr   => '0',
    cmd_desc_dpr_ad   => (others => '0'),
    cmd_desc_dpr_dout => (others => '0'),
    cmd_ack_fifo_dout => (others => '0'),
    cmd_ack_fifo_wr   => '0',
    resp_ack_dpr_ad   => (others => '0'),
    resp_ack_dpr_dout => (others => '0'),
    resp_ack_dpr_wr   => '0',
    Rx_mac_rd         => '0',
    restart           => '0'
    );

  signal c : T_RCV_COMB := RCV_COMB_DEFAULT;

  signal cmd_rd_ptr                       : unsigned(C_CFR_ABITS-1 downto 0) := (others => '0');
  signal rx_rst_n, rx_rst_n_0, rx_rst_n_1 : std_logic                        := '0';
  signal s_leds                           : std_logic_vector(3 downto 0)     := (others => '0');
  -- Additional pipeline registers to improve timing
  signal Rx_Dv_0                          : std_logic;
  signal Rx_Er_0                          : std_logic;
  signal RxD_0                            : std_logic_vector(7 downto 0);
  attribute keep of Rx_Dv_0               : signal is "true";
  attribute mark_debug of Rx_Dv_0         : signal is "true";
  attribute keep of RxD_0                 : signal is "true";
  attribute mark_debug of RxD_0           : signal is "true";
  signal Rx_D4v_0                         : std_logic;
  signal Rx_4Er_0                         : std_logic;
  signal RxD4_0                           : std_logic_vector(3 downto 0);

  signal special_cmd_ack_sync : std_logic := '0';
  signal full_byte            : std_logic := '0';

begin  -- beh1

  dbg_state <= r.state;
  dbg_crc32 <= r.crc32;

  received_peer_mac <= r.mac_addr;
  special_cmd       <= c.special_cmd;
  special_cmd_req   <= c.special_cmd_req;

  ready <= r.ready;

  -- Mapping of signals for communication channels
  -- CMD DESC
  cmd_desc_dpr_ad   <= c.cmd_desc_dpr_ad;
  cmd_desc_dpr_wr   <= c.cmd_desc_dpr_wr;
  cmd_desc_dpr_dout <= c.cmd_desc_dpr_dout;
  cmd_desc_dpr_clk  <= Rx_Clk;

  -- CMD FRAME
  cmd_frame_dpr_ad   <= c.cmd_addr;
  cmd_frame_dpr_wr   <= c.cmd_wr;
  cmd_frame_dpr_dout <= c.cmd_in;
  cmd_frame_dpr_clk  <= Rx_Clk;

  -- CMD ACK
  cmd_ack_fifo_wr   <= c.cmd_ack_fifo_wr;
  cmd_ack_fifo_clk  <= Rx_Clk;
  cmd_ack_fifo_dout <= c.cmd_ack_fifo_dout;

  -- RESP ACK
  resp_ack_wr_ptr   <= std_logic_vector(r.resp_ack_start);
  resp_ack_dpr_ad   <= c.resp_ack_dpr_ad;
  resp_ack_dpr_wr   <= c.resp_ack_dpr_wr;
  resp_ack_dpr_dout <= c.resp_ack_dpr_dout;
  resp_ack_dpr_clk  <= Rx_Clk;


  leds               <= s_leds;
  --s_leds(3) <= pkt_fifo_empty;
  s_leds(2 downto 0) <= r.dbg(2 downto 0);
--  rx_error           <= '0';

  -- Connection of pointers!
  cmd_frame_wr_ptr <= std_logic_vector(r.cmd_start);
  -- Previously the above was connected to r.cmd_wr_ptr, but it was incorrect.
  -- r.cmd_wr_ptr is changed when a new packet is being received. Therefore
  -- it can't be used to check if we have serviced the last packet.
  cmd_rd_ptr       <= unsigned(cmd_frame_rd_ptr);

  -- Reading of ethernet data
  rdp1 : process (Rx_Clk)
  begin  -- process rdp1
    if Rx_Clk'event and Rx_Clk = '1' then  -- rising clock edge
      if rx_rst_n = '0' then               -- synchronous reset (active low)
        r         <= RCV_REGS_INI;
        Rx_D4v_0  <= '0';
        Rx_4Er_0  <= '0';
        full_byte <= '0';
        RxD4_0    <= (others => '0');
      else
        r        <= r_n;
        Rx_D4v_0 <= Rx_Dv;
        Rx_4Er_0 <= Rx_Er;
        RxD4_0   <= RxD;
        if r.in_pkt = '1' then
          if full_byte = '0' then
            RxD_0     <= RxD & RxD4_0;
            Rx_Dv_0   <= Rx_Dv and Rx_D4v_0;
            full_byte <= '1';
          else
            RxD_0     <= (others => '0');
            Rx_Dv_0   <= '0';
            full_byte <= '0';
          end if;
        else
          RxD_0     <= (others => '0');
          Rx_Dv_0   <= '0';
          full_byte <= '0';
        end if;
      end if;
    end if;
  end process rdp1;

  rdp2 : process (RxD4_0, RxD_0, Rx_D4v_0, Rx_Dv_0, cmd_ack_fifo_full,
                  cmd_desc_dpr_din, cmd_rd_ptr, full_byte, my_mac, r,
                  resp_ack_rd_ptr, special_cmd_ack_sync)

    variable v_mac_addr   : std_logic_vector(47 downto 0);
    variable v_cmd        : std_logic_vector(63 downto 0);
    variable v_cmd_wr_ptr : unsigned(C_CFR_ABITS-1 downto 0) := (others => '0');

    variable v_resp_ack_wr_ptr : unsigned(C_RACK_ABITS-1 downto 0);
    variable v_comp_frame_nums : unsigned(15 downto 0) := (others => '0');

    constant C_MAX_DESC_DPR_AD : unsigned(C_CDESC_ABITS-1 downto 0) := (others => '1');

  begin  -- process
    c                 <= RCV_COMB_DEFAULT;
    c.cmd_desc_dpr_ad <= std_logic_vector(r.cmd_frame_num(C_CDESC_ABITS-1 downto 0));  -- That allows us to quickly check
                                        -- the frame number in current slot

    r_n <= r;
    --dbg <= "1111";
    case r.state is
      when ST_RCV_INIT_0 =>
        r_n.cmd_desc_dpr_ad <= (others => '0');
        r_n.state           <= ST_RCV_INIT_1;
      when ST_RCV_INIT_1 =>
        r_n.cmd_desc_dpr_ad <= r.cmd_desc_dpr_ad + 1;
        c.cmd_desc_dpr_ad   <= std_logic_vector(r.cmd_desc_dpr_ad);
        c.cmd_desc_dpr_dout <= (others => '1');     -- Frame number -1!
        c.cmd_desc_dpr_wr   <= '1';
        if r.cmd_desc_dpr_ad = C_MAX_DESC_DPR_AD then
          r_n.state           <= ST_RCV_IDLE;
          r_n.ready           <= '1';
          r_n.cmd_desc_dpr_ad <= (others => '0');
        end if;
      when ST_RCV_IDLE =>
        --dbg <= "0000";
        r_n.in_pkt <= '0';
        if Rx_D4v_0 = '1' then
          if RxD4_0 = x"5" then
            r_n.count  <= 1;
            r_n.dbg(0) <= not r.dbg(0);
            r_n.state  <= ST_RCV_PREAMB;
          end if;
        end if;
      when ST_RCV_PREAMB =>
        --dbg <= "0001";
        if Rx_D4v_0 = '0' then
          -- interrupted preamble reception
          r_n.state <= ST_RCV_IDLE;
        elsif RxD4_0 = x"5" then
          if r.count < 15 then
            r_n.count <= r.count + 1;
          end if;
        elsif (RxD4_0 = x"d") and (r.count = 15) then
          -- We start reception of the packet
          r_n.in_pkt          <= '1';
          r_n.crc32           <= (others => '1');
          r_n.count           <= 0;
          -- Here we add filtering of packets to other destinations
          -- r_n.state     <= ST_RCV_PACKET_1;
          r_n.state           <= ST_RCV_DEST;
          -- The lines below ensure proper recovery of buffer space in case
          -- if previously a corrupted packet was received.
          r_n.cmd_wr_ptr      <= r.cmd_start;
          r_n.resp_ack_wr_ptr <= r.resp_ack_start;
        else
          -- something wrong happened during preamble detection
          r_n.state <= ST_RCV_WAIT_IDLE;
        end if;
      when ST_RCV_DEST =>
        -- dbg <= 0010
        if Rx_Dv_0 = '1' then
          r_n.crc32 <= newcrc32_d8(RxD_0, r.crc32);
          if my_mac(47-r.count*8 downto 40-r.count*8) /= RxD_0 then
            -- Not our address, return to IDLE!
            r_n.state <= ST_RCV_WAIT_IDLE;
          elsif r.count < 5 then
            r_n.count <= r.count + 1;
          else
            r_n.count <= 0;
            r_n.state <= ST_RCV_SOURCE;
          -- Our address! Receive the sender
          end if;
        else
          -- packet broken?
          if full_byte = '1' then
            r_n.state <= ST_RCV_IDLE;
          end if;
        end if;
      when ST_RCV_SOURCE =>
        --dbg <= "0011";
        if Rx_Dv_0 = '1' then
          r_n.crc32                                    <= newcrc32_d8(RxD_0, r.crc32);
          v_mac_addr                                   := r.mac_addr;
          v_mac_addr(47-r.count*8 downto 40-r.count*8) := RxD_0;
          r_n.mac_addr                                 <= v_mac_addr;
          if r.count < 5 then
            r_n.count <= r.count + 1;
          else
            r_n.count <= 0;
            r_n.state <= ST_RCV_PROTO;
          end if;
        else
          -- packet broken?
          if full_byte = '1' then
            r_n.state <= ST_RCV_IDLE;
          end if;
        end if;
      when ST_RCV_PROTO =>
        if Rx_Dv_0 = '1' then
          r_n.crc32 <= newcrc32_d8(RxD_0, r.crc32);
          if proto_id(31-r.count*8 downto 24-r.count*8) /= RxD_0 then
            -- Incorrect type of frame or protocol ID
            r_n.state <= ST_RCV_IDLE;
          elsif r.count < 3 then
            r_n.count <= r.count + 1;
          else
            r_n.count <= 0;
            r_n.state <= ST_RCV_PACKET_0;
          end if;
        else
          -- packet broken?
          if full_byte = '1' then
            r_n.state <= ST_RCV_IDLE;
          end if;
        end if;
      -- In the section below we have to separate the CMD_FRAMES ans RESP_ACKS.
      -- We assume, that RESP_ACKS should be sent at the begining of the package
      -- The RESP_ACKS are sent as bytes with the MSB set to 1.
      -- The next 
      when ST_RCV_PACKET_0 =>
        if Rx_Dv_0 = '1' then
          r_n.crc32 <= newcrc32_d8(RxD_0, r.crc32);
          if RxD_0(7) = '1' then
            -- This is response acknowledgement
            r_n.ack_byte0 <= RxD_0;
            r_n.state     <= ST_RCV_ACK0;
          elsif RxD_0 = x"5b" then
            r_n.state <= ST_RCV_SPECIAL_CMD_1;
          elsif RxD_0 = x"5a" then
            r_n.count    <= 0;
            r_n.state    <= ST_RCV_PACKET_1;
            -- Reserve place for frame number!
            v_cmd_wr_ptr := r.cmd_wr_ptr + 1;
            if v_cmd_wr_ptr /= cmd_rd_ptr then
              r_n.cmd_wr_ptr <= v_cmd_wr_ptr;
            else
              -- No place for data, drop the packet
              r_n.state <= ST_RCV_WAIT_IDLE;
            end if;
          elsif RxD_0 = x"51" then      -- Was 0x55, but it may create false
                                        -- preamble. Changed to 0x51
            -- There is no command packet
            -- Just ignore the packet until its end
            r_n.state <= ST_RCV_IGNORE;
          else
            -- packet broken?
            r_n.state <= ST_RCV_IDLE;
          end if;
        else
          -- packet broken?
          if full_byte = '1' then
            r_n.state <= ST_RCV_IDLE;
          end if;
        end if;
      when ST_RCV_SPECIAL_CMD_1 =>
        if Rx_Dv_0 = '1' then
          r_n.crc32     <= newcrc32_d8(RxD_0, r.crc32);
          r_n.ack_byte0 <= RxD_0;
          r_n.state     <= ST_RCV_SPECIAL_CMD_2;
        else
          -- packet broken?
          if full_byte = '1' then
            r_n.state <= ST_RCV_IDLE;
          end if;
        end if;
      when ST_RCV_SPECIAL_CMD_2 =>
        -- Just ignore all bytes until the end of the packet (usefull
        -- when the packet had to be extended to match the minimum length)
        if Rx_DV_0 = '1' then
          r_n.crc32 <= newcrc32_d8(RxD_0, r.crc32);
        else
          if full_byte = '1' then
            if r.crc32 /= x"c704dd7b" then
              r_n.dbg(1) <= not r.dbg(1);
              r_n.state  <= ST_RCV_IDLE;
            else
              -- We notify the system about reception of the special command
              r_n.state <= ST_RCV_SPECIAL_CMD_3;
            end if;
          end if;
        end if;
      when ST_RCV_SPECIAL_CMD_3 =>
        -- We request servicing of the special command, and stay in that state
        -- until it is acknowledged (or the whole receiver/transmitter system
        -- is reset).
        c.special_cmd     <= r.ack_byte0;
        c.special_cmd_req <= '1';
        if special_cmd_ack_sync = '1' then
          r_n.state <= ST_RCV_SPECIAL_CMD_4;
        end if;
      when ST_RCV_SPECIAL_CMD_4 =>
        -- We request servicing of the special command, and stay in that state
        -- until it is acknowledged (or the whole receiver/transmitter system
        -- is reset).
        if special_cmd_ack_sync = '0' then
          r_n.state <= ST_RCV_IDLE;
        end if;
      when ST_RCV_IGNORE =>
        -- Just ignore all bytes until the end of the packet (usefull
        -- when the packet had to be extended to match the minimum length)
        if Rx_DV_0 = '1' then
          r_n.crc32 <= newcrc32_d8(RxD_0, r.crc32);
        else
          if full_byte = '1' then
            if r.crc32 /= x"c704dd7b" then
              r_n.dbg(1) <= not r.dbg(1);
              r_n.state  <= ST_RCV_IDLE;
            else
              -- We pass the responses ACKs
              r_n.resp_ack_start <= r.resp_ack_wr_ptr;
              r_n.dbg(2)         <= not r.dbg(2);
              r_n.state          <= ST_RCV_IDLE;
            end if;
          end if;
        end if;
      when ST_RCV_ACK0 =>
        if Rx_DV_0 = '1' then
          r_n.crc32     <= newcrc32_d8(RxD_0, r.crc32);
          r_n.ack_byte1 <= RxD_0;
          r_n.state     <= ST_RCV_ACK1;
        -- If there is no place for ACK, we silently ignore it.
        else
          -- packet broken?
          if full_byte = '1' then
            r_n.state <= ST_RCV_IDLE;
          end if;
        end if;
      when ST_RCV_ACK1 =>
        if Rx_DV_0 = '1' then
          r_n.crc32     <= newcrc32_d8(RxD_0, r.crc32);
          r_n.ack_byte2 <= RxD_0;
          r_n.state     <= ST_RCV_ACK2;
        -- If there is no place for ACK, we silently ignore it.
        else
          -- packet broken?
          if full_byte = '1' then
            r_n.state <= ST_RCV_IDLE;
          end if;
        end if;
      when ST_RCV_ACK2 =>
        if Rx_Dv_0 = '1' then
          r_n.crc32         <= newcrc32_d8(RxD_0, r.crc32);
          v_resp_ack_wr_ptr := r.resp_ack_wr_ptr + 1;
          if v_resp_ack_wr_ptr /= unsigned(resp_ack_rd_ptr) then
            -- There is a place for ACK
            -- Ignore the bit 15 - it is always '1'!
            c.resp_ack_dpr_dout <= r.ack_byte0(6 downto 0) & r.ack_byte1 & r.ack_byte2 & RxD_0;
            c.resp_ack_dpr_wr   <= '1';
            c.resp_ack_dpr_ad   <= std_logic_vector(r.resp_ack_wr_ptr);
            r_n.crc32           <= newcrc32_d8(RxD_0, r.crc32);
            r_n.resp_ack_wr_ptr <= v_resp_ack_wr_ptr;
            r_n.state           <= ST_RCV_PACKET_0;
          end if;
        -- If there is no place for ACK, we silently ignore it.
        else
          -- packet broken?
          if full_byte = '1' then
            r_n.state <= ST_RCV_IDLE;
          end if;
        end if;
      when ST_RCV_PACKET_1 =>
        --dbg <= "0010";
        if Rx_Dv_0 = '1' then
          -- Check if there is place for the received byte
          v_cmd_wr_ptr := r.cmd_wr_ptr + 1;
          if v_cmd_wr_ptr /= cmd_rd_ptr then
            c.cmd_addr     <= std_logic_vector(r.cmd_wr_ptr);
            c.cmd_in       <= RxD_0;
            c.cmd_wr       <= '1';
            r_n.crc32      <= newcrc32_d8(RxD_0, r.crc32);
            r_n.cmd_wr_ptr <= v_cmd_wr_ptr;
            -- Here we also extract the 16-bit command frame number
            if r.count = 0 then
              r_n.cmd_frame_num(15 downto 8) <= unsigned(RxD_0);
              r_n.count                      <= r.count + 1;
            elsif r.count = 1 then
              r_n.cmd_frame_num(7 downto 0) <= unsigned(RxD_0);
              r_n.count                     <= r.count + 1;
            end if;
          else
            -- No place for data, drop the packet
            r_n.state <= ST_RCV_WAIT_IDLE;
          end if;
          -- We precompute the comp_frame_nums, to shorten the critical path
          -- Only the last result, calculated before Rx_Dv_0 goes down is valid.
          -- We use in in the else clause below.
          -- Please note, that the r.cmd_frame_num is updated only in the first
          -- two cycles. That's why we can safely use that approach.
          v_comp_frame_nums   := unsigned(stlv2cdesc_frm_num(cmd_desc_dpr_din)) - unsigned(r.cmd_frame_num);
          r_n.frnum_is_bigger <= v_comp_frame_nums(14);  -- frame numbers are 15-bit!
        else
          if full_byte = '1' then
            -- Rx_Dv = 0!
            -- Packet broken, or completed?
            -- Theoretically, we should check here, if the packet is longer than
            -- the minimal length!
            if r.crc32 /= x"c704dd7b" then
              r_n.dbg(1) <= not r.dbg(1);
              r_n.state  <= ST_RCV_IDLE;
            else
              -- We pass the responses ACKs
              r_n.resp_ack_start <= r.resp_ack_wr_ptr;
              -- Now we should pass the frame if it is not a duplicate
              -- Please remember, that the r.cmd_frame_num was set when
              -- receiving the packet. It is important, that it should be used
              -- to address the DESC DPR in the previous cycle!
              -- Now we compare it with the number of the last processed
              -- command frame.
              if r.frnum_is_bigger = '1' then
                -- We compare modulo 2^15. That's why the sign is expected to
                -- be on the 14-th bit.
                -- The number of the frame stored in the slot is lower than the number of
                -- arrived frame. 
                -- Update the start of the next packet
                v_cmd_wr_ptr := r.cmd_wr_ptr - 5;   -- drop the CRC!
                -- How is set the address?
                c.cmd_desc_dpr_dout <= cdesc2stlv(std_logic_vector(r.cmd_start),
                                                  std_logic_vector(v_cmd_wr_ptr),
                                                  std_logic_vector(r.cmd_frame_num));
                c.cmd_desc_dpr_wr <= '1';
                -- Update the writing position for the next command (adjusting it
                -- to 4 bytes!). Because v_cmd_wr_ptr points at the last byte of
                -- the previous command, here we must add 4, not 3!
                v_cmd_wr_ptr      := (v_cmd_wr_ptr + 4);
                v_cmd_wr_ptr(0)   := '0';
                v_cmd_wr_ptr(1)   := '0';
                r_n.cmd_start     <= v_cmd_wr_ptr;  -- command frame buffer
                -- Write the slot number to the command buffer (to its first byte)
                c.cmd_addr        <= std_logic_vector(r.cmd_start);
                c.cmd_in          <= std_logic_vector(r.cmd_frame_num(7 downto 0));
                c.cmd_wr          <= '1';
              end if;
              -- We send the confirmation that the commadn was delivered.
              --
              -- IMPORTANT NOTICE !!!
              -- We do not handle here a situation where the command frame was
              -- sent, but it couldn't be stored to the DESC DPR due to lack of space.
              -- The HOST must take care, that it sends next command to the
              -- particular slot only after the previous one was executed and confirmed!
              if cmd_ack_fifo_full = '0' then
                c.cmd_ack_fifo_dout <= std_logic_vector(r.cmd_frame_num);
                c.cmd_ack_fifo_wr   <= '1';
              end if;
              r_n.dbg(2) <= not r.dbg(2);
              r_n.state  <= ST_RCV_IDLE;
            end if;
          end if;
        end if;
      when ST_RCV_WAIT_IDLE =>
        --dbg             <= "1001";
        if Rx_Dv_0 = '0' then
          r_n.state <= ST_RCV_IDLE;
        end if;
      when others => null;
    end case;
  end process rdp2;

  -- IMPORTANT WARNING!!! We must ensure, that the DP RAMs are cleared after reset!
  -- Otherwise we may get false "busy" command slots!

  -- Synchronization of the special command ack
  process (Rx_Clk) is
  begin  -- process
    if Rx_Clk'event and Rx_Clk = '1' then  -- rising clock edge
      special_cmd_ack_sync <= special_cmd_ack;
    end if;
  end process;

  -- Synchronization of the reset signal for the Rx_Clk domain
  process (Rx_Clk, rst_n)
  begin  -- process
    if rst_n = '0' then                 -- asynchronous reset (active low)
      rx_rst_n_0 <= '0';
      rx_rst_n_1 <= '0';
      rx_rst_n   <= '0';
    elsif Rx_Clk'event and Rx_Clk = '1' then  -- rising clock edge
      rx_rst_n_0 <= rst_n;
      rx_rst_n_1 <= rx_rst_n_0;
      rx_rst_n   <= rx_rst_n_1;
    end if;
  end process;



end beh1;
