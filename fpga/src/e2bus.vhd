-------------------------------------------------------------------------------
-- Title      : e2bus controller - version for 100 MBps
-- Project    : 
-------------------------------------------------------------------------------
-- File       : e2bus.vhd
-- Author     : FPGA Developer  <xl@wzab.nasz.dom>
-- Company    : 
-- Created    : 2018-03-15
-- Last update: 2019-07-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This is the main block of the e2bus controller
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

entity e2bus is

  generic (
    PHY_DTA_WIDTH  : integer := 8
    );

  port (
    leds    : out std_logic_vector(7 downto 0);
    irqs    : in  std_logic_vector(7 downto 0);
    -- BUS interface (depends on the BUS used)
    my_mac  : in  std_logic_vector(47 downto 0);
    sys_clk : in  std_logic;
    rst_n   : in  std_logic;
    -- MAC interface
    Rx_Clk  : in  std_logic;
    Rx_Er   : in  std_logic;
    Rx_Dv   : in  std_logic;
    RxD     : in  std_logic_vector(PHY_DTA_WIDTH-1 downto 0);
    Tx_Clk  : in  std_logic;
    Tx_En   : out std_logic;
    TxD     : out std_logic_vector(PHY_DTA_WIDTH-1 downto 0));

end entity e2bus;

