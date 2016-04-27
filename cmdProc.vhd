---
--- author: roy miles
--- top level entity wrapping the sub components
---

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

USE ieee.numeric_std.ALL; -- additional debug

USE work.common_pack.ALL;

ENTITY cmdProc IS
	PORT (
		clk : IN std_logic;
		reset : IN std_logic;
		rxnow : IN std_logic; -- valid port
		rxData : IN std_logic_vector (7 DOWNTO 0);
		txData : OUT std_logic_vector (7 DOWNTO 0);
		rxdone : OUT std_logic;
		ovErr : IN std_logic;
		framErr : IN std_logic;
		txnow : OUT std_logic;
		txdone : IN std_logic;
		start : OUT std_logic;
		--numWords: out std_logic_vector(9 downto 0);
		numWords_bcd : OUT BCD_ARRAY_TYPE(2 DOWNTO 0);
		dataReady : IN std_logic;
		byte : IN std_logic_vector(7 DOWNTO 0);
		maxIndex : IN BCD_ARRAY_TYPE(2 DOWNTO 0);
		--dataResults: in std_logic_vector(55 downto 0);
		dataResults : IN CHAR_ARRAY_TYPE(0 TO RESULT_BYTE_NUM - 1);
		seqDone : IN std_logic
	);
END cmdProc;

ARCHITECTURE behaviour OF cmdProc IS
  TYPE state_type IS (INIT, SENDING, WAITING); 
    
	SIGNAL curState, nextState : state_type;
	SIGNAL counter_enable : std_logic := '0';
	SIGNAL counter_reset : std_logic := '0';
	SIGNAL count : integer := 0;
	
	SIGNAL startFormat, finishFormat : std_logic;
	
	-- Signals between sub components
	SIGNAL aNow : std_logic := '0';
	SIGNAL aRecieve : std_logic := '0';

	SIGNAL lNow : std_logic := '0';
	SIGNAL lDone : std_logic := '0';
	SIGNAL lRecieve : std_logic := '0';
 
	SIGNAL pNow : std_logic := '0';
	SIGNAL pDone : std_logic := '0';
	SIGNAL pRecieve : std_logic := '0'; 
 
	SIGNAL stxDone : std_logic; 
 
	SIGNAL stxNow_cmdParse : std_logic := '0';
	SIGNAL stxData_cmdParse : std_logic_vector (7 DOWNTO 0) := "00011000";

	SIGNAL stxNow_dataProc : std_logic := '0';
	SIGNAL stxData_dataProc : std_logic_vector (7 DOWNTO 0) := "00011000";

	SIGNAL stxNow_Lcmd : std_logic := '0';
	SIGNAL stxData_Lcmd : std_logic_vector (7 DOWNTO 0) := "00011000";

	SIGNAL stxNow_Pcmd : std_logic := '0';
	SIGNAL stxData_Pcmd : std_logic_vector (7 DOWNTO 0) := "00011000";
 
	SIGNAL dataProc_TxHold : std_logic;
	SIGNAL Lcmd_TxHold : std_logic;
	SIGNAL Pcmd_TxHold : std_logic;
 
	--variable ascii_reg : CHAR_ARRAY_TYPE(7 downto 0); -- Max queue size of 8 ascii characters
	SIGNAL printNow, printSpace : std_logic := '0';
