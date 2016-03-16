---
--- author: roy miles
--- Interface to the Tx module for printing ascii characters
--- This is an example architecture to demonstrate modulising the code even further to allow synchronised queueing of characters to print to Tx module
---

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std_unsigned.all;

use ieee.numeric_std.all; -- additional debug

use work.common_pack.all;

entity printQueue is
	port (
		clk:		in std_logic;
		reset:		in std_logic;
		
		stxData:			out std_logic_vector (7 downto 0);
		stxnow:		out std_logic;
		stxdone:		in std_logic;
		
		printNow: in std_logic;
		printSpace: in std_logic
	);
end printQueue;

architecture queuePrint of printQueue is
  type state_type is (INIT, WAITING, SPACE);
  signal curState, nextState : state_type;
begin
  queue_print: process(clk, curState)
    --variable ascii_reg : CHAR_ARRAY_TYPE(7 downto 0); -- Max queue size of 8 ascii characters
  begin
    case curState is      
      when INIT =>
        if printNow = '1' then
          stxNow <= '1';
          nextState <= WAITING;
        else
          stxNow <= '0';
          nextState <= INIT;
        end if;
        
      when WAITING =>
        stxNow <= '0';
        -- Wait until tx is ready for another byte
        if stxDone <= '1' then
          -- This character is at the end of the line and so a new line character needs to be appended to the printed output
          if printSpace <= '1' then
            nextState <= SPACE;
          else
            nextState <= INIT;  
          end if;
        else
          nextState <= WAITING;
        end if;
        
      when SPACE =>
        -- Append the ascii space to the printing buffer
        stxData <= x"50"; -- Space
        stxNow <= '1';
        --prntSpace <= '0';
        nextState <= WAITING;
        
    end case;   
    
  end process; -- queue_print
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
  ----------------------------------------------------- 
  
end; -- queuePrint  