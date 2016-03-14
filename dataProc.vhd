---author: joshua coop
---
--- processing the data processors data for P and L commands
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

use work.common_pack.all;

entity Pcmd is
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
		maxIndex: in BCD_ARRAY_TYPE(12 downto 0);
--		dataResults: in std_logic_vector(55 downto 0);
		dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
		seqDone: in std_logic;
	  --inter module signals
	  PReceive : in std_logic;
	  PDone : out std_logic
	   
	);
end Pcmd;

  architecture Pcommand of Pcmd is
  type state_type is (S0, S1, S2, S3, S4, S5, S6, S7);
  signal curState, nextState: state_type;
	signal counter_enable : std_logic := '0';
	signal counter_reset : std_logic := '0';
	signal count : integer := 0;
	
begin
  dataSend: process(txdone, dataready, byte)
  begin
    case curState is
--- handshake to the module to ensure tha the rxdata has recieved an L or 1
     when  S0 => 
     counter_reset <= '1'; 
     TxNow <= '0';     
       if PReceive = '1' then 
         nextstate <= S1;
       else
         nextstate <= S0;
       end if;
       
--- handshake back to the cmdparce to say that we know that an L or 1 has been recieved        
      when S1 =>
     counter_reset <= '0';
       PDone <= '1';
       if PReceive = '0' then 
         nextstate <= S2;
       else
         nextstate <= S1;
       end if;
       
--- sends the data results values in order, from count = 0 to 7       
      when S2 =>
        TxData <= dataResults(3);
        TxNow <= '1';
        PDone <= '0';
        if TxDone = '1' then
          nextstate <= S3;
        else
          nextstate <= S2;
        end if;
        
---       
      when S3 =>
        TxNow <= '0';
        nextstate <= S4;
        
--- sends a space to the output and then tests to see if all the dataresults have been sent       
      when S4 =>
          TxData <= x"50"; -- space at the output
          TxNow <= '1';
          if TxDone = '1' then
            nextstate <= S5;
          else
            nextstate <= S4;
          end if;
        
---       
      when S5 =>
        TxNow <= '0';
        nextstate <= S6;
        
      when S6 =>
          TxData <= "0011"& maxIndex(count+3 to count);
          TxNow <= '1';
          if TxDone = '1' then
            if count = 2 then
              nextstate <= S0;
            else
              nextstate <= S7;
            end if;       
          else
            nextstate <= S6;
          end if;        
        
      when S7 =>
        counter_enable <= '1';
        TxNow <= '0';
        nextstate <= S6;
        
--      when others =>
--        nextstate <= S0;
        
    end case;
 end process;
   ----------------------------------------------------
   
   ---------------------------------------------------- 
    stateChange: process (clk, reset)
  begin
    if reset = '1' AND clk'event AND clk='1' then
      curState <= S0;
    elsif clk'event AND clk='1' then
    curState <= nextState;
    end if;
  end process; --clock
  -----------------------------------------------------
end;

