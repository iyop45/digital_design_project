---
--- author: joshua coop
--- processing the data recieved from the data processor to send to the Tx module
---

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std_unsigned.all;

use ieee.numeric_std.all; -- additional debug

use work.common_pack.all;

entity dataProc is
	port (
		clk:		in std_logic;
		reset:		in std_logic;
		
		stxData:			out std_logic_vector (7 downto 0);
		stxNow:		out std_logic;
		stxDone:		in std_logic;
		
		start: out std_logic;
		dataReady: in std_logic;
		byte: in std_logic_vector(7 downto 0);
		seqDone: in std_logic;
		
		cmdNow: in std_logic;     --- goes high when a start command is typed into the terminal of the format aNNN or ANNN
		cmdRecieve: out std_logic; --- send back to tell cmdparse that data is not being processed by this module
		TxHold: out std_logic
	);
end dataProc;

architecture processData of dataProc is
  type state_type is (S0, S1, S2, S3, S4, S5, S6, S7);
  signal curState, nextState: state_type;
begin

	combi_nextState: process(clk, curState)
	begin
		case curState is
			when S0 =>
				TxHold <= '0';
        --- tells us when a new byte can be sent through the Tx module and that a start has been sent through the Rx module
				if  cmdNow = '1' then 
				  nextstate <= S1;
				else
					nextstate <= S0;
				end if;
				
      when S1 =>
    				cmdRecieve <= '1';
        if cmdNow = '0' then --- a duel handshake between cmd parse and this module
			     nextState <= S2;
        else 
			     nextState <= S1;
        end if;
				
			when S2 =>
			  TxHold <= '1';
				cmdRecieve <= '0'; 
				start <= '1';
				nextstate <= S2;
				
			when S3 => --- waits until there is a new byte of data from the data processor
			  start <= '0';
				if dataready = '1' then
					nextstate <= S4;
				else
					nextstate <= S3;        
				end if;
				
			when S4 => 
				stxData <= byte; --- gives the byte given by the data procossor to the Tx module
				stxNow <= '1'; ---issues a send command
				nextstate <= S5;

				
			when S5 => --sets stxNow to 0 and waits to issue the next send			  
			  stxNow <= '0'; 
			  if stxDone = '1' then --- waits until Tx modules ready to send again
				  nextstate <= S6;
				else
				  nextstate <= S5;
				end if;
				 
			when S6 =>-- adds a space after every character and issue a send command
			  stxData <= x"50";
			  stxNow <= '1';
			  nextstate <= S7;

			when S7 =>
			  stxNow <= '0'; 
			  if seqDone = '1' then
				   nextstate <= S0;
				else 
				   nextstate <= S2;
				end if;
			
		end case;
	end process; -- datasend
	-----------------------------------------------------
	seq_state: process (clk, reset)
	  begin
		if reset = '1' AND clk'event AND clk='1' then
		  curState <= S0;
		elsif clk'event AND clk='1' then
			curState <= nextState;
		end if;
	end process; -- stateChange
	-----------------------------------------------------  
	
end; -- processData
