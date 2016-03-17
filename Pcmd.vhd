
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
		
		stxData:			out std_logic_vector (7 downto 0);
		stxNow:		out std_logic;
		stxDone:		in std_logic;
		
		maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
		dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
	  --inter module signals
	  PRecieve : in std_logic;   --- goes high when an P or p command has beebn typed into the terminal
	  PNow : out std_logic;     --- send back to tell cmdparse that data is not being processed by this module
		TxHold: out std_logic      --- goes high when printing to the Tx module and goes low when it stops
	   
	);
end Pcmd;

  architecture Pcommand of Pcmd is
  type state_type is ( S0, S1, S2, S3, S4, S5, S6, S7);
  signal curState, nextState: state_type;
	signal counter_enable : std_logic := '0';
	signal counter_reset : std_logic := '0';
	signal count : integer := 0;

begin
  dataSend: process(stxDone, PRecieve, count, maxIndex, dataResults, curState)
  begin

    case curState is  
--- handshake to the module to ensure tha the rxdata has recieved an P or p
     when  S0 => 
     counter_reset <= '1'; 
     stxNow <= '0';     
       if PRecieve = '1' then 
         nextstate <= S1;
       else
         nextstate <= S0;
       end if;
       
--- handshake back to the cmdparce to say that we know that an P or p has been recieved        
      when S1 =>
          PNow <= '1';
          if PRecieve = '0' then 
            nextstate <= S2;
          else
            nextstate <= S1;
          end if;
       
--- sends the peak byte to the tx module      
      when S2 =>
          stxData <= dataResults(3);
          stxNow <= '1';
          PNow <= '0';
          nextstate <= S3;
        
---  sets txNow = 0 so that it has only been high for a single clock cycle, as per specification     
      when S3 =>
          stxNow <= '0';
          if stxDone = '1' then
            nextstate <= S4;
          else
            nextstate <= S3;
          end if;

        
--- sends a space to the output     
      when S4 =>
          stxData <= x"50"; -- space at the output
          stxNow <= '1';
          nextstate <= S5;
             
      when S5 =>
          stxNow <= '0';
          if stxDone = '1' then -- checks to see when Tx is ready to send the next byte
            nextstate <= S6;
          else
            nextstate <= S5;
          end if;
        
      when S6 =>
          stxData <= "0011"& maxIndex(2-count);--- converts the numbers on Maxindex to ascii characters
          stxNow <= '1'; 
          counter_enable <= '1'; 
          nextstate <= S7;
       
        
      when S7 =>
          counter_enable <= '0';
          stxNow <= '0';
          if stxDone = '1' then --- checks to see when the Tx module is ready to send the next byte
            if count = 3 then --- checks to see that the whole neumber on the maxindex line has been sent
--              nextstate <= S0;
            else
              nextstate <= S6;
            end if;       
          else
            nextstate <= S7;
          end if; 

        
--      when others =>
--        nextstate <= S0;
        
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
   ---------------------------------------------------- 
    stateChange: process (clk, reset)
  begin
    if reset = '1' AND clk'event AND clk='1' then
--      curState <= S0;
    elsif clk'event AND clk='1' then
    curState <= nextState;
    end if;
  end process; --clock
  -----------------------------------------------------
end;


