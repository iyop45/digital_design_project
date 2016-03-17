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
 
	TYPE state_type IS (INIT, FIRST, SECOND, AStart, AFinish, LShake, PShake); 
	SIGNAL curState, nextState : state_type;
	SIGNAL counter_enable : std_logic := '0';
	SIGNAL counter_reset : std_logic := '0';
	SIGNAL count : INTEGER := 0;
	SIGNAL hasProcessedACommand : std_logic := '0';
BEGIN
	combi_nextState : PROCESS(clk, curState, rxnow, rxData, seqdone, count, hasProcessedACommand, stxDone, cmdRecieve, lRecieve, pRecieve)
		-- char variables are used for debugging
		-- variable char1, char2, char3, char4 : integer := 0;
	BEGIN
		stxNow <= '0';
		stxData <= "00000000";
		
		lNow <= '0';
		pNow <= '0';
		rxdone <= '0';
		
		counter_enable <= '0';
		counter_reset <= '0';
		cmdNow <= '0';
		numWords_bcd <= ("0000", "0000", "0000");
		
		hasProcessedACommand <= '0';
		
		CASE curState IS
			WHEN INIT => 
				counter_reset <= '0';
 
				IF rxnow = '1' THEN
					CASE rxData IS
 
						WHEN "01100001" | "01000001" => -- a or A
							--char1 := to_integer(rxData);

							stxNow <= '1';
							stxData <= rxData;

							nextState <= FIRST;
 
							-- Print 3 bytes preceeding the peak byte
						WHEN "01101100" | "01001100" => -- l or L
							-- These commands should not result in any action if a data sequence has not been processed prior to receiving them.
							IF seqDone = '1' AND hasProcessedACommand = '1' THEN
								lNow <= '1';

								stxNow <= '1';
								stxData <= rxData; 

								nextState <= LShake;
							ELSE		
								nextState <= INIT; 
							END IF;
 
							-- Print peak byte
						WHEN "01110000" | "01010000" => -- p or P 
							-- These commands should not result in any action if a data sequence has not been processed prior to receiving them.
							IF seqDone = '1' AND hasProcessedACommand = '1' THEN
								pNow <= '1';

								stxNow <= '1';
								stxData <= rxData; 

								nextState <= PShake;
							ELSE
								nextState <= INIT; 
							END IF;
 
						WHEN OTHERS => 
							nextState <= INIT;
 
					END CASE;
				ELSE
					-- Keep waiting until rxnow is 1 (data is ready to read)
					rxdone <= '0';
					nextState <= INIT;
				END IF;
 
			WHEN FIRST => 
				-- Recieved a character
				-- Wait for rxnow to become 0
				counter_enable <= '0';

				stxData <= rxData;
				stxNow <= '0';
 
				IF rxnow = '0' AND stxDone = '1' THEN
					rxdone <= '0';
					nextState <= SECOND;
				ELSE
					rxdone <= '1';
					nextState <= FIRST;
				END IF;
 
 
 
			WHEN SECOND => 
				IF count = 3 THEN
					-- Nothing yet
					cmdNow <= '1';
					nextState <= AStart; 
				ELSE
					IF rxnow = '1' THEN -- If data is ready to read
						-- Every keystroke needs to be printed
						--txnow <= '1';
						--txData <= rxData;
 
						IF rxData(7 DOWNTO 4) = "0011" AND (rxData(3 DOWNTO 0) > "0000" OR rxData(3 DOWNTO 0) < "1001") THEN -- Check if byte is a valid ascii integer
							-- The 3 NNN digits
							CASE count IS
								WHEN 0 => 
									numWords_bcd(0) <= rxData(3 DOWNTO 0);
									--char2 := to_integer(rxData);
								WHEN 1 => 
									numWords_bcd(1) <= rxData(3 DOWNTO 0);
									--char3 := to_integer(rxData);
								WHEN 2 => 
									numWords_bcd(2) <= rxData(3 DOWNTO 0);
									--char4 := to_integer(rxData);
								WHEN OTHERS => 
									NULL;
							END CASE;

							counter_enable <= '1';
							--prntNow <= '1';
							nextState <= FIRST;
						ELSE
							-- Not an integer
							nextState <= FIRST;
						END IF;
					ELSE
						nextState <= SECOND;
					END IF;
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
				--if seqDone = '1' then
				--char1 := 0;
				--char2 := 0;
				--char3 := 0;
				--char4 := 0;
				counter_reset <= '1';
				hasProcessedACommand <= '1';
				nextState <= INIT;
				--else
				-- nextState <= AFinish; 
				--end if;
 
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
 
	--txNow <= txnowsignal; 
	-----------------------------------------------------
	-- Integer counter, primarily used for counting 3Ns in ANNN command
	counter : PROCESS(clk, counter_enable, counter_reset)
	BEGIN
		IF counter_reset = '1' THEN
			count <= 0;
			--counter_reset <= '0';
		ELSIF rising_edge(clk) AND counter_enable = '1' THEN
			count <= count + 1;
		END IF;
	END PROCESS; -- counter
	-----------------------------------------------------
	-- Change state on every rising clock edge
	seq_state : PROCESS(clk, reset)
	BEGIN
		IF reset = '1' AND clk'EVENT AND clk = '1' THEN
			curState <= INIT;
		ELSIF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
		END IF;
	END PROCESS; -- seq
	END; -- parseCommands
