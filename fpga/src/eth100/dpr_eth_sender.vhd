-------------------------------------------------------------------------------
-- Title      : FPGA Ethernet interface - block sending packets via GMII Phy
-- Project    : 
-------------------------------------------------------------------------------
-- File       : dpr_eth_sender.vhd
-- Author     : Wojciech M. Zabolotny (wzab@ise.pw.edu.pl)
-- License    : Dual LGPL/BSD License
-- Company    : 
-- Created    : 2014-11-10
-- Last update: 2019-07-03
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: This file implements an Ethernet transmitter, which receives
-- packets from IPbus
--
-- It consists of two FSMs - one responsible for reception of packets and
-- writing them to the DP RAM
-- The second one, receives packets from the DP RAM and transmits them via
-- Ethernet PHY.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-11-10  1.0      WZab      Created
-- 2018-03-01  2.0      WZab   Very serious rework for control interface
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.e2bus_pkg.all;
use work.pkg_newcrc32_d8.all;

entity eth_sender is

  port (
    my_mac   : in std_logic_vector(47 downto 0);
    peer_mac : in std_logic_vector(47 downto 0);

    -- System interface
    clk                    : in  std_logic;
    rst_n                  : in  std_logic;
    -- Interrupt inputs
    irqs                   : in  std_logic_vector(7 downto 0);
    -- CMD ACK FIFO INTERFACE
    snd_cmd_ack_fifo_clk   : out std_logic;
    snd_cmd_ack_fifo_rd    : out std_logic;
    snd_cmd_ack_fifo_din   : in  std_logic_vector(C_CACK_DBITS-1 downto 0);
    snd_cmd_ack_fifo_empty : in  std_logic;
    -- RESP DPR interface
    snd_resp_dpr_clk       : out std_logic;
    snd_resp_dpr_din       : in  std_logic_vector(7 downto 0);
    snd_resp_dpr_ad        : out std_logic_vector(C_RESP_ABITS-1 downto 0);
    -- RESP REQUEST interface
    snd_resp_start         : in  std_logic_vector(C_RESP_ABITS-1 downto 0);
    snd_resp_end           : in  std_logic_vector(C_RESP_ABITS-1 downto 0);
    snd_resp_req           : in  std_logic;
    snd_resp_ack           : out std_logic;
    -- Additional info about the transmitted response
    -- Lower 8-bits of frame number
    snd_cmd_frm_num        : in  std_logic_vector(7 downto 0);
    -- Time of sending of the response
    snd_resp_time         : in std_logic_vector(31 downto 0);
    -- TX Phy interface
    Tx_Clk : in  std_logic;
    Tx_En  : out std_logic;
    TxD    : out std_logic_vector(3 downto 0);
    leds   : out std_logic_vector(3 downto 0)
    );

end eth_sender;


architecture beh1 of eth_sender is

  constant DPR_AWDTH : integer := 12;

  type T_ETH_SENDER_STATE is (WST_IDLE, WST_SEND_PREAMB, WST_SEND_SOF,
                              WST_SEND_PACKET_0, WST_SEND_PACKET_0b,
                              WST_SEND_PACKET_0c, WST_SEND_PACKET_0d,
                              WST_SEND_PACKET_0e, WST_SEND_PACKET_0f,
                              WST_SEND_PACKET_1, WST_SEND_PACKET_2,
                              WST_SEND_MY_MAC_0, WST_SEND_PEER_MAC_0,
                              WST_SEND_PROTO_0,
                              WST_SEND_ACKS, WST_SEND_IRQS, WST_SELECT_PART,
                              WST_ADD_TRAILER,
                              WST_SEND_CRC,
                              WST_SEND_COMPLETED);

  type T_TX_STATE is (DST_IDLE, DST_PACKET);

  signal dr_state : T_TX_STATE := DST_IDLE;
  -- Additional pipeline registers to improve timing
  signal Tx_En_0  : std_logic;
  signal TxD_0    : std_logic_vector(3 downto 0);

  signal snd_resp_req_sync : std_logic;
  signal is_irq_to_service : boolean := false;

  type T_ETH_SENDER_REGS is record
    state        : T_ETH_SENDER_STATE;
    snd_resp_ack : std_logic;
    --ready   : std_logic;
    tmp          : std_logic_vector(7 downto 0);
    nibble       : std_logic;
    count        : integer;
    pkt_len      : integer;
    rd_ptr       : unsigned(C_RESP_ABITS-1 downto 0);
    byte         : integer;
    crc32        : std_logic_vector(31 downto 0);
    irq_throttle : integer;
  end record;


  constant ETH_SENDER_REGS_INI : T_ETH_SENDER_REGS := (
    state        => WST_IDLE,
    --ready   => '1',
    tmp          => (others => '0'),
    nibble       => '0',
    snd_resp_ack => '0',
    count        => 0,
    pkt_len      => 0,
    rd_ptr       => (others => '0'),
    byte         => 0,
    crc32        => (others => '0'),
    irq_throttle => 0
    );

  signal r, r_n : T_ETH_SENDER_REGS := ETH_SENDER_REGS_INI;

  type T_ETH_SENDER_COMB is record
    TxD             : std_logic_vector(3 downto 0);
    Tx_En           : std_logic;
