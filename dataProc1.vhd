---
--- author: joshua coop
--- processing the data recieved from the data processor to send to the Tx module
---

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

USE ieee.numeric_std.ALL; -- additional debug

USE work.common_pack.ALL;

ENTITY dataProc IS
	PORT (
		clk : IN std_logic;
		reset : IN std_logic;
 
		stxData : OUT std_logic_vector (7 DOWNTO 0);
		stxNow : OUT std_logic;
		stxDone : IN std_logic;
 
		start : OUT std_logic;
		dataReady : IN std_logic;
		byte : IN std_logic_vector(7 DOWNTO 0);
		seqDone : IN std_logic;
 
		cmdNow : IN std_logic; --- goes high when a start command is typed into the terminal of the format aNNN or ANNN
		cmdRecieve : OUT std_logic; --- send back to tell cmdparse that data is not being processed by this module
		TxHold : OUT std_logic
	);
END dataProc;

ARCHITECTURE processData OF dataProc IS
	TYPE state_type IS (S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10);--
	SIGNAL curState, nextState : state_type;
	SIGNAL seqDoneGet : std_logic;
	SIGNAL BYTENEW : std_logic_vector(7 downto 0);
  SIGNAL counter_enable : std_logic := '0';
	SIGNAL counter_reset : std_logic := '0';
	SIGNAL count : INTEGER := 0;
BEGIN
	combi_nextState : PROCESS(clk, curState, cmdNow, dataready, byte, stxDone, seqDone, seqDoneGet)
	BEGIN
		cmdRecieve <= '0';
		start <= '0';
		stxData <= BYTENEW;
		stxNow <= '0';
		TxHold <= '1';
	
		CASE curState IS
			WHEN S0 => 
			
				TxHold <= '0';
				--- tells us when a new byte can be sent through the Tx module and that a start has been sent through the Rx module
				IF cmdNow = '1' THEN
					nextstate <= S1;
				ELSE
					nextstate <= S0;
				END IF;
 
			WHEN S1 => 
				cmdRecieve <= '1';
				IF cmdNow = '0' THEN --- a duel handshake between cmd parse and this module
					nextState <= S2;
				ELSE
					nextState <= S1;
				END IF;
 
			WHEN S2 => 
				TxHold <= '1';
				cmdRecieve <= '0';
				start <= '1';
				nextstate <= S3;
 
			WHEN S3 => --- waits until there is a new byte of data from the data processor
				start <= '0';
				IF dataready = '1' THEN
					nextstate <= S4;
				ELSE
					nextstate <= S3; 
				END IF;
 
---------------------------------------------------------------------------------------
			WHEN S4 => 
			  counter_enable <= '0';
				stxData <= BYTENEW; --- gives the byte given by the data procossor to the Tx module
				stxNow <= '1'; ---issues a send command
				nextstate <= S5;
				
			WHEN S5 =>
				stxData <= BYTENEW;
				stxNow <= '0';
				IF stxDone = '0' THEN --- waits until Tx modules is sending
					nextstate <= S6;
				ELSE
					nextstate <= S5;
				END IF;			  

 
			WHEN S6 => --sets stxNow to 0 and waits to issue the next send 
				stxData <= BYTENEW;
				IF stxDone = '1' THEN --- waits until Tx modules ready to send again
          nextstate <= S7;
				ELSE
					nextstate <= S6;
				END IF;	
	    
		  WHEN S7 =>
		     counter_enable <= '1';
		    	IF count = 4 THEN
					 nextstate <= S8;
				 ELSE 
					 nextstate <= S4;
				 END IF;
				
				
 
 -------------------------------------------------------------------------------
			WHEN S8 => -- adds a space after every character and issue a send command
			  counter_enable <= '0';
			  counter_reset <= '1';
				stxData <= x"20";
				stxNow <= '1';
				nextstate <= S9;
				
			WHEN S9 =>
			  counter_reset <= '0';
			  stxData <= x"20";
				stxNow <= '0';
				IF stxDone = '0' THEN --- waits until Tx modules is sending
					nextstate <= S10;
				ELSE
					nextstate <= S9;
				END IF;

			WHEN S10 =>
			  stxData <= x"20"; 
				IF stxDone = '1' THEN ---waits until Tx has sent the space
				  IF seqDoneGet = '1' THEN --- checks to see if all words have been processed
					 nextstate <= S0;
				  ELSE
					 nextstate <= S2;
				  END IF;
        ELSE
          nextstate <= S10;
        END IF ;
        
		END CASE;
	END PROCESS; -- datasend
		-----------------------------------------------------
	seqDoneCheck : PROCESS (clk, seqDone, curstate)
	BEGIN
		IF clk'EVENT AND clk = '1' AND curstate = S0 THEN
			seqDoneGet <= '0';
		END IF;	
	
		IF seqDone = '1' THEN
			seqDoneGet <= '1';
		END IF;
	END PROCESS; -- Checks for if the Data processing is done
	-----------------------------------------------------
	seq_state : PROCESS (clk, reset)
	BEGIN
		IF reset = '1' AND clk'EVENT AND clk = '1' THEN
			curState <= S0;
		ELSIF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
		END IF;
	END PROCESS; -- stateChange
	----------------------------------------------------- 
	counter : PROCESS(clk, counter_enable, counter_reset)
	BEGIN
		IF counter_reset = '1' THEN
			count <= 0;
			--counter_reset <= '0';
		ELSIF rising_edge(clk) AND counter_enable = '1' AND count < 4 THEN
			count <= count + 4;
		END IF;
	END PROCESS; -- counter
	----------------------------------------------------- 
	byte_test: process(byte, count)
	BEGIN
	  IF byte((7-count) downto (4-count)) < "1010" AND count < 8 THEN
	    BYTENEW <= "0011" & byte((7-count) downto (4-count));
	    
	  ELSIF byte((7-count) downto (4-count)) > "1001" AND count < 8 THEN
	    BYTENEW <= std_logic_vector(unsigned(  std_logic_vector'("0011"&byte((7-count) downto (4-count))))  + ("00000111"));
	    
	  END IF;   
	END PROCESS; -- converting byte to hex 
	
	END; -- processData



