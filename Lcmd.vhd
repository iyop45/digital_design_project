--- author: joshua coop
---
--- processing the data processors data for P and L commands
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

use work.common_pack.all;

entity Lcmd is
	port (
		clk:		in std_logic;
		reset:		in std_logic;
		
		txData:			out std_logic_vector (7 downto 0);
		txnow:		out std_logic;
		txdone:		in std_logic;
		
		dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);

	  lNow : in std_logic;
	  lRecieve : out std_logic;
	  
		prntNow: out std_logic;
		prntSpace: out std_logic
	   
	);
end Lcmd;

architecture Lcommand of Lcmd is
  type state_type is (S0, S1, S2, S3, S4, S5, S6, S7);
  signal curState, nextState: state_type;
	signal counter_enable : std_logic := '0';
	signal counter_reset : std_logic := '0';
	signal count : integer := 0;
begin
  
  combi_nextState: process(clk, curState)
  begin
    case curState is
      --- handshake to the module to ensure tha the rxdata has recieved an L or 1
      when  S0 => 
        counter_reset <= '1'; 
        TxNow <= '0';     
        if lNow = '1' then 
          nextstate <= S1;
        else
          nextstate <= S0;
        end if;
       
      --- handshake back to the cmdparce to say that we know that an L or 1 has been recieved        
      when S1 =>
        counter_reset <= '0'; 
        lRecieve <= '1';
        if lNow = '0' then 
          nextstate <= S2;
        else
          nextstate <= S1;
        end if;
       
      --- sends the data results values in order, from count = 0 to 7       
      when S2 =>
        counter_enable <= '0';
        TxData <= dataResults(count);
        TxNow <= '1';
        lRecieve <= '0';
        if TxDone = '1' then
          nextstate <= S3;
        else
          nextstate <= S2;
        end if;
              
      when S3 =>
        TxNow <= '0';
        nextstate <= S4;
        
      --- sends a space to the output and then tests to see if all the dataresults have been sent       
      when S4 =>
        TxData <= x"50"; -- space at the output
        TxNow <= '1';
        if TxDone = '1' then
          if Count = 6 then
            nextstate <= S0;
          else
            nextstate <= S5;
          end if;
        else
          nextstate <= S4;
        end if;
        
      when S5 =>
        Counter_enable <= '1';
        TxNow <= '0';
        nextstate <= S4;

      when others =>
        nextstate <= S0;
    end case;
    
end process;
---------------------------------------------------- 
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
stateChange: process (clk, reset)
begin
  if reset = '1' AND clk'event AND clk='1' then
    curState <= S0;
  elsif clk'event AND clk='1' then
    curState <= nextState;
  end if;
end process; --stateChange
-----------------------------------------------------
end;
