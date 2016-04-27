---
--- author: roy miles
--- processing the commands send from Rx
---

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
--use ieee.std_logic_arith.all;
--use ieee.numeric_std_unsigned.all; -- need for charN debugging

USE ieee.numeric_std.ALL; -- additional debug

USE work.common_pack.ALL;

ENTITY cmdParse IS
	PORT (
		clk : IN std_logic;
		reset : IN std_logic;
 
		rxnow : IN std_logic; -- valid port
		rxData : IN std_logic_vector (7 DOWNTO 0);
		rxdone : OUT std_logic;
 
		stxData : OUT std_logic_vector (7 DOWNTO 0);
		stxnow : OUT std_logic;
		stxdone : IN std_logic;
		numWords_bcd : OUT BCD_ARRAY_TYPE(2 DOWNTO 0);
		
		cmdNow : OUT std_logic; 
		cmdRecieve : IN std_logic;
 
		lNow : OUT std_logic;
		lRecieve : IN std_logic;
 
		pNow : OUT std_logic;
		pRecieve : IN std_logic;
 
		seqDone : IN std_logic
	);
END cmdParse;

ARCHITECTURE parseCommands OF cmdParse IS
	-- Specification Part 1:
	-- 1. Parse/Detect a 4 character string with ANNN or aNNN pattern
	-- NNN is a 3 digit sequence 000-999
	-- Baude-rate = 9600
	-- \n\r terminating characters
 
	-- Part 2:
	-- 1. The value NNN means NNN bytes need to be processed
	-- NNN must be an integer / number
	-- No interruption while processing the NNN bytes
	-- Each byte printing in hexadecimal format
 
	TYPE state_type IS (INIT, FIRST, STXDATA_WAIT, SECOND, AStart, AFinish, LShake, PShake, VALIDINPUT, BADINPUT, SPACE, STXDATA_WAIT_SPACE); 
	SIGNAL curState, nextState : state_type;
	SIGNAL counter_enable : std_logic := '0';
	SIGNAL counter_reset : std_logic := '0';
	SIGNAL count : integer := 0;
	
	SIGNAL numWords_en : integer := 0; -- Needs to be an integer as it can enable different writes
	SIGNAL numWords_bcd_reset : std_logic := '0';
	SIGNAL numWords_bcd_reg : BCD_ARRAY_TYPE(2 DOWNTO 0) := ("0000", "0000", "0000");
	
	SIGNAL hasProcessedACommand_en : std_logic := '0';
	SIGNAL hasProcessedACommand_reg : std_logic := '0';
	SIGNAL hasProcessedACommand : std_logic := '0';
	
	SIGNAL stxData_en : std_logic := '0';
	SIGNAL stxData_reg : std_logic_vector (7 DOWNTO 0) := "11111111"; 
