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
		
		txData:			out std_logic_vector (7 downto 0);
		txnow:		out std_logic;
		txdone:		in std_logic;
		
		start: out std_logic;
		dataReady: in std_logic;
		byte: in std_logic_vector(7 downto 0);
		
		cmdNow: in std_logic;     
		cmdDone: out std_logic; 
		cmdRecieve: out std_logic
	);
end dataProc;

architecture processData of dataProc is
  type state_type is (S0, S1, S2, S3);
  signal curState, nextState: state_type;
begin

	combi_nextState: process(txdone, dataready, byte)
	begin
		case curState is
			when  S0 =>
				cmddone <= '0';
				txnow <= '0';       
				if txdone = '1' AND cmdNow = '1' then --- roys part telling me that he's recieved an annn and i should start processing
					nextstate <= S1;
				else
					nextstate <= S0;
				end if;
				
			when S1 =>
				cmdRecieve <= '1'; --- variable to tell roy i have started processing
				start <= '1';
				nextstate <= S2;
				
			when S2 =>
				start <= '0';
				if dataready = '1' then
					nextstate <= S3;
				else
					nextstate <= S0;        
				end if;
				
			when S3 =>
				cmdRecieve <= '0';
				cmdDone <= '1';
				txnow <= '1';
				txData <= byte;
				nextstate <= S0;
			
			
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