architecture beh_rtl of e2bus is

  attribute keep       : string;
  attribute mark_debug : string;

  signal cmd_frame_dpr_ad         : std_logic_vector(C_CFR_ABITS-1 downto 0)   := (others => '0');
  signal cmd_frame_dpr_dout       : std_logic_vector(C_CFR_DBITS-1 downto 0)   := (others => '0');
  signal cmd_frame_dpr_din        : std_logic_vector(C_CFR_DBITS-1 downto 0)   := (others => '0');
  signal cmd_frame_dpr_wr         : std_logic_vector(0 downto 0)               := (others => '0');
  signal cmd_frame_dpr_clk        : std_logic                                  := '0';
  signal cmd_frame_wr_ptr         : std_logic_vector(C_CFR_ABITS-1 downto 0)   := (others => '0');
  signal cmd_frame_rd_ptr         : std_logic_vector(C_CFR_ABITS-1 downto 0)   := (others => '0');
  signal cmd_frame_wr_ptr_nsync   : std_logic_vector(C_CFR_ABITS-1 downto 0)   := (others => '0');
  signal cmd_frame_rd_ptr_sync    : std_logic_vector(C_CFR_ABITS-1 downto 0)   := (others => '0');
  signal cmd_desc_dpr_ad          : std_logic_vector(C_CDESC_ABITS-1 downto 0) := (others => '0');
  signal cmd_desc_dpr_dout        : std_logic_vector(C_CDESC_DBITS-1 downto 0) := (others => '0');
  signal cmd_desc_dpr_din         : std_logic_vector(C_CDESC_DBITS-1 downto 0) := (others => '0');
  signal cmd_desc_dpr_wr          : std_logic_vector(0 downto 0)               := (others => '0');
  signal cmd_desc_dpr_clk         : std_logic                                  := '0';
  signal cmd_last_processed_frame : std_logic_vector(15 downto 0)              := (others => '0');
  signal cmd_ack_fifo_full        : std_logic                                  := '0';
  signal cmd_ack_fifo_dout        : std_logic_vector(C_CACK_DBITS-1 downto 0)  := (others => '0');
  signal cmd_ack_fifo_wr          : std_logic                                  := '0';
  signal cmd_ack_fifo_clk         : std_logic                                  := '0';
  signal resp_ack_dpr_dout        : std_logic_vector(C_RACK_DBITS-1 downto 0)  := (others => '0');
  signal resp_ack_dpr_din         : std_logic_vector(C_RACK_DBITS-1 downto 0)  := (others => '0');
  signal resp_ack_dpr_ad          : std_logic_vector(C_RACK_ABITS-1 downto 0)  := (others => '0');
  signal resp_ack_dpr_wr          : std_logic_vector(0 downto 0)               := (others => '0');
  signal resp_ack_dpr_clk         : std_logic                                  := '0';
  signal resp_ack_wr_ptr          : std_logic_vector(C_RACK_ABITS-1 downto 0)  := (others => '0');
  signal resp_ack_rd_ptr          : std_logic_vector(C_RACK_ABITS-1 downto 0)  := (others => '0');
  signal resp_ack_wr_ptr_nsync    : std_logic_vector(C_RACK_ABITS-1 downto 0)  := (others => '0');
  signal resp_ack_rd_ptr_sync     : std_logic_vector(C_RACK_ABITS-1 downto 0)  := (others => '0');
  signal snd_cmd_ack_fifo_clk     : std_logic                                  := '0';
  signal snd_cmd_ack_fifo_empty   : std_logic                                  := '0';
  signal snd_cmd_ack_fifo_rd      : std_logic                                  := '0';
  signal snd_cmd_ack_fifo_din     : std_logic_vector(C_CACK_DBITS-1 downto 0)  := (others => '0');

  signal sys_cmd_frame_wr   : std_logic_vector(0 downto 0)                 := (others => '0');
  signal sys_cmd_frame_ad   : std_logic_vector(C_CFR_SYS_ABITS-1 downto 0) := (others => '0');
  signal sys_cmd_frame_din  : std_logic_vector(C_CFR_SYS_DBITS-1 downto 0) := (others => '0');
  signal sys_cmd_frame_dout : std_logic_vector(C_CFR_SYS_DBITS-1 downto 0) := (others => '0');

  signal sys_desc_dout : std_logic_vector(C_CDESC_DBITS-1 downto 0) := (others => '0');
  signal sys_desc_din  : std_logic_vector(C_CDESC_DBITS-1 downto 0) := (others => '0');
  signal sys_desc_wr   : std_logic_vector(0 downto 0)               := (others => '0');
  signal sys_desc_ad   : std_logic_vector(C_CDESC_ABITS-1 downto 0) := (others => '0');

  signal sys_resp_ack_wr   : std_logic_vector(0 downto 0)              := (others => '0');
  signal sys_resp_ack_ad   : std_logic_vector(C_RACK_ABITS-1 downto 0) := (others => '0');
  signal sys_resp_ack_din  : std_logic_vector(C_RACK_DBITS-1 downto 0) := (others => '0');
  signal sys_resp_ack_dout : std_logic_vector(C_RACK_DBITS-1 downto 0) := (others => '0');

  signal sys_resp_wr   : std_logic_vector(0 downto 0)                  := (others => '0');
  signal sys_resp_ad   : std_logic_vector(C_RESP_SYS_ABITS-1 downto 0) := (others => '0');
  signal sys_resp_din  : std_logic_vector(31 downto 0)                 := (others => '0');
  signal sys_resp_dout : std_logic_vector(31 downto 0)                 := (others => '0');

  signal snd_resp_dpr_wr   : std_logic_vector(0 downto 0)              := (others => '0');
  signal snd_resp_dpr_clk  : std_logic                                 := '0';
  signal snd_resp_dpr_din  : std_logic_vector(7 downto 0)              := (others => '0');
  signal snd_resp_dpr_dout : std_logic_vector(7 downto 0)              := (others => '0');
  signal snd_resp_dpr_ad   : std_logic_vector(C_RESP_ABITS-1 downto 0) := (others => '0');
  signal snd_resp_start    : std_logic_vector(C_RESP_ABITS-1 downto 0) := (others => '0');
  signal snd_resp_end      : std_logic_vector(C_RESP_ABITS-1 downto 0) := (others => '0');
  signal snd_resp_req      : std_logic                                 := '0';
  signal snd_resp_ack      : std_logic                                 := '0';

  signal snd_cmd_frm_num : std_logic_vector(7 downto 0) := (others => '0');

  signal snd_resp_ack_sync : std_logic := '0';

  signal rcv_ready_nsync, rcv_ready, rcv_ready_0 : std_logic := '0';


  signal rst_p     : std_logic := '0';
  --signal leds  : std_logic_vector(7 downto 0);
  signal rst_e2b_p : std_logic := '0';
  signal rst_e2b_n : std_logic := '1';

  signal special_cmd           : std_logic_vector(7 downto 0) := (others => '0');
  signal special_cmd_req_sync  : std_logic                    := '0';
  signal special_cmd_req_async : std_logic                    := '0';
  signal special_cmd_ack       : std_logic                    := '0';

  signal received_peer_mac : std_logic_vector(47 downto 0) := (others => '0');
  signal peer_mac          : std_logic_vector(47 downto 0) := (others => '0');

  -- Components from Core Generator
  component cmd_frm_dpr
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(12 downto 0);
      dina  : in  std_logic_vector(7 downto 0);
      douta : out std_logic_vector(7 downto 0);
      clkb  : in  std_logic;
      web   : in  std_logic_vector(0 downto 0);
      addrb : in  std_logic_vector(10 downto 0);
      dinb  : in  std_logic_vector(31 downto 0);
      doutb : out std_logic_vector(31 downto 0)
      );
  end component;


  component cmd_desc_dpr
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(4 downto 0);
      dina  : in  std_logic_vector(41 downto 0);
      douta : out std_logic_vector(41 downto 0);
      clkb  : in  std_logic;
      web   : in  std_logic_vector(0 downto 0);
      addrb : in  std_logic_vector(4 downto 0);
      dinb  : in  std_logic_vector(41 downto 0);
      doutb : out std_logic_vector(41 downto 0)
      );
  end component;

  component resp_ack_dpr
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(6 downto 0);
      dina  : in  std_logic_vector(14 downto 0);
      douta : out std_logic_vector(14 downto 0);
      clkb  : in  std_logic;
      web   : in  std_logic_vector(0 downto 0);
      addrb : in  std_logic_vector(6 downto 0);
      dinb  : in  std_logic_vector(14 downto 0);
      doutb : out std_logic_vector(14 downto 0)
      );
  end component;

  component cmd_ack_fifo
    port (
      rst    : in  std_logic;
      wr_clk : in  std_logic;
      rd_clk : in  std_logic;
      din    : in  std_logic_vector(15 downto 0);
      wr_en  : in  std_logic;
      rd_en  : in  std_logic;
      dout   : out std_logic_vector(15 downto 0);
      full   : out std_logic;
      empty  : out std_logic
      );
  end component;

  component resp_dpr
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(9 downto 0);
      dina  : in  std_logic_vector(31 downto 0);
      douta : out std_logic_vector(31 downto 0);
      clkb  : in  std_logic;
      web   : in  std_logic_vector(0 downto 0);
      addrb : in  std_logic_vector(11 downto 0);
      dinb  : in  std_logic_vector(7 downto 0);
      doutb : out std_logic_vector(7 downto 0)
      );
  end component;

  component wb_test_slvx is
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
      slv_stb_i   : in  std_logic);
  end component wb_test_slvx;

