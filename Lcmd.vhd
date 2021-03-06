--- author: joshua coop
---
--- processing the data processors data for L commands
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
--USE ieee.std_logic_arith.ALL;
USE ieee.numeric_std.ALL; 
USE work.common_pack.ALL;

ENTITY Lcmd IS
	PORT (
		clk : IN std_logic;
		reset : IN std_logic;
 
		stxData : OUT std_logic_vector (7 DOWNTO 0);
		stxNow : OUT std_logic;
		stxDone : IN std_logic;
 
--		dataResults : IN CHAR_ARRAY_TYPE(0 TO RESULT_BYTE_NUM - 1);
		dataResults: in std_logic_vector(55 downto 0);

		lNow : IN std_logic; --- tells the module when an L comand has been recieved
		lRecieve : OUT std_logic; --- tells cmdparse that i know an L command has been sent
		TxHold : OUT std_logic 
 
	);
END Lcmd;

ARCHITECTURE Lcommand OF Lcmd IS
	TYPE state_type IS (S0, S1, S2, S3, S4, S5, S6, S7, S55);
	SIGNAL curState, nextState : state_type;
	SIGNAL counter_enable : std_logic := '0';
	SIGNAL counter_reset : std_logic;
	SIGNAL counter2_reset : std_logic;
	SIGNAL count : INTEGER := 0;
	SIGNAL count2 : INTEGER := 0; -- counts the number of iterations
	SIGNAL NEWDataResults : std_logic_vector(7 downto 0);

BEGIN
	combi_nextState : PROCESS(clk, curState, lNow, dataResults, stxDone, Count)
	BEGIN
		counter_reset <= '0';
		lRecieve <= '0'; 
		counter_enable <= '0';
		stxData <= NEWDataResults;
		stxNow <= '0';
		TxHold <= '1'; 
		
		CASE curState IS
			--- handshake to the module to ensure tha the rxdata has recieved an L or l
			WHEN S0 => 
				TxHold <= '0';
				counter_reset <= '1'; --- resets the counter for the next L command
				IF lNow = '1' THEN
					nextstate <= S1;
				ELSE
					nextstate <= S0;
				END IF;
 
				--- handshake back to the cmdparce to say that we know that an L or l has been recieved 
			WHEN S1 => 
				counter_reset <= '0';
				TxHold <= '1'; --- says that this module will access the Tx moduls signals 
				lRecieve <= '1';
				IF lNow = '0' THEN
					nextstate <= S2;
				ELSE
					nextstate <= S1;
				END IF;
				
				--- sends the data results values in the order they were processed, from 0 to 7 
			WHEN S2 => 
			  counter_enable <= '0';
				stxData <= NEWdataResults;
				stxNow <= '1';
				lRecieve <= '0';
				nextstate <= S3;
				
			WHEN S3 =>		  
			  stxnow <= '0';
			  stxdata <= NEWdataResults;
			  IF stxdone = '0' THEN --- waits until Tx modules is sending before the module can wait until it the byte has been sent
			    nextstate <= S4;
			  ELSE
			    nextstate <= S3;
			  END IF;
			      
				-- waits until the Tx moduls finishes sending the current byte before issuing the send of the next byte 
			WHEN S4 => 
				stxData <= NEWdataResults;
				IF stxDone = '1' THEN
					nextstate <= S55;
				ELSE
					nextstate <= S4;
				END IF;	
				
				
		  WHEN S55 =>
		     counter_enable <= '1';
		    	IF count2 <= 1 THEN
					 nextstate <= S5;
				 ELSE 
					 nextstate <= S2;
				 END IF;				
				
				--- sends a space to the output as per specification 
			WHEN S5 => 
				counter2_reset <= '1'; 
		    counter_enable <= '0';			  
				stxData <= x"20"; -- space at the output after each dataResult is sent
				stxNow <= '1';
				nextstate <= S6;
				
      WHEN S6 =>
				counter2_reset <= '0';         
        stxdata <= x"20";
        stxnow <= '0';
        IF stxdone = '0' THEN --- waits until Tx modules is sending before the module can wait until it the byte has been sent
          nextstate <= S7;
        ELSE
          nextstate <= S6;
        END IF;
 
			WHEN S7 => 
			  stxData <= x"20";
				IF stxDone = '1' THEN --- waits for the Tx module to be ready to send the next bytes
					IF Count = 55 THEN --- Check to see if all the data result bytes have been sent to stxData to ensure all bytes have been sent
						nextstate <= S0;
					ELSE
						nextstate <= S2;
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
		ELSIF rising_edge(clk) AND counter_enable = '1' AND count < 55  THEN
			count <= count + 4;
		END IF;
	END PROCESS; -- counter
	-----------------------------------------------------
		counter2 : PROCESS(clk, counter_enable, counter2_reset)
	BEGIN
		IF counter2_reset = '1' THEN
			count2 <= 0;
		ELSIF rising_edge(clk) AND counter_enable = '1' AND count2 < 1 THEN
			count2 <= count2 + 1;
		END IF;
	END PROCESS; -- counter for counting the number of iterations
	-----------------------------------------------------
	stateChange : PROCESS (clk, reset)
	BEGIN
		IF reset = '1' AND clk'EVENT AND clk = '1' THEN
			curState <= S0;
		ELSIF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
		END IF;
	END PROCESS; --stateChange
	----------------------------------------------------- 
	byte_test: process(dataResults, count)
	BEGIN
	  IF dataResults((55-count) downto (52-count)) < "1010" AND count < 8 THEN
	    NEWDataResults <= "0011" & dataResults((55-count) downto (52-count));
	    
	  ELSIF dataResults((55-count) downto (52-count)) > "1001" AND count < 8 THEN
	    NEWDataResults <= std_logic_vector( unsigned(  std_logic_vector'("0011"&dataResults((55-count) downto (52-count))))  + ("00000111"));
	    
	  END IF;
	END PROCESS; --stateChange
	-----------------------------------------------------
	END;
	-----------------------------------------------------