--    pkt_fifo_rd : std_logic;
    cmd_ack_fifo_rd : std_logic;
    stall           : std_logic;
  end record;

  constant ETH_SENDER_COMB_DEFAULT : T_ETH_SENDER_COMB := (
    TxD             => (others => '0'),
    Tx_En           => '0',
--    pkt_fifo_rd => '0',
    cmd_ack_fifo_rd => '0',
    stall           => '1'
    );

  signal c : T_ETH_SENDER_COMB := ETH_SENDER_COMB_DEFAULT;

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

  signal tx_rst_n, tx_rst_n_0, tx_rst_n_1 : std_logic := '0';

  type T_STATE1 is (ST1_IDLE, ST1_WAIT_NOT_READY, ST1_WAIT_NOT_START,
                    ST1_WAIT_READY);
  signal state1 : T_STATE1;

  type T_STATE2 is (ST2_IDLE, ST2_WAIT_NOT_READY, ST2_WAIT_READY);
  signal state2          : T_STATE2;
  signal dta_packet_type : std_logic_vector(15 downto 0) := (others => '0');

  -- Signals used by the first FSM
--  signal dpr_st_ptr, dpr_wr_ptr, dpr_rd_ptr, dpr_end_ptr, dpr_beg_ptr : unsigned(DPR_AWDTH-1 downto 0)           := (others => '0');
--  signal pkt_fifo_din, pkt_fifo_dout                                  : std_logic_vector(2*DPR_AWDTH-1 downto 0) := (others => '0');
--  signal pkt_fifo_wr, pkt_fifo_full, pkt_fifo_empty                   : std_logic                                := '0';
  --signal dpr_din, dpr_dout                                            : std_logic_vector(7 downto 0);
  --signal dpr_wr                                                       : std_logic;
--  signal s_tx_ready                                                   : std_logic;
  signal s_leds : std_logic_vector(3 downto 0) := (others => '0');
-- 
begin  -- beh1


  snd_resp_dpr_clk <= Tx_Clk;
  snd_resp_dpr_ad  <= std_logic_vector(r.rd_ptr);
  snd_resp_ack     <= r.snd_resp_ack;

  snd_cmd_ack_fifo_clk <= Tx_Clk;
  snd_cmd_ack_fifo_rd  <= c.cmd_ack_fifo_rd;

  -- dpr_end_ptr <= unsigned(pkt_fifo_dout(DPR_AWDTH-1 downto 0));
  -- dpr_beg_ptr <= unsigned(pkt_fifo_dout(2*DPR_AWDTH-1 downto DPR_AWDTH));
  leds <= s_leds;
--  s_leds(0)   <= s_tx_ready;
--  tx_ready    <= s_tx_ready;

  is_irq_to_service <= true when (to_integer(unsigned(irqs)) /= 0) and (r.irq_throttle = 0) else false;

