
---author: joshua coop
---
--- processing the data processors data for P and L commands
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;

USE work.common_pack.ALL;

ENTITY Pcmd IS
	PORT (
		clk : IN std_logic;
		reset : IN std_logic;

		stxData : OUT std_logic_vector (7 DOWNTO 0);
		stxNow : OUT std_logic;
		stxDone : IN std_logic;

		maxIndex : IN BCD_ARRAY_TYPE(2 DOWNTO 0);
		dataResults : IN CHAR_ARRAY_TYPE(0 TO RESULT_BYTE_NUM - 1);
		--inter module signals
		pNow : IN std_logic; --- goes high when an P or p command has beebn typed into the terminal
		pRecieve : OUT std_logic; --- send back to tell cmdparse that data is not being processed by this module
		TxHold : OUT std_logic --- goes high when printing to the Tx module and goes low when it stops
	);
END Pcmd;

ARCHITECTURE Pcommand OF Pcmd IS
	TYPE state_type IS (S0, S1, S2, S3, S4, S5, S6, S7);
	SIGNAL curState, nextState : state_type;
	SIGNAL counter_enable : std_logic := '0';
	SIGNAL counter_reset : std_logic;
	SIGNAL count : INTEGER := 0;
BEGIN
	dataSend : PROCESS(stxDone, pNow, count, maxIndex, dataResults, curState)
	BEGIN
		CASE curState IS 
			--- handshake to the module to ensure tha the rxdata has recieved an P or p
			WHEN S0 => 
				counter_reset <= '1';
				stxNow <= '0'; 
				IF pNow = '1' THEN
					nextstate <= S1;
				ELSE
					nextstate <= S0;
				END IF;
 
				--- handshake back to the cmdparce to say that we know that an P or p has been recieved 
			WHEN S1 => 
				counter_reset <= '0';
				pRecieve <= '1';
				IF pNow = '0' THEN
					nextstate <= S2;
				ELSE
					nextstate <= S1;
				END IF;
 
				--- sends the peak byte to the tx module 
			WHEN S2 => 
				stxData <= dataResults(3);
				stxNow <= '1';
				pRecieve <= '0';
				nextstate <= S3;
 
				--- sets txNow = 0 so that it has only been high for a single clock cycle, as per specification 
			WHEN S3 => 
				stxNow <= '0';
				IF stxDone = '1' THEN
					nextstate <= S4;
				ELSE
					nextstate <= S3;
				END IF;

 
				--- sends a space to the output 
			WHEN S4 => 
				stxData <= x"50"; -- space at the output
				stxNow <= '1';
				nextstate <= S5;
 
			WHEN S5 => 
				stxNow <= '0';
				IF stxDone = '1' THEN -- checks to see when Tx is ready to send the next byte
					nextstate <= S6;
				ELSE
					nextstate <= S5;
				END IF;
 
			WHEN S6 => 
				stxData <= "0011" & maxIndex(2 - count);--- converts the numbers on Maxindex to ascii characters
				stxNow <= '1';
				counter_enable <= '1';
				nextstate <= S7;
 
 
			WHEN S7 => 
				counter_enable <= '0';
				stxNow <= '0';
				IF stxDone = '1' THEN --- checks to see when the Tx module is ready to send the next byte
					IF count = 3 THEN --- checks to see that the whole neumber on the maxindex line has been sent
						nextstate <= S0;
					ELSE
						nextstate <= S6;
					END IF; 
				ELSE
					nextstate <= S7;
				END IF;

			WHEN OTHERS => 
				nextstate <= S0;
 
		END CASE;
	END PROCESS;
	----------------------------------------------------
	counter : PROCESS(clk, counter_enable, counter_reset)
	BEGIN
		IF counter_reset = '1' THEN
			count <= 0;
		ELSIF rising_edge(clk) AND counter_enable = '1' THEN
			count <= count + 1;
		END IF;
	END PROCESS; -- counter
	----------------------------------------------------
	stateChange : PROCESS (clk, reset)
	BEGIN
		IF reset = '1' AND clk'EVENT AND clk = '1' THEN
			curState <= S0;
		ELSIF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
		END IF;
	END PROCESS; --clock
	-----------------------------------------------------
	END;
