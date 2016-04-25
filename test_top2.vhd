----------------------------------------------------------------------------
--	test_top.vhd -- Top level component for testing
----------------------------------------------------------------------------
-- Author:  Dinesh Pamunuwa
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
--	This component instantiates the Rx, Tx and control_unit_test
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- Version:			1.0
-- Revision History:
--  08/01/2013 (Dinesh): Created using Xilinx Tools 14.2 for 64 bit Win
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity TEST_TOP is 
	port (
		clk:	in std_logic;
		clear:	in std_logic; -- asynchronous reset
		reset:	in std_logic; -- synchronous reset
		rxdata:	in std_logic;
		txdata:	out std_logic;
		rxDataOut: out std_logic_vector(7 downto 0)
	);
end;

architecture STRUCT of TEST_TOP is

  component UART_TX_CTRL is
    port ( 
      SEND : in  STD_LOGIC;
      DATA : in  STD_LOGIC_VECTOR (7 downto 0);
      CLK : in  STD_LOGIC;
      READY : out  STD_LOGIC;
      UART_TX : out  STD_LOGIC
    );
  end component;  
  
  component UART_RX_CTRL is
    port(
      RxD: in std_logic;                -- serial data in
      sysclk: in std_logic; 		-- system clock
      reset: in std_logic;		--	synchronous reset
      rxDone: in std_logic;		-- data succesfully read (active high)
      rcvDataReg: out std_logic_vector(7 downto 0); -- received data
      dataReady: out std_logic;	        -- data ready to be read
      setOE: out std_logic;		-- overrun error (active high)
      setFE: out std_logic		-- frame error (active high)
    );
  end component; 

  component dataGen is
    port (
      clk:		in std_logic;
      reset:		in std_logic; -- synchronous reset
      ctrlIn: in std_logic;
      ctrlOut: out std_logic;
      data: out std_logic_vector(7 downto 0)
    );
  end component;
  
  component dataConsume is
    port (
      clk:		in std_logic;
      reset:		in std_logic; -- synchronous reset
      start: in std_logic;
      numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
      ctrlIn: in std_logic;
      ctrlOut: out std_logic;
      data: in std_logic_vector(7 downto 0);
      dataReady: out std_logic;
      byte: out std_logic_vector(7 downto 0);
      seqDone: out std_logic;
      maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
      dataResults: out CHAR_ARRAY_TYPE(0 to 6) 
    );
  end component;
  
  component cmdProc is
    port (
      clk:		in std_logic;
      reset:		in std_logic;
      rxnow:		in std_logic;
      rxData:			in std_logic_vector (7 downto 0);
      txData:			out std_logic_vector (7 downto 0);
      rxdone:		out std_logic;
      ovErr:		in std_logic;
      framErr:	in std_logic;
      txnow:		out std_logic;
      txdone:		in std_logic;
      start: out std_logic;
      numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
      dataReady: in std_logic;
      byte: in std_logic_vector(7 downto 0);
      maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
      dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
      seqDone: in std_logic
    );
  end component;
	
	

--
--	component CONTROL_UNIT_TST is
--		port (
--			clk:		in std_logic; -- system clock
--			clear:		in std_logic; -- asynchronous reset
--			reset:		in std_logic; -- synchronous reset
--			rxnow:		in std_logic; -- data ready signal from Rx
--			rx:			in std_logic_vector (7 downto 0); -- parallel data in
--			tx:			out std_logic_vector (7 downto 0); -- parallel data out
--			rxdone:		out std_logic; -- data read complete signal to Rx
--			ovrerr:		in std_logic; -- overrun error (not used in this implementation)
--			framerr:	in std_logic; -- frame error  (not used in this implementation)
--			txnow:		out std_logic; -- data ready signal to Tx
--			txdone:		in std_logic  -- data transmission complete signal from Tx
--		);
--	end component;	

	for rx: UART_RX_CTRL use
	  entity work.UART_RX_CTRL(rcvr2);

	signal sig_rxnow, sig_rxdone, sig_overr, sig_framerr, sig_txnow, sig_txdone: std_logic;
	signal sig_rxdata, sig_txdata: std_logic_vector (7 downto 0);
begin 

--control:	CONTROL_UNIT_TST
--	port map (
--		clk => clk,
--		clear => clear,
--		reset => reset,
--		rxnow => sig_rxnow,
--		rx => sig_rxdata,
--		tx => sig_txdata,
--		rxdone => sig_rxdone,
--		ovrerr => sig_overr,
--		framerr => sig_framerr,
--		txnow => sig_txnow,
--		txdone => sig_txdone
--	);

tx: UART_TX_CTRL
	port map (
		SEND => sig_txnow,
		DATA => sig_txdata,
		CLK => clk,
		READY => sig_txdone,
		UART_TX => txdata
	);

rx : UART_RX_CTRL
   port map(
	  RxD => rxdata, -- input serial line
	  sysclk => clk,
	  reset => reset, 
	  rxDone => sig_rxdone,
	  rcvDataReg => sig_rxdata,
     dataReady => sig_rxnow,
     setOE => sig_overr,
     setFE =>  sig_framerr
   ); 
	
  dataGen1: dataGen
    port map (
      clk => clk,
      reset => reset,
      ctrlIn => ctrl_consDriv,
      ctrlOut => ctrl_genDriv,
      data => sig_data
    );
    
  dataConsume1: dataConsume
    port map (
      clk => clk,
      reset => reset,
      start => sig_start,
      numWords_bcd => sig_numWords_bcd,
      ctrlIn => ctrl_genDriv,
      ctrlOut => ctrl_consDriv,
      dataReady => sig_dataReady,
      byte => sig_byte,
      data => sig_data,
      seqDone => sig_seqDone,
      maxIndex => sig_maxIndex,
      dataResults => sig_dataResults
    );
    
  cmdProc1: cmdProc
    port map (
      clk => clk,
      reset => reset,
      rxNow => sig_rxNow,
      rxData => sig_rxData,
      txData => sig_txData,
      rxDone => sig_rxDone,
      ovErr => sig_ovErr,
      framErr => sig_framErr,
      txNow => sig_txNow,
      txDone => sig_txDone,
      start => sig_start,
      numWords_bcd => sig_numWords_bcd,
      dataReady => sig_dataReady,
      byte => sig_byte,
      maxIndex => sig_maxIndex,
      seqDone => sig_seqDone,
      dataResults => sig_dataResults
    );
	
end;