BEGIN
	combi_nextState : PROCESS(clk, curState, rxnow, rxData, seqdone, count, stxDone, cmdRecieve, lRecieve, pRecieve, numWords_bcd_reg, hasProcessedACommand)
	BEGIN 
	  rxDone <= '0';
	  
		stxNow <= '0';
		
		stxData_en <= '0';
		stxData_reg <= "00000000";
		
		lNow <= '0';
		pNow <= '0';
		--rxdone <= '0';
		
		counter_enable <= '0';
		counter_reset <= '0';
		cmdNow <= '0';
		
		numWords_en <= 0;
		numWords_bcd_reset <= '0';
		numWords_bcd_reg <= ("0000", "0000", "0000");
		
		hasProcessedACommand_en <= '0';
		hasProcessedACommand_reg <= '0';

		CASE curState IS
			WHEN INIT => 
 
				IF rxnow = '1' THEN
					--stxNow <= '1';
					CASE rxData IS
 
						WHEN "01100001" | "01000001" => -- a or A
							--char1 := to_integer(rxData);

							--stxNow <= '0';
							
							stxData_en <= '1';
							stxData_reg <= rxData;
							
							--rxDone <= '1';BLEH

							--nextState <= STXDATA_WAIT;
							nextState <= VALIDINPUT;
 
							-- Print 3 bytes preceeding the peak byte
						WHEN "01101100" | "01001100" => -- l or L
							-- These commands should not result in any action if a data sequence has not been processed prior to receiving them.
							IF seqDone = '1' AND hasProcessedACommand = '1' THEN
								lNow <= '1';

								--stxNow <= '1';
								
  							  stxData_en <= '1';
							  stxData_reg <= rxData;

								nextState <= LShake;
							ELSE		
								nextState <= INIT; 
							END IF;
 
							-- Print peak byte
						WHEN "01110000" | "01010000" => -- p or P 
							-- These commands should not result in any action if a data sequence has not been processed prior to receiving them.
							IF seqDone = '1' AND hasProcessedACommand = '1' THEN
								pNow <= '1';

								--stxNow <= '1';
								
							  stxData_en <= '1';
							  stxData_reg <= rxData;

								nextState <= PShake;
							ELSE
								nextState <= INIT; 
							END IF;
 
						WHEN OTHERS =>
							stxData_en <= '1';
							stxData_reg <= rxData;
							
							nextState <= BADINPUT;
 
					END CASE;
				ELSE
					-- Keep waiting until rxnow is 1 (data is ready to read)
					--rxdone <= '0';
					nextState <= INIT;
				END IF;
				
			WHEN BADINPUT =>
			 counter_reset <= '1';
		   stxNow <= '1';
			 rxDone <= '1';
			 nextState <= INIT;	
				
			WHEN VALIDINPUT =>
		   stxNow <= '1';
			 rxDone <= '1';
			 nextState <= STXDATA_WAIT;	
				
			WHEN STXDATA_WAIT =>
			  rxDone <= '0';
			  
			  --stxNow <= '0';
			  
				stxData_en <= '1';
				stxData_reg <= rxData;
			  
				IF stxDone = '0' THEN --- waits until Tx modules is sending
					nextstate <= FIRST;
				ELSE
					nextstate <= STXDATA_WAIT;
				END IF;	
 
			WHEN FIRST => 		  
			  
			  rxDone <= '0';
			  
				-- Recieved a character
				-- Wait for rxnow to become 0
				counter_enable <= '0';

				stxData_en <= '1';
				stxData_reg <= rxData;
				stxNow <= '0';
 
				IF rxnow = '0' AND stxDone = '1' THEN
					--rxdone <= '0';
					nextState <= SECOND;
				ELSE
					--rxdone <= '1';
					nextState <= FIRST;
				END IF; 
				
			WHEN SECOND => 
				IF count = 3 THEN
					-- Nothing yet
					--cmdNow <= '1';
					
					stxData_en <= '1';
					stxData_reg <= "00100000";		
					
					nextState <= SPACE; 			
					
				ELSE
				  rxDone <= '0';
				  
					IF rxnow = '1' THEN -- If data is ready to read
						-- Every keystroke needs to be printed
						
						--rxDone <= '1';
						
						IF rxData(7 DOWNTO 4) = "0011" AND (rxData(3 DOWNTO 0) > "0000" OR rxData(3 DOWNTO 0) < "1001") THEN -- Check if byte is a valid ascii integer
							-- The 3 NNN digits
							CASE count IS
								WHEN 0 => 
								  numWords_en <= 1;
									numWords_bcd_reg(0) <= rxData(3 DOWNTO 0);
								WHEN 1 => 
								  numWords_en <= 2;
									numWords_bcd_reg(1) <= rxData(3 DOWNTO 0);
								WHEN 2 => 
								  numWords_en <= 3;
									numWords_bcd_reg(2) <= rxData(3 DOWNTO 0);
								WHEN OTHERS => 
									NULL;
							END CASE;

							counter_enable <= '1';
							
							stxNow <= '1';
							
							stxData_en <= '1';
							stxData_reg <= rxData;				
							
							--nextState <= STXDATA_WAIT;
							nextState <= VALIDINPUT;
						ELSE
							stxData_en <= '1';
							stxData_reg <= rxData;
							
							nextState <= BADINPUT;
						END IF;
					ELSE
						nextState <= SECOND;
					END IF;
				END IF;
				
			WHEN SPACE =>
			   stxNow <= '1';
			   cmdNow <= '1';
			   nextState <= STXDATA_WAIT_SPACE;
			   
			WHEN STXDATA_WAIT_SPACE =>
				stxData_en <= '1';
				stxData_reg <= rxData;
			  
				IF stxDone = '0' THEN --- waits until Tx modules is sending
					nextstate <= AStart;
				ELSE
					nextstate <= STXDATA_WAIT_SPACE;
				END IF;				   
 
				-- Initial 3-way handshaking protocol for the dataProc module
			WHEN AStart => 
				-- Processing part has been notified of the command
				IF cmdRecieve = '1' THEN
					cmdNow <= '0';
					nextState <= AFinish;
				ELSE
					cmdNow <= '1';
					nextState <= AStart;
				END IF;
 
				-- Final handshaking acknologement for the dataProc module
			WHEN AFinish => 
				-- Finished processing
				if seqDone = '1' then
					counter_reset <= '1';
				
					hasProcessedACommand_en <= '1';
					hasProcessedACommand_reg <= '1';
				
					nextState <= INIT;
				else
					nextState <= AFinish; 
				end if;
 
				-- Initial 3-way handshaking protocol for the L module 
			WHEN LShake => 
				IF lRecieve = '1' AND stxDone = '1' THEN
					lNow <= '0';
					nextState <= INIT;
				ELSE
					lNow <= '1';
					nextState <= LShake;
				END IF;
 
				-- Initial 3-way handshaking protocol for the P module 
			WHEN PShake => 
				IF pRecieve = '1' AND stxDone = '1' THEN
					pNow <= '0';
					nextState <= INIT;
				ELSE
					pNow <= '1';
					nextState <= PShake;
				END IF; 
 
			WHEN OTHERS => 
				nextstate <= INIT;
 
		END CASE;
		
	END PROCESS; -- combi_nextState 

	-----------------------------------------------------	
	-- Registers to stop latches from being inferrred
	reg : PROCESS(clk, numWords_en, numWords_bcd_reg, numWords_bcd_reset, hasProcessedACommand_en, stxData_en)
	BEGIN