-- Main state machine used to send the packet

  snd1 : process (Tx_Clk, tx_rst_n)
  begin
    if tx_rst_n = '0' then              -- asynchronous reset (active low)
      r                 <= ETH_SENDER_REGS_INI;
      TxD               <= (others => '0');
      Tx_En             <= '0';
      TxD_0             <= (others => '0');
      Tx_En_0           <= '0';
      snd_resp_req_sync <= '0';
    elsif Tx_Clk'event and Tx_Clk = '1' then  -- rising clock edge
      r                 <= r_n;
      snd_resp_req_sync <= snd_resp_req;
      -- To minimize glitches and propagation delay, let's add pipeline register
      Tx_En_0           <= c.Tx_En;
      TxD_0             <= c.TxD;
      TxD               <= TxD_0;
      Tx_En             <= Tx_En_0;
    end if;
  end process snd1;  -- snd1

  snd2 : process (irqs, is_irq_to_service, my_mac, peer_mac, r,
                  snd_cmd_ack_fifo_din, snd_cmd_ack_fifo_empty,
                  snd_cmd_frm_num, snd_resp_dpr_din, snd_resp_end,
                  snd_resp_req_sync, snd_resp_start)
    variable v_TxD, v2_TxD : std_logic_vector(7 downto 0);
  begin  -- process snd1
    -- default values
    c          <= ETH_SENDER_COMB_DEFAULT;
    r_n        <= r;
    r_n.nibble <= not r.nibble;
    -- Always decrease the irq throttle counter
    if r.irq_throttle > 0 then
      r_n.irq_throttle <= r.irq_throttle - 1;
    end if;
    -- Main state machine
    case r.state is
      when WST_IDLE =>
        if r.irq_throttle < 0 then
          -- Enable irq_throttle counter
          r_n.irq_throttle <= - r.irq_throttle;
        end if;
        --r_n.ready <= '1';
        if (snd_cmd_ack_fifo_empty = '0') or
          (snd_resp_req_sync /= r.snd_resp_ack) or
          is_irq_to_service then
          -- We have a packet to transmit!
          --r_n.ready <= '0';
          r_n.state <= WST_SEND_PREAMB;
          r_n.count <= 15;
        end if;
      when WST_SEND_PREAMB =>
        c.TxD     <= x"5";
        c.Tx_En   <= '1';
        r_n.count <= r.count - 1;
        if r.count = 1 then
          r_n.state <= WST_SEND_SOF;
        end if;
      when WST_SEND_SOF =>
        c.TxD       <= x"D";
        c.Tx_En     <= '1';
                                         -- Prepare for sending of packet
        r_n.crc32   <= (others => '1');
        r_n.nibble  <= '0';
        r_n.count   <= 6;
        r_n.state   <= WST_SEND_PEER_MAC_0;
        r_n.pkt_len <= 0;
      when WST_SEND_PEER_MAC_0 =>
        -- Here we send the header and we decide whether we send the
        -- acknowledgements only or also the response
        v_TxD := peer_mac(r.count*8-1 downto (r.count-1)*8);
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          if r.count > 1 then
            r_n.count <= r.count - 1;
          else
            r_n.count <= 6;
            r_n.state <= WST_SEND_MY_MAC_0;
          end if;
        end if;
      when WST_SEND_MY_MAC_0 =>
        -- Here we send the header and we decide whether we send the
        -- acknowledgements only or also the response
        v_TxD := my_mac(r.count*8-1 downto (r.count-1)*8);
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          if r.count > 1 then
            r_n.count <= r.count - 1;
          else
            r_n.count <= 4;
            r_n.state <= WST_SEND_PROTO_0;
          end if;
        end if;
      when WST_SEND_PROTO_0 =>
        -- Here we send the header and we decide whether we send the
        -- acknowledgements only or also the response
        v_TxD := proto_id(r.count*8-1 downto (r.count-1)*8);
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          if r.count > 2 then
            r_n.count <= r.count - 1;
          else
            -- count was decreased to 2, so we prepare the byte to be
            -- sent and select the next part of the message
            r_n.tmp   <= proto_id(7 downto 0);
            r_n.state <= WST_SELECT_PART;
          end if;
        end if;
      when WST_SELECT_PART =>
        v_TxD := r.tmp;
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          -- Now we check possible actions
          -- Do we need to send an IRQ notification?
          if is_irq_to_service then
            r_n.state        <= WST_SEND_IRQS;
            -- We set the "irq_throttle" to the negative value.
            -- That ensures that counter starts counting down only after
            -- going through the IDLE state.
            r_n.irq_throttle <= -10000;  -- May be adjusted
          elsif snd_cmd_ack_fifo_empty = '0' then
            -- We go to sending ACKs
            r_n.state <= WST_SEND_ACKS;
          elsif snd_resp_req_sync /= r.snd_resp_ack then
            -- We go to sending content of the frame
            r_n.state  <= WST_SEND_PACKET_0;
            r_n.rd_ptr <= unsigned(snd_resp_start);
          else
            -- If necessary, pad the packet until it has correct length
            r_n.state <= WST_ADD_TRAILER;
          end if;
        end if;
      when WST_SEND_IRQS =>
        v_TxD := x"59";                  -- Marker of IRQ status
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          r_n.tmp     <= irqs;
          r_n.state   <= WST_SELECT_PART;
        end if;
      when WST_SEND_ACKS =>
        -- Here we send the acknowledgements
        -- At the end we check if there is response to be sent if yes,
        v_TxD(7)          := '1';
        v_TxD(6 downto 0) := snd_cmd_ack_fifo_din(14 downto 8);
        r_n.tmp           <= snd_cmd_ack_fifo_din(7 downto 0);
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD             <= v_TxD(7 downto 4);
          c.Tx_En           <= '1';
          c.cmd_ack_fifo_rd <= '1';
          r_n.pkt_len       <= r.pkt_len + 1;
          r_n.crc32         <= newcrc32_d8(v_TxD, r.crc32);
          r_n.state         <= WST_SELECT_PART;
        end if;
      when WST_SEND_PACKET_0 =>
        -- we send the marker of the response and then the contents of the response...
        v_TxD := x"5a";
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          r_n.state   <= WST_SEND_PACKET_0b;
        end if;
      when WST_SEND_PACKET_0b =>
        -- we send the number of the response 
        v_TxD := snd_cmd_frm_num;
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          r_n.state   <= WST_SEND_PACKET_0c;
        end if;
      when WST_SEND_PACKET_0c =>
        -- we send the 1st byte of the response time
        v_TxD := snd_resp_time(31 downto 24);
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          r_n.state   <= WST_SEND_PACKET_0d;
        end if;
      when WST_SEND_PACKET_0d =>
        -- we send the 2nd byte of the response time
        v_TxD := snd_resp_time(23 downto 16);
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          r_n.state   <= WST_SEND_PACKET_0e;
        end if;
      when WST_SEND_PACKET_0e =>
        -- we send the 3rd byte of the response time
        v_TxD := snd_resp_time(15 downto 8);
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          r_n.state   <= WST_SEND_PACKET_0f;
        end if;
      when WST_SEND_PACKET_0f =>
        -- we send the 4th byte of the response time
        v_TxD := snd_resp_time(7 downto 0);
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          r_n.state   <= WST_SEND_PACKET_1;
        end if;
      when WST_SEND_PACKET_1 =>
        v_TxD := snd_resp_dpr_din;
        if r.nibble = '0' then
          -- Increase the address (but due to 1clk delay,
          -- the DPRAM will still present the previous value in the cycle with
          -- nibble=1!)
          r_n.rd_ptr <= r.rd_ptr+1;
          c.TxD      <= v_TxD(3 downto 0);
          c.Tx_En    <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
                                         -- If we are at the last byte of the packet (it will be provided
                                         -- by the DPRAM in the next cycle), leave the loop
          if r.rd_ptr = unsigned(snd_resp_end) then
            r_n.state <= WST_SEND_PACKET_2;
          -- Remove packet from the packet FIFO
          end if;
        end if;
      when WST_SEND_PACKET_2 =>
        v_TxD := snd_resp_dpr_din;
        if r.nibble = '0' then
          c.TxD       <= v_TxD(3 downto 0);
          r_n.pkt_len <= r.pkt_len + 1;
          c.Tx_En     <= '1';
        else
          c.TxD            <= v_TxD(7 downto 4);
          c.Tx_En          <= '1';
          r_n.crc32        <= newcrc32_d8(v_TxD, r.crc32);
          -- Mark the packet as transmitted
          r_n.snd_resp_ack <= snd_resp_req_sync;
          -- if the length of packet is sufficient, go to sending of checksum
          if r.pkt_len > 98 then
            r_n.byte  <= 0;
            r_n.state <= WST_SEND_CRC;
          else
            r_n.state <= WST_ADD_TRAILER;
          end if;
        end if;
      when WST_ADD_TRAILER =>
        v_TxD := x"51";
        if r.nibble = '0' then
          c.TxD   <= v_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD       <= v_TxD(7 downto 4);
          c.Tx_En     <= '1';
          r_n.pkt_len <= r.pkt_len + 1;
          r_n.crc32   <= newcrc32_d8(v_TxD, r.crc32);
          -- if the length of packet is sufficient, go to sending of checksum
          if r.pkt_len > 98 then
            r_n.byte  <= 0;
            r_n.state <= WST_SEND_CRC;
          end if;
        end if;
      when WST_SEND_CRC =>
        v_TxD  := r.crc32(31-r.byte*8 downto 24-r.byte*8);
        v2_TxD := not rev(v_TxD);
        if r.nibble = '0' then
          c.TxD   <= v2_TxD(3 downto 0);
          c.Tx_En <= '1';
        else
          c.TxD   <= v2_TxD(7 downto 4);
          c.Tx_En <= '1';
          if r.byte < 3 then
            r_n.byte <= r.byte + 1;
          else
            r_n.count <= 24;             -- generate the IFG - 24 nibbles = 12 bytes = 96
            -- bits
            r_n.state <= WST_SEND_COMPLETED;
          end if;
        end if;
      when WST_SEND_COMPLETED =>
        if r.count > 0 then
          r_n.count <= r.count - 1;
        else
          --r_n.ready <= '1';
          r_n.state <= WST_IDLE;
        end if;
    end case;
  end process snd2;


-- Synchronization of the reset signal for the Tx_Clk domain
  process (Tx_Clk, rst_n)
  begin  -- process
    if rst_n = '0' then                 -- asynchronous reset (active low)
      tx_rst_n_0 <= '0';
      tx_rst_n_1 <= '0';
      tx_rst_n   <= '0';
    elsif Tx_Clk'event and Tx_Clk = '1' then  -- rising clock edge
      tx_rst_n_0 <= rst_n;
      tx_rst_n_1 <= tx_rst_n_0;
      tx_rst_n   <= tx_rst_n_1;
    end if;
  end process;

end beh1;
