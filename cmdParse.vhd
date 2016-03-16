---
--- author: roy miles
--- processing the commands send from Rx
---

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
--use ieee.numeric_std_unsigned.all; -- need for charN debugging

use ieee.numeric_std.all; -- additional debug

use work.common_pack.all;

entity cmdParse is
	port (
		clk:		in std_logic;
		reset:		in std_logic;
		
		rxnow:		in std_logic; -- valid port
		rxData:			in std_logic_vector (7 downto 0);
		rxdone:		out std_logic;
		
		stxData:			out std_logic_vector (7 downto 0);
		stxnow:		out std_logic;
		stxdone:		in std_logic;
		numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
		
		cmdNow: out std_logic;     
		cmdRecieve: in std_logic;
		
		lNow: out std_logic;
		lRecieve: in std_logic;
	
		pNow: out std_logic;
		pRecieve: in std_logic;
		
		seqDone: in std_logic
	);
end cmdParse;

architecture parseCommands of cmdParse is
  -- Specification Part 1:
  -- 1. Parse/Detect a 4 character string with ANNN or aNNN pattern
  --    NNN is a 3 digit sequence 000-999
  --    Baude-rate = 9600 
  --    \n\r terminating characters
  
  -- Part 2:
  -- 1. The value NNN means NNN bytes need to be processed
  --    NNN must be an integer / number
  --    No interruption while processing the NNN bytes
  --    Each byte printing in hexadecimal format
  
	type state_type is (INIT, FIRST, SECOND, AStart, AFinish, LShake, PShake); 	
	signal curState, nextState : state_type;
	signal counter_enable : std_logic := '0';
	signal counter_reset : std_logic := '0';
	signal count : integer := 0;
	signal hasProcessedACommand : std_logic := '0';
begin
  
  combi_nextState: process(clk, curState)
    -- char variables are used for debugging
	  -- variable char1, char2, char3, char4 : integer := 0;
  begin
    --txnowsignal <= '0';
    case curState is
      when INIT =>
        counter_reset <= '0';

        --stxNow <= '0';
        --stxData <= "00000000";
        
        if rxnow = '1' then
	       case rxData is
	         
		        when "01100001"|"01000001" => -- a or A
					     --char1 := to_integer(rxData);
					     
					     stxNow <= '1';
					     stxData <= rxData;
					     
					     nextState <= FIRST;
					     
					  -- Print 3 bytes preceeding the peak byte
		        when "01101100"|"01001100" => -- l or L
					     -- These commands should not result in any action if a data sequence has not been processed prior to receiving them.
					     if seqDone = '1' AND hasProcessedACommand = '1' then
					       lNow <= '1';
					       
					       stxNow <= '1';
					       stxData <= rxData;					       
					       
					       nextState <= LShake;
					     else 
					       nextState <= INIT;  
					     end if;
					     
					  -- Print peak byte
		        when "01110000"|"01010000" => -- p or P  
					     -- These commands should not result in any action if a data sequence has not been processed prior to receiving them.
					     if seqDone = '1' AND hasProcessedACommand = '1' then
					       pNow <= '1';
					       
					       stxNow <= '1';
					       stxData <= rxData;									       
					       
					       nextState <= PShake;
					     else 
					       nextState <= INIT;  
					     end if;
					     
		        when others =>
					     nextState <= INIT;
					     
	       end case;
        else
			     -- Keep waiting until rxnow is 1 (data is ready to read)
			     rxdone <= '0';
			     nextState <= INIT;
        end if;
	       
	    when FIRST =>
	      -- Recieved a character
	      -- Wait for rxnow to become 0
	      counter_enable <= '0';

	      stxData <= rxData;
	      stxNow <= '0';
	      
	      if rxnow = '0' AND stxDone = '1' then
			     rxdone <= '0';
			     nextState <= SECOND;
	      else
			     rxdone <= '1';
			     nextState <= FIRST;
	      end if;
	      
	      
	       
      when SECOND =>
        if count = 3 then
			     -- Nothing yet
			     cmdNow <= '1';
			     nextState <= AStart;        
        else
          if rxnow = '1' then -- If data is ready to read
            -- Every keystroke needs to be printed
            --txnow <= '1';
            --txData <= rxData;
            
            if rxData(7 downto 4) = "0011" AND (rxData(3 downto 0) > "0000" OR rxData(3 downto 0) < "1001") then -- Check if byte is a valid ascii integer
              -- The 3 NNN digits
              case count is
                when 0 =>
					         numWords_bcd(0) <= rxData(3 downto 0);
					         --char2 := to_integer(rxData);
                when 1 =>
					         numWords_bcd(1) <= rxData(3 downto 0);
					         --char3 := to_integer(rxData);
                when 2 =>
					         numWords_bcd(2) <= rxData(3 downto 0);
					         --char4 := to_integer(rxData);
                when others =>
                  null;
              end case;

				      counter_enable <= '1';
				      --prntNow <= '1';
				      nextState <= FIRST;
            else
				      -- Not an integer
				      nextState <= FIRST;
            end if;
          else
			       nextState <= SECOND;
          end if; 
        end if;
        
      -- Initial 3-way handshaking protocol for the dataProc module 
      when AStart =>
        -- Processing part has been notified of the command
        if cmdRecieve = '1' then
			     cmdNow <= '0';
			     nextState <= AFinish;
        else 
			     cmdNow <= '1';
			     nextState <= AStart;
        end if;
      
      -- Final handshaking acknologement for the dataProc module 
      when AFinish =>
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
			  --   nextState <= AFinish;  
        --end if;
        
      -- Initial 3-way handshaking protocol for the L module  
      when LShake =>
        if lRecieve = '1' AND stxDone = '1' then
			     lNow <= '0';
			     nextState <= INIT;
        else 
			     lNow <= '1';
			     nextState <= LShake;
        end if;
        
      -- Initial 3-way handshaking protocol for the P module    
      when PShake =>  
        if pRecieve = '1' AND stxDone = '1' then
			     pNow <= '0';
			     nextState <= INIT;
        else 
			     pNow <= '1';
			     nextState <= PShake;
        end if;   
        
   			when others =>
			  nextstate <= INIT;
      
    end case;
  end process; -- combi_nextState  
  
  --txNow <= txnowsignal;   
  -----------------------------------------------------
  -- Integer counter, primarily used for counting 3Ns in ANNN command
  counter: process(clk, counter_enable, counter_reset)
  begin
    if counter_reset = '1' then
		  count <= 0;
		  --counter_reset <= '0';
    elsif rising_edge(clk) AND counter_enable = '1' then
		  count <= count + 1;
    end if;
  end process; -- counter
  -----------------------------------------------------
  -- Change state on every rising clock edge
  seq_state: process(clk, reset)
  begin
    if reset = '1' AND clk'event AND clk='1' then
		  curState <= INIT;
    elsif clk'event AND clk='1' then
		  curState <= nextState;
    end if;
  end process; -- seq
end; -- parseCommands