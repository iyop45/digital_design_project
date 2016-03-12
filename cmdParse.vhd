---
--- author: roy miles
--- processing the commands send from Rx
---

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std_unsigned.all;

use ieee.numeric_std.all; -- additional debug

use work.common_pack.all;

entity cmdParse is
	port (
		clk:		in std_logic;
		reset:		in std_logic;
		
		rxnow:		in std_logic; -- valid port
		rxData:			in std_logic_vector (7 downto 0);
		rxdone:		out std_logic;
		
		txData:			out std_logic_vector (7 downto 0);
		txnow:		out std_logic;
		txdone:		in std_logic;
		numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
		
		cmdNow: out std_logic;     
		cmdDone: in std_logic; 
		cmdRecieve: in std_logic;
		
		lNow: out std_logic;
		lRecieve: in std_logic;
		lDone: in std_logic;
	
		pNow: out std_logic;
		pRecieve: in std_logic;
		pDone: in std_logic;	
		
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
  
	type state_type is (INIT, FIRST, SECOND, AStart, AFinish, LStart, PStart, LFinish, PFinish); 	
	signal curState, nextState : state_type;
	signal counter_enable : std_logic := '0';
	signal counter_reset : std_logic := '0';
	signal count : integer := 0;
	signal hasProcessedACommand : std_logic := '0';
begin
  
  combi_nextState: process(clk, curState)
	  variable char1, char2, char3, char4 : integer := 0;
    variable data : std_logic_vector (23 downto 0);
  begin
    case curState is

      when INIT =>
        if rxnow = '1' then
	       case rxData is
		        when "01100001"|"01000001" => -- a or A
					     char1 := to_integer(rxData); 
					     nextState <= FIRST;
		        when "01101100"|"01001100" => -- l or L
					     -- Print 3 bytes preceeding the peak byte
					     if seqDone = '1' AND hasProcessedACommand = '1' then
					       lNow <= '1';
					       nextState <= LStart;
					     else 
					       nextState <= INIT;  
					     end if;
		        when "01110000"|"01010000" => -- p or P
					     -- Print peak byte
					     if seqDone = '1' AND hasProcessedACommand = '1' then
					       pNow <= '1';
					       nextState <= PStart;
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
	      if rxnow = '0' then
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
            txnow <= '1';
            txData <= rxData;
            
            if rxData(7 downto 4) = "0011" AND (rxData(3 downto 0) > "0000" OR rxData(3 downto 0) < "1001") then -- Check if byte is a valid ascii integer
              -- The 3 NNN digits
              case count is
                when 0 =>
					         data(7 downto 0) := rxData;
					         char2 := to_integer(rxData);
                when 1 =>
					         data(15 downto 8) := rxData;
					         char3 := to_integer(rxData);
                when 2 =>
					         data(23 downto 16) := rxData;
					         char4 := to_integer(rxData);
                when others =>
                  null;
              end case;

				      counter_enable <= '1';
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
        if cmdDone = '1' then
			     char1 := 0;
			     char2 := 0;
			     char3 := 0;
			     char4 := 0;
			     counter_reset <= '1';
			     hasProcessedACommand <= '1';
			     nextState <= INIT;
        else
			     nextState <= AFinish;  
        end if;
        
      -- Initial 3-way handshaking protocol for the L module  
      when LStart =>
        if lRecieve = '1' then
			     lNow <= '0';
			     nextState <= LFinish;
        else 
			     lNow <= '1';
			     nextState <= LStart;
        end if;
        
      -- Final handshaking acknologement with the L module
      when LFinish =>
        if lDone = '1' then
			     nextState <= INIT;
        else
			     nextState <= LFinish;  
        end if;
        
      -- Initial 3-way handshaking protocol for the P module    
      when PStart =>  
        if pRecieve = '1' then
			     pNow <= '0';
			     nextState <= PFinish;
        else 
			     pNow <= '1';
			     nextState <= PStart;
        end if;   
        
      -- Final handshaking acknologement with the P module  
      when PFinish =>
        if pDone = '1' then
			     nextState <= INIT;
        else
			     nextState <= PFinish;  
        end if;
        
   			when others =>
			  nextstate <= INIT;
      
    end case;
  end process; -- combi_nextState     
  ----------------------------------------------------- 
  counter: process(clk, counter_enable, counter_reset)
  begin
    if counter_reset = '1' then
		  count <= 0;
		  counter_reset <= '0';
    elsif rising_edge(clk) AND counter_enable = '1' then
		  count <= count + 1;
    end if;
  end process; -- counter
  -----------------------------------------------------
  seq_state: process(clk)
  begin
    if reset = '1' AND clk'event AND clk='1' then
		  curState <= INIT;
    elsif clk'event AND clk='1' then
		  curState <= nextState;
    end if;
  end process; -- seq
  ----------------------------------------------------- 
  
end; -- parseCommands
