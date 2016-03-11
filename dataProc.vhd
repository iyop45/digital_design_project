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
		rxnow:		in std_logic; -- valid port
		rxData:			in std_logic_vector (7 downto 0);
		txData:			out std_logic_vector (7 downto 0);
		rxdone:		out std_logic;
		ovErr:		in std_logic;
		framErr:	in std_logic;
		txnow:		out std_logic;
		txdone:		in std_logic;
		start: out std_logic;
		--numWords: out std_logic_vector(9 downto 0);
		numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
		dataReady: in std_logic;
		byte: in std_logic_vector(7 downto 0);
		maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
		--dataResults: in std_logic_vector(55 downto 0);
		dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
		seqDone: in std_logic
	);
end dataProc;

architecture processData of dataProc is
  type state_type is (S0, S1, S2, S3);
  signal curState, nextState: state_type;
  signal cmdNow : std_logic;
  signal cmdDone : std_logic;
  signal cmdRecieve : std_logic;
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