begin  -- architecture beh_rtl

  rst_p <= not rst_n;

  eth_receiver_1 : entity work.eth_receiver
    port map (
      my_mac                   => my_mac,
      received_peer_mac        => received_peer_mac,
      special_cmd              => special_cmd,
      special_cmd_req          => special_cmd_req_async,
      special_cmd_ack          => special_cmd_ack,
      -- CMD FRAME DPR INTERFACE
      cmd_frame_dpr_ad         => cmd_frame_dpr_ad,
      cmd_frame_dpr_dout       => cmd_frame_dpr_dout,
      cmd_frame_dpr_din        => cmd_frame_dpr_din,
      cmd_frame_dpr_wr         => cmd_frame_dpr_wr(0),
      cmd_frame_dpr_clk        => cmd_frame_dpr_clk,
      cmd_frame_wr_ptr         => cmd_frame_wr_ptr_nsync,
      cmd_frame_rd_ptr         => cmd_frame_rd_ptr_sync,
      -- CMD DESC INTERFACE
      cmd_desc_dpr_ad          => cmd_desc_dpr_ad,
      cmd_desc_dpr_dout        => cmd_desc_dpr_dout,
      cmd_desc_dpr_din         => cmd_desc_dpr_din,
      cmd_desc_dpr_wr          => cmd_desc_dpr_wr(0),
      cmd_desc_dpr_clk         => cmd_desc_dpr_clk,
      cmd_last_processed_frame => cmd_last_processed_frame,
      -- CMD ACK FIFO INTERFACE
      cmd_ack_fifo_full        => cmd_ack_fifo_full,
      cmd_ack_fifo_dout        => cmd_ack_fifo_dout,
      cmd_ack_fifo_wr          => cmd_ack_fifo_wr,
      cmd_ack_fifo_clk         => cmd_ack_fifo_clk,
      -- RESP ACK DPR INTERFACE
      resp_ack_dpr_dout        => resp_ack_dpr_dout,
      resp_ack_dpr_din         => resp_ack_dpr_din,
      resp_ack_dpr_ad          => resp_ack_dpr_ad,
      resp_ack_dpr_wr          => resp_ack_dpr_wr(0),
      resp_ack_dpr_clk         => resp_ack_dpr_clk,
      resp_ack_wr_ptr          => resp_ack_wr_ptr_nsync,
      resp_ack_rd_ptr          => resp_ack_rd_ptr_sync,

      -- System interface
      clk    => sys_clk,
      rst_n  => rst_e2b_n,
      ready  => rcv_ready_nsync,
      -- MAC interface
      Rx_Clk => Rx_Clk,
      Rx_Er  => Rx_Er,
      Rx_Dv  => Rx_Dv,
      RxD    => RxD,
      leds   => leds(7 downto 4));

  eth_sender_1 : entity work.eth_sender
    port map (
      -- System interface
      irqs                   => irqs,
      my_mac                 => my_mac,
      peer_mac               => peer_mac,
      clk                    => sys_clk,
      rst_n                  => rst_e2b_n,
      -- CMD ACK interface (connected directly)
      snd_cmd_ack_fifo_clk   => snd_cmd_ack_fifo_clk,
      snd_cmd_ack_fifo_rd    => snd_cmd_ack_fifo_rd,
      snd_cmd_ack_fifo_din   => snd_cmd_ack_fifo_din,
      snd_cmd_ack_fifo_empty => snd_cmd_ack_fifo_empty,
      -- CMD RESP interface (connected to FSM)
      snd_resp_dpr_clk       => snd_resp_dpr_clk,
      snd_resp_dpr_din       => snd_resp_dpr_din,
      snd_resp_dpr_ad        => snd_resp_dpr_ad,
      snd_resp_start         => snd_resp_start,
      snd_resp_end           => snd_resp_end,
      snd_resp_req           => snd_resp_req,
      snd_resp_ack           => snd_resp_ack,
      snd_cmd_frm_num        => snd_cmd_frm_num,
      -- MAC Interface
      Tx_Clk                 => Tx_Clk,
      Tx_En                  => Tx_En,
      TxD                    => TxD,
      leds                   => leds(3 downto 0));

  -- synchronizer for rcv_ready
  rcv_rd_p1 : process (rst_e2b_p, sys_clk) is
  begin  -- process rcv_ready
    if rst_e2b_p = '1' then             -- asynchronous reset (active low)
      rcv_ready   <= '0';
      rcv_ready_0 <= '0';
    elsif sys_clk'event and sys_clk = '1' then  -- rising clock edge
      rcv_ready_0 <= rcv_ready_nsync;
      rcv_ready   <= rcv_ready_0;
    end if;
  end process rcv_rd_p1;

  -- synchronizers for pointers
  -- For RESP ACK DPR
  sync_stlv_1 : entity work.sync_stlv
    generic map (
      width => C_RACK_ABITS)
    port map (
      din     => resp_ack_wr_ptr_nsync,
      clk_in  => resp_ack_dpr_clk,
      dout    => resp_ack_wr_ptr,
      clk_out => sys_clk,
      rst_p   => rst_e2b_p);

  sync_stlv_2 : entity work.sync_stlv
    generic map (
      width => C_RACK_ABITS)
    port map (
      din     => resp_ack_rd_ptr,
      clk_in  => sys_clk,
      dout    => resp_ack_rd_ptr_sync,
      clk_out => resp_ack_dpr_clk,
      rst_p   => rst_e2b_p);
  -- FOR CMD FRAME DPR
  sync_stlv_3 : entity work.sync_stlv
    generic map (
      width => C_CFR_ABITS)
    port map (
      din     => cmd_frame_wr_ptr_nsync,
      clk_in  => cmd_frame_dpr_clk,
      dout    => cmd_frame_wr_ptr,
      clk_out => sys_clk,
      rst_p   => rst_e2b_p);
  -- cmd_frame_wr_ptr is connected above, but it is not used.
  -- Notification about the written locations in that block is provided by the
  -- CMD FRAME descriptors. Therefore, that synchronizer is useless at the moment.


  sync_stlv_4 : entity work.sync_stlv
    generic map (
      width => C_CFR_ABITS)
    port map (
      din     => cmd_frame_rd_ptr,
      clk_in  => sys_clk,
      dout    => cmd_frame_rd_ptr_sync,
      clk_out => cmd_frame_dpr_clk,
      rst_p   => rst_e2b_p);

  -- Instantiation of the CMD FRAME DPR

  cmd_frm_dpr_1 : cmd_frm_dpr
    port map (
      clka  => cmd_frame_dpr_clk,
      wea   => cmd_frame_dpr_wr,
      addra => cmd_frame_dpr_ad,
      dina  => cmd_frame_dpr_dout,
      douta => cmd_frame_dpr_din,
      clkb  => sys_clk,
      web   => sys_cmd_frame_wr,
      addrb => sys_cmd_frame_ad,
      dinb  => sys_cmd_frame_din,
      doutb => sys_cmd_frame_dout);


  -- Instantiation of the CMD DESC DPR

  cmd_desc_dpr_1 : cmd_desc_dpr
    port map (
      clka  => cmd_desc_dpr_clk,
      wea   => cmd_desc_dpr_wr,
      addra => cmd_desc_dpr_ad,
      dina  => cmd_desc_dpr_dout,
      douta => cmd_desc_dpr_din,
      clkb  => sys_clk,
      web   => sys_desc_wr,
      addrb => sys_desc_ad,
      dinb  => sys_desc_din,
      doutb => sys_desc_dout);

  -- Instantiation of the CMD ACK FIFO

  cmd_ack_fifo_1 : entity work.cmd_ack_fifo
    port map (
      rst    => rst_e2b_p,
      wr_clk => cmd_ack_fifo_clk,
      rd_clk => snd_cmd_ack_fifo_clk,
      din    => cmd_ack_fifo_dout,
      wr_en  => cmd_ack_fifo_wr,
      rd_en  => snd_cmd_ack_fifo_rd,
      dout   => snd_cmd_ack_fifo_din,
      full   => cmd_ack_fifo_full,
      empty  => snd_cmd_ack_fifo_empty);

  -- Instantiation of the RESP ACK DPR

  resp_ack_dpr_1 : resp_ack_dpr
    port map (
      clka  => resp_ack_dpr_clk,
      wea   => resp_ack_dpr_wr,
      addra => resp_ack_dpr_ad,
      dina  => resp_ack_dpr_dout,
      douta => resp_ack_dpr_din,
      clkb  => sys_clk,
      web   => sys_resp_ack_wr,
      addrb => sys_resp_ack_ad,
      dinb  => sys_resp_ack_din,
      doutb => sys_resp_ack_dout);

  -- Instantiation of RESP DPR
  resp_dpr_1 : resp_dpr
    port map (
      clka  => sys_clk,
      wea   => sys_resp_wr,
      addra => sys_resp_ad,
      dina  => sys_resp_din,
      douta => sys_resp_dout,
      clkb  => snd_resp_dpr_clk,
      web   => snd_resp_dpr_wr,
      addrb => snd_resp_dpr_ad,
      dinb  => snd_resp_dpr_dout,
      doutb => snd_resp_dpr_din);

  cb0 : block is
    type T_SC_STATE is (SC_INIT, SC_IDLE, SC_KEEP_RESET, SC_WAIT_REQ);
    signal sc_state : T_SC_STATE            := SC_IDLE;
    signal count    : integer range 0 to 10 := 0;
  begin  -- block cb0

    rst_e2b_n <= not rst_e2b_p;
    -- Process responsible for handling of special commands
    process (sys_clk) is
    begin  -- process
      if sys_clk'event and sys_clk = '1' then  -- rising clock edge
        if rst_p = '1' then             -- synchronous reset (active high)
          special_cmd_req_sync <= '0';
          rst_e2b_p            <= '1';
          special_cmd_ack      <= '0';
          sc_state             <= SC_INIT;
          peer_mac             <= (others => '0');
        else
          special_cmd_req_sync <= special_cmd_req_async;
          case sc_state is
            when SC_INIT =>
              count    <= 10;
              sc_state <= SC_KEEP_RESET;
            when SC_IDLE =>
              if special_cmd_req_sync = '1' then
                -- Check the command
                case to_integer(unsigned(special_cmd)) is
                  when 1 =>
                    -- Reset and set MAC command
                    peer_mac        <= received_peer_mac;
                    rst_e2b_p       <= '1';
                    special_cmd_ack <= '1';
                    count           <= 10;
                    sc_state        <= SC_KEEP_RESET;
                  when 2 =>
                    -- Reset and stay idle command
                    null;
                  when 3 =>
                    -- Report status command
                    null;
                  when others => null;
                end case;
              end if;
            when SC_KEEP_RESET =>
              if count > 0 then
                count <= count - 1;
              else
                count           <= 10;
                rst_e2b_p       <= '0';
                special_cmd_ack <= '0';
                sc_state        <= SC_WAIT_REQ;
              end if;
            when SC_WAIT_REQ =>
              if count > 0 then
                count <= count - 1;
              else
                if special_cmd_req_sync = '0' then
                  sc_state <= SC_IDLE;
                end if;
              end if;
            when others => null;
          end case;
        end if;
      end if;
    end process;
  end block cb0;


  cb1 : block is

    type T_R1_STATE is (S1_IDLE_0, S1_IDLE_1, S1_EXEC_0, S1_FREE_SGM_0, S1_FREE_SGM_1);

    type T_R1_REGS is record
      state             : T_R1_STATE;
      --exp_frm_num       : unsigned(15 downto 0);
      --resp_frm_num      : unsigned(14 downto 0);
      sys_cmd_frame_ad  : unsigned(C_CFR_SYS_ABITS-1 downto 0);
      sys_resp_dpr_ad   : unsigned(C_RESP_SYS_ABITS-1 downto 0);
      sys_resp_dpr_dout : std_logic_vector(31 downto 0);
      sys_resp_dpr_wr   : std_logic;
      length            : unsigned(15 downto 0);
      exp_pkt_num       : unsigned(15 downto 0);
      exec_start        : std_logic;
      cmd_frame_rd_ptr  : std_logic_vector(C_CFR_ABITS-1 downto 0);
    end record T_R1_REGS;

    constant C_R1_REGS_INIT : T_R1_REGS := (
      state             => S1_IDLE_0,
      --exp_frm_num       => to_unsigned(1, 16),
      --resp_frm_num      => (others => '0'),
      sys_cmd_frame_ad  => (others => '0'),
      sys_resp_dpr_ad   => (others => '0'),
      sys_resp_dpr_dout => (others => '0'),
      sys_resp_dpr_wr   => '0',
      length            => (others => '0'),
      exp_pkt_num       => to_unsigned(1, 16),
      exec_start        => '0',
      cmd_frame_rd_ptr  => (others => '0')
      );

    type T_C1_COMB is record
      sys_desc_ad       : std_logic_vector(C_CDESC_ABITS-1 downto 0);
      sys_resp_dpr_ad   : std_logic_vector(C_RESP_SYS_ABITS-1 downto 0);
      sys_resp_dpr_dout : std_logic_vector(31 downto 0);
      sys_resp_dpr_wr   : std_logic;
      sys_cmd_frame_ad  : std_logic_vector(C_CFR_SYS_ABITS-1 downto 0);
      --resp_frm_num      : unsigned(14 downto 0);
      --resp_frm_len      : unsigned(15 downto 0);
      set_busy          : std_logic_vector(C_RESP_SYS_N-1 downto 0);
      request_cmd_frame : std_logic;
    end record T_C1_COMB;

    constant C_C1_DEFAULT : T_C1_COMB := (
      sys_desc_ad       => (others => '1'),
      sys_resp_dpr_ad   => (others => '0'),
      sys_resp_dpr_dout => (others => '0'),
      sys_resp_dpr_wr   => '0',
      sys_cmd_frame_ad  => (others => '0'),
      --resp_frm_num      => (others => '0'),
      --resp_frm_len      => (others => '0'),
      set_busy          => (others => '0'),
      request_cmd_frame => '0'
      );

    signal r1, r1_n                   : T_R1_REGS                             := C_R1_REGS_INIT;
    signal c1                         : T_C1_COMB                             := C_C1_DEFAULT;
    signal fr_tail, frame_to_transmit : unsigned(C_RESP_SYS_FBITS-1 downto 0) := (others => '0');

    -- That time counter will be used to timestamp the responses and to adaptively
    -- adjust the retransmission time, using the method based on  DOI: 10.1145/800056.802085 
    signal time_cnt : unsigned(31 downto 0) := (others => '0');
    
    type T_RESP_NUM is array (0 to C_RESP_SYS_N-1) of unsigned(14 downto 0);
    signal resp_num     : T_RESP_NUM     := (others => (others => '0'));
    type T_RESP_CMD_NUM is array (0 to C_RESP_SYS_N-1) of std_logic_vector(7 downto 0);
    signal resp_cmd_num : T_RESP_CMD_NUM := (others => (others => '0'));
    type T_RESP_LEN is array (0 to C_RESP_SYS_N-1) of unsigned(15 downto 0); 
    signal resp_len     : T_RESP_LEN     := (others => (others => '0'));
    type T_RESP_TIME is array (0 to C_RESP_SYS_N-1) of unsigned(31 downto 0);
    signal resp_busy    : std_logic_vector(C_RESP_SYS_N-1 downto 0);

    attribute keep of resp_num           : signal is "true";
    attribute mark_debug of resp_num     : signal is "true";
    attribute keep of resp_cmd_num       : signal is "true";
    attribute mark_debug of resp_cmd_num : signal is "true";
    attribute keep of resp_len           : signal is "true";
    attribute mark_debug of resp_len     : signal is "true";
    attribute keep of resp_busy          : signal is "true";
    attribute mark_debug of resp_busy    : signal is "true";


    signal in_transmission  : boolean                                      := false;
    signal resp_wait        : integer range 0 to 10                        := 0;
    signal cex_fr_full      : std_logic                                    := '0';
    signal cex_fr_wr        : std_logic                                    := '0';
    signal cex_cmd_frame_ad : std_logic_vector(C_CFR_SYS_ABITS-1 downto 0) := (others => '0');
    signal cex_fr_num       : unsigned(14 downto 0)                        := (others => '0');
    signal cex_cmd_num      : std_logic_vector(7 downto 0)                 := (others => '0');
    signal cex_fr_length    : unsigned(15 downto 0)                        := (others => '0');
    signal cex_exec_start   : std_logic                                    := '0';
    signal cex_exec_ack     : std_logic                                    := '0';

    signal wb_adr_o   : std_logic_vector(31 downto 0) := (others => '0');
    signal wb_dat_o   : std_logic_vector(31 downto 0) := (others => '0');
    signal wb_dat_i   : std_logic_vector(31 downto 0) := (others => '0');
    signal wb_we_o    : std_logic                     := '0';
    signal wb_sel_o   : std_logic                     := '0';
    signal wb_stb_o   : std_logic                     := '0';
    signal wb_ack_i   : std_logic                     := '0';
    signal wb_cyc_o   : std_logic                     := '0';
    signal wb_clk     : std_logic                     := '0';
    -- WB optional signals
    signal wb_err_i   : std_logic                     := '0';
    signal wb_rty_i   : std_logic                     := '0';
    signal wb_stall_i : std_logic                     := '0';


  begin  -- block c1

    -- Servicing of CMD frames
    -- 2-process state machine

    -- Mapping of internal signals to signals visible outside the block
    sys_desc_ad      <= c1.sys_desc_ad;
    sys_cmd_frame_ad <= c1.sys_cmd_frame_ad when c1.request_cmd_frame = '1' else cex_cmd_frame_ad;
    cmd_frame_rd_ptr <= r1.cmd_frame_rd_ptr;
    cex_exec_start   <= r1.exec_start;

    wb_test_slv_1 : wb_test_slvx
      port map (
        slv_clk_i   => wb_clk,
        slv_rst_i   => rst_e2b_p,
        slv_dat_i   => wb_dat_o,
        slv_dat_o   => wb_dat_i,
        slv_adr_i   => wb_adr_o,
        slv_cyc_i   => wb_cyc_o,
        slv_lock_i  => '0',
        slv_sel_i   => '1',
        slv_we_i    => wb_we_o,
        slv_ack_o   => wb_ack_i,
        slv_err_o   => wb_err_i,
        slv_rty_o   => wb_rty_i,
        slv_stall_o => wb_stall_i,
        slv_stb_i   => wb_stb_o);

    cmd_exec_1 : entity work.cmd_exec_wb
      port map (
        wb_adr_o      => wb_adr_o,
        wb_dat_o      => wb_dat_o,
        wb_dat_i      => wb_dat_i,
        wb_we_o       => wb_we_o,
        wb_sel_o      => wb_sel_o,
        wb_stb_o      => wb_stb_o,
        wb_ack_i      => wb_ack_i,
        wb_cyc_o      => wb_cyc_o,
        wb_clk        => wb_clk,
        wb_err_i      => wb_err_i,
        wb_rty_i      => wb_rty_i,
        wb_stall_i    => wb_stall_i,
        desc_din      => sys_desc_dout,
        cmd_frame_ad  => cex_cmd_frame_ad,
        cmd_frame_din => sys_cmd_frame_dout,
        resp_ad       => sys_resp_ad,
        resp_dout     => sys_resp_din,
        resp_wr       => sys_resp_wr(0),
        fr_full       => cex_fr_full,
        fr_num        => cex_fr_num,
        fr_length     => cex_fr_length,
        fr_cmd_num    => cex_cmd_num,
        fr_wr         => cex_fr_wr,
        exec_start    => cex_exec_start,
        exec_ack      => cex_exec_ack,
        rst_p         => rst_e2b_p,
        sys_clk       => sys_clk);

    cps1 : process (rst_e2b_p, sys_clk)
    begin  -- process rdp1
      if rst_e2b_p = '1' then
        r1 <= C_R1_REGS_INIT;
      elsif sys_clk'event and sys_clk = '1' then  -- rising clock edge
        r1 <= r1_n;
      end if;
    end process cps1;
    cpc1 : process (cex_exec_ack, cmd_frame_wr_ptr, r1, rcv_ready,
                    sys_cmd_frame_dout, sys_desc_dout) is
      -- Finally that process will be handling the bus communication.
      -- Therefore it should be free from retransmission and similar tasks.
      -- So how it can mark the frame for transmission?
      -- do I need to create yet another memory?

      --variable v_cur_resp_frame   : unsigned(C_RESP_SYS_FBITS-1 downto 0);
      variable v_frame_to_confirm : unsigned(14 downto 0);
      variable v_sys_cmd_frame_ad : std_logic_vector(C_CFR_ABITS-1 downto 0);
      variable v_frame_nr_8bit    : unsigned(7 downto 0);
    begin  -- process
      r1_n                <= r1;
      c1                  <= C_C1_DEFAULT;
      --v_cur_resp_frame    := r1.resp_frm_num(C_RESP_SYS_FBITS-1 downto 0);
      c1.sys_desc_ad      <= std_logic_vector(r1.exp_pkt_num(C_CDESC_ABITS-1 downto 0));
      c1.sys_cmd_frame_ad <= std_logic_vector(r1.sys_cmd_frame_ad);
      case r1.state is
        when S1_IDLE_0 =>
          -- Wait until new packet is available. Packets must come in sequence!
          -- Please remember, that the memory must be initialized properly,
          -- so that initial, value is NOT recognized as a valid frame number.
          -- Now we initialize it (in receiver) to 0xffffffff (-1)
          -- We wait until the expected frame becomes available
          -- After setting the address we must wait one clock
          if rcv_ready = '1' then
            -- We must wait, until receiver completes initialization of the
            -- descriptor's memory
            r1_n.state <= S1_IDLE_1;
          end if;
        when S1_IDLE_1 =>
          if stlv2cdesc_frm_num(sys_desc_dout) = std_logic_vector(r1.exp_pkt_num) then
            -- We start the processing. The command executor block gets the information
            -- about the processed segment from the descriptor (sys_desc_dout).
            r1_n.exec_start <= not r1.exec_start;
            r1_n.state      <= S1_EXEC_0;
          end if;
        when S1_EXEC_0 =>
          -- In this state we wait until processing is finished
          if cex_exec_ack = r1.exec_start then
            -- Execution is finished and we go to freeing of segments          
            if stlv2cdesc_pstart(sys_desc_dout) = r1.cmd_frame_rd_ptr then
              -- We must remember that current frame starts at TAIL
              -- Here we can remove our current frame from the buffer
              -- But we need to consider the alligment of the next buffer!
              v_sys_cmd_frame_ad    := std_logic_vector(unsigned(stlv2cdesc_pend(sys_desc_dout)) + 3);
              v_sys_cmd_frame_ad(0) := '0';
              v_sys_cmd_frame_ad(1) := '0';
              r1_n.cmd_frame_rd_ptr <= v_sys_cmd_frame_ad;
              -- First we need to read the frame stored in the next segment of
              -- circular buffer
              c1.request_cmd_frame  <= '1';  -- To access the cmd_frame DPR
              --v_sys_cmd_frame_ad    := stlv2cdesc_pend(sys_desc_dout);
              c1.sys_cmd_frame_ad   <= v_sys_cmd_frame_ad(v_sys_cmd_frame_ad'left downto 2);
              -- in the next state, we will get the number of the next frame
              r1_n.state            <= S1_FREE_SGM_0;
            else
              -- Loop to waiting for the next packet
              -- Increase the number of the expected packet
              r1_n.exp_pkt_num <= r1.exp_pkt_num + 1;
              r1_n.state       <= S1_IDLE_1;
            end if;
          end if;
        when S1_FREE_SGM_0 =>
          -- We still need access to the CMD FRAME DPR
          c1.request_cmd_frame <= '1';       -- To access the cmd_frame DPR
          -- Here we need to detect if it was the last segment
          -- If yes, then we don't do anything!!!
          -- However that detection is not trivial. We can't rely on having the
          -- tail equal to the cmd_frame_wr_ptr, because the frame may be still
          -- during reception. It looks like we need to remember the last "end"
          -- address and use it here for comparison...
          -- In fact such address is available. It is the 
          if r1.cmd_frame_rd_ptr /= cmd_frame_wr_ptr then
            -- Now we can read the number of the frame;
            v_frame_nr_8bit := unsigned(sys_cmd_frame_dout(7 downto 0));
            -- We check if that frame is older than the last one;
            v_frame_nr_8bit := v_frame_nr_8bit - unsigned(r1.exp_pkt_num(7 downto 0));
            if v_frame_nr_8bit(7) = '1' then
              -- It was an older frame, so we should remove it as well
              -- We need to read its descriptor
              c1.sys_desc_ad <= std_logic_vector(v_frame_nr_8bit(C_CDESC_ABITS-1 downto 0));
              r1_n.state     <= S1_FREE_SGM_1;
            else
              -- cleaning is finished, we return to servicing the packets
              r1_n.exp_pkt_num <= r1.exp_pkt_num + 1;
              r1_n.state       <= S1_IDLE_1;
            end if;
          else
            -- cleaning is finished, we return to servicing the packets
            r1_n.exp_pkt_num <= r1.exp_pkt_num + 1;
            r1_n.state       <= S1_IDLE_1;
          end if;
        when S1_FREE_SGM_1 =>
          -- and adjust the tail pointer
          v_sys_cmd_frame_ad    := std_logic_vector(unsigned(stlv2cdesc_pend(sys_desc_dout)) + 3);
          v_sys_cmd_frame_ad(0) := '0';
          v_sys_cmd_frame_ad(1) := '0';
          r1_n.cmd_frame_rd_ptr <= v_sys_cmd_frame_ad;
          -- r1_n.cmd_frame_rd_ptr <= stlv2cdesc_pend(sys_desc_dout);
          -- We still need access to the CMD FRAME DPR
          c1.request_cmd_frame <= '1';       -- To access the cmd_frame DPR
          -- Now we can read the descriptor
          --v_sys_cmd_frame_ad    := stlv2cdesc_pend(sys_desc_dout);
          c1.sys_cmd_frame_ad   <= v_sys_cmd_frame_ad(v_sys_cmd_frame_ad'left downto 2);
          r1_n.state            <= S1_FREE_SGM_0;
        when others => null;
      end case;
    end process cpc1;


    -- Process responsible for allocation of response frames
    -- Please note, that it is the command executor thats sets the frame number!
    -- Maybe it can be simplified? The response frame queue is full only
    -- when the descriptor of the frame to be filled is busy now?
    -- I should check this concept later on...
    arf1 : process (cex_fr_num, fr_tail) is
      variable v_new_resp_fr_num : unsigned(14 downto 0);
      variable v_new_fr_head     : unsigned(C_RESP_SYS_FBITS-1 downto 0);

    begin  -- process arf1
      v_new_resp_fr_num := cex_fr_num + 1;
      v_new_fr_head     := v_new_resp_fr_num(C_RESP_SYS_FBITS-1 downto 0);
      if v_new_fr_head = fr_tail then
        cex_fr_full <= '1';
      else
        cex_fr_full <= '0';
      end if;
    end process arf1;

    -- Process responsible for handling the busy flags  sending of frames, and handling of head and tail
    -- pointers

    sys_resp_ack_ad <= resp_ack_rd_ptr;

    psf1 : process (sys_clk) is
      variable v_frame_to_confirm : integer;
      variable v_fr_head          : integer;
      variable v_word_adr         : integer;
    begin  -- process psf1
      if sys_clk'event and sys_clk = '1' then  -- rising clock edge
        if rst_e2b_p = '1' then         -- synchronous reset (active high)
          resp_busy         <= (others => '0');
          resp_num          <= (others => (others => '0'));
          resp_len          <= (others => (others => '0'));
          snd_resp_ack_sync <= '0';
          snd_resp_req      <= '0';
          resp_wait         <= 0;
          fr_tail           <= (others => '0');
          in_transmission   <= false;
          resp_ack_rd_ptr   <= (others => '0');
          frame_to_transmit <= (others => '0');
        else
          if resp_wait > 0 then
            resp_wait <= 0;
          end if;
          v_fr_head         := to_integer(cex_fr_num(C_RESP_SYS_FBITS-1 downto 0));
          -- Synchronize the transmission ACK signal (to be moved later to the
          -- separate process?)
          snd_resp_ack_sync <= snd_resp_ack;
          -- Set the busy flags
          if cex_fr_wr = '1' then
            resp_busy(v_fr_head)    <= '1';
            resp_time(v_fr_head)    <= time_cnt;
            resp_time(v_fr_head)(31) <= not time_cnt(31);  -- Negate to ensure
                                                           -- immediate transmission
            resp_num(v_fr_head)     <= cex_fr_num;
            resp_len(v_fr_head)     <= cex_fr_length;
            resp_cmd_num(v_fr_head) <= cex_cmd_num;
          end if;
          -- Service the RESP confirmations
          if resp_wait = 0 then
            -- We must wait until the memory output is stable
            if resp_ack_rd_ptr /= resp_ack_wr_ptr then
              -- There is confirmation to handle
              v_frame_to_confirm := to_integer(unsigned(sys_resp_ack_dout(C_RESP_SYS_FBITS-1 downto 0)));
              if unsigned(sys_resp_ack_dout) = resp_num(v_frame_to_confirm) then
                -- We check if it is not an outdated delayed ACK
                resp_busy(v_frame_to_confirm) <= '0';
              end if;
              -- Advance the pointer
              resp_ack_rd_ptr <= std_logic_vector(unsigned(resp_ack_rd_ptr) + 1);
              -- Set the flag needed to wait until the meory output is stable.
              resp_wait       <= 1;
            end if;
          end if;
          -- We can try to advance the tail pointer
          -- But where is it stored??? It is our sole responsibility
          -- To maintain it!
          -- Writing of responses is done by our "c1" process.
          if v_fr_head /= to_integer(fr_tail) then
            -- There is a response that is not confirmed yet
            if resp_busy(to_integer(fr_tail)) = '0' then
              -- We may advance the tail pointer, but we must be sure,
              -- that this frame is not transmitted now!
              -- Now we do it in a very simple suboptimal way - just checking
              -- if the frame_to_transmit is equal to fr_tail.
              -- If yes, then we wait.
              if frame_to_transmit /= fr_tail then
                fr_tail <= fr_tail + 1;
                -- However, when moving the frame slot tail pointer, we should also try to
                -- move the circular buffer tail pointer.

              end if;
            end if;
          end if;
          if not in_transmission then
            -- Check if the frame to transmit is busy
            if (resp_busy(to_integer(frame_to_transmit)) = '1') and 
              (time_cnt - resp_time(frame_to_transmit) > retr_threshold)  then
              -- Here we should also verify, that the sufficient amount
              -- of time elapsed since the previous transmission of the frame.
              -- We should also somehow mark the frames that are transmitted
              -- for the first time (the simplest trick would be to take the
              -- negated value of the current timestamp?)
              resp_time(frame_to_transmit) <= time_cnt;
              -- What if the response was fried just above?
              -- Then we may start its transmission.
              -- However, it is not a problem, as the tail wont be moved after
              -- that response as long, as it is being transmitted...
              v_word_adr      := 1024*to_integer(frame_to_transmit);
              snd_resp_start  <= std_logic_vector(to_unsigned(v_word_adr, C_RESP_ABITS));
              v_word_adr      := v_word_adr + (3+to_integer(resp_len(to_integer(frame_to_transmit))));
              snd_resp_end    <= std_logic_vector(to_unsigned(v_word_adr, C_RESP_ABITS));
              snd_cmd_frm_num <= resp_cmd_num(to_integer(frame_to_transmit));
              snd_resp_req    <= not snd_resp_req;
              in_transmission <= true;
            else
              -- Check the next response
              frame_to_transmit <= frame_to_transmit + 1;
            end if;
          else
            -- Transmission is in progress
            if snd_resp_ack_sync = snd_resp_req then
              in_transmission   <= false;
              frame_to_transmit <= frame_to_transmit + 1;
            end if;
          end if;
        end if;
      end if;
    end process psf1;

    -- Process responsible for handling the busy flags  sending of frames, and handling of head and tail
    -- pointes


  end block cb1;


end architecture beh_rtl;