--	  IF rising_edge(clk) AND numWords_bcd_reset = '1' THEN
--	    numWords_bcd(0) <= "0000";
--		  numWords_bcd(1) <= "0000";
--		  numWords_bcd(2) <= "0000";
--		ELSIF rising_edge(clk) AND numWords_en = '1' THEN
--      numWords_bcd(0) <= numWords_bcd_reg(0);
--      numWords_bcd(1) <= numWords_bcd_reg(1);
--      numWords_bcd(2) <= numWords_bcd_reg(2);
--		END IF;
  
    IF rising_edge(clk) AND numWords_en = 1 THEN
      numWords_bcd(2) <= numWords_bcd_reg(0);
    END IF;

    IF rising_edge(clk) AND numWords_en = 2 THEN
      numWords_bcd(1) <= numWords_bcd_reg(1);
    END IF;
    
    IF rising_edge(clk) AND numWords_en = 3 THEN
      numWords_bcd(0) <= numWords_bcd_reg(2);
    END IF;    

	  IF rising_edge(clk) AND stxData_en = '1' THEN
      stxData <= stxData_reg;
		END IF;

	  IF rising_edge(clk) AND hasProcessedACommand_en = '1' THEN
      hasProcessedACommand <= hasProcessedACommand_reg;
		END IF;
	END PROCESS; -- counter
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
--		IF reset = '1' AND clk'EVENT AND clk = '1' THEN
--			curState <= INIT;
--		ELSIF clk'EVENT AND clk = '1' THEN
--			curState <= nextState;
--		END IF;
		IF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
		END IF;
	END PROCESS; -- seq
	
	END; -- parseCommands