BEGIN
	-- entity for parsing and processing commands
	cmd_parse : ENTITY work.cmdParse(parseCommands)
		PORT MAP(
			clk => clk, 
			reset => reset, 
 
			rxnow => rxnow, 
			rxData => rxData, 
			rxdone => rxdone, 
 
			stxData => stxData_cmdParse, 
			stxnow => stxnow_cmdParse, 
			stxdone => stxdone, 
			numWords_bcd => numWords_bcd, 
			
			startFormat => startFormat,
			finishFormat => finishFormat,
 
			cmdNow => aNow, 
			cmdRecieve => aRecieve, 
 
			lNow => lNow, 
			lRecieve => lRecieve, 

			pNow => pNow, 
			pRecieve => pRecieve, 
 
			seqDone => seqDone
		);
	-- queue_print :entity work.printQueue(queuePrint) port map (
	-- clk => clk,
	-- reset => reset, 
	-- 
	-- stxData => stxData,
	-- stxnow => stxNow,
	-- stxdone => stxDone,
	-- 
	-- printNow => printNow,
	-- printSpace => printSpace 
	-- 
	-- );

	data_process : ENTITY work.dataProc(processData)
		PORT MAP(
			clk => clk, 
			reset => reset, 

			stxData => stxData_dataProc, 
			stxnow => stxnow_dataProc, 
			stxdone => stxdone, 
 
			start => start, 
			dataReady => dataReady, 
			byte => byte, 
			seqDone => seqDone, 
 
			cmdNow => aNow, 
			cmdRecieve => aRecieve, 
 
			txHold => dataProc_TxHold
		);
 
	l_cmd : ENTITY work.Lcmd(Lcommand)
		PORT MAP(
			clk => clk, 
			reset => reset, 

			stxData => stxData_Lcmd, 
			stxnow => stxnow_Lcmd, 
			stxdone => stxdone, 
 
			dataResults => dataResults, 
 
			lNow => lNow, 
			lRecieve => lRecieve, 
 
			txHold => Lcmd_TxHold
		);
 
	p_cmd : ENTITY work.Pcmd(Pcommand)
		PORT MAP(
			clk => clk, 
			reset => reset, 

			stxData => stxData_Pcmd, 
			stxnow => stxnow_Pcmd, 
			stxdone => stxdone, 
 
			dataResults => dataResults, 
			maxIndex => maxIndex, 
 
			pNow => pNow, 
			pRecieve => pRecieve, 
 
			txHold => Pcmd_TxHold
		); 
 
	-----------------------------------------------------
	tx_print : PROCESS(clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN
		  --IF startFormat = '0' THEN
			txNow <= '0';
			txData <= "11111111";
			-- set Tx inputs to value of internal signal
			IF dataProc_TxHold = '1' THEN
				txNow <= stxNow_dataProc;
				txData <= stxData_dataProc;
			ELSIF Lcmd_TxHold = '1' THEN
				txNow <= stxNow_Lcmd;
				txData <= stxData_Lcmd;
			ELSIF Pcmd_TxHold = '1' THEN
				txNow <= stxNow_Pcmd;
				txData <= stxData_Pcmd;
			ELSE
				txNow <= stxNow_cmdParse;
				txData <= stxData_cmdParse; 
			END IF; 
 
 
			-- set signal to value of Tx outputs
			stxDone <= txDone;
			
			--END IF;
		ELSE NULL;
		END IF;
	END PROCESS;
		
	combi_nextState : PROCESS(clk, curState, startFormat)
	BEGIN
	  counter_enable <= '0';
	  counter_reset <= '0';
	  finishFormat <= '0';
	  
		CASE curState IS
			WHEN INIT => 
			  IF startFormat = '1' THEN
			     finishFormat <= '0';
			     nextState <= SENDING; 
			  ELSE
			     nextState <= INIT;
			  END IF;
			 
		  WHEN SENDING =>
		    finishFormat <= '0';
				counter_enable <= '1';
				
				CASE count IS
					WHEN 0 | 7 => 
				    txData <= "00001010";
				  WHEN 1 | 8 =>
				    txData <= "00001101";
				  WHEN 2 | 3 | 4 | 5 | 6 =>
				    txData <= "00111101";
				  WHEN OTHERS =>
				    finishFormat <= '1';
				    counter_reset <= '1';
				    nextState <= INIT;
				END CASE;  
		    
		  WHEN WAITING =>
		    finishFormat <= '0';
		    txNow <= '1';
		    nextState <= SENDING;
		    
			WHEN OTHERS =>
			  finishFormat <= '1';
				nextstate <= INIT;
 
		END CASE;
	END PROCESS;
	
	-----------------------------------------------------
	-- Integer counter, primarily used for counting 3Ns in ANNN command
	counter : PROCESS(clk, counter_enable, counter_reset)
	BEGIN
		IF counter_reset = '1' THEN
			count <= 0;
		ELSIF rising_edge(clk) AND counter_enable = '1' THEN
			count <= count + 1;
		END IF;
	END PROCESS; -- counter
	-----------------------------------------------------
	-- Change state on every rising clock edge
	seq_state : PROCESS(clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
		END IF;
	END PROCESS; -- seq	
 
	END;


