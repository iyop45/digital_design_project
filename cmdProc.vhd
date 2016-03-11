library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std_unsigned.all;

use ieee.numeric_std.all; -- additional debug

use work.common_pack.all;

entity cmdProc is
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
end cmdProc;

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
  
	type state_type is (INIT, FIRST, SECOND, THIRD, FOURTH); 	
	signal curState, nextState : state_type;
	signal counter_enable : std_logic := '0';
	signal counter_reset : std_logic := '0';
	signal count : integer := 0;
	--our signals
	signal cmdNow : std_logic := '0';
	signal cmdDone : std_logic := '0';
	signal cmdRecieve : std_logic := '0';
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
					     nextState <= INIT;
					     -- dont know yet
		        when "01110000"|"01010000" => -- p or P
					     -- Print peak byte
					     nextState <= INIT;
					     -- dont know yet
		        when others =>
					     nextState <= INIT;
					     -- dont know yet
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
        if count = 4 then
			     -- Nothing yet
			     cmdNow <= '1';
			     nextState <= THIRD;        
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
        
      when THIRD =>
        -- Processing part has been notified of the command
        if cmdRecieve = '1' then
			     cmdNow <= '0';
			     nextState <= FOURTH;
        else 
			     cmdNow <= '1';
			     nextState <= THIRD;
        end if;
        
      when FOURTH =>
        -- Finished processing
        if cmdDone = '1' then
			     char1 := 0;
			     char2 := 0;
			     char3 := 0;
			     char4 := 0;
			     counter_reset <= '1';
			     nextState <= INIT;
        else
			     nextState <= FOURTH;  
        end if;
      
    end case;
  end process; -- combi_nextState     
  --------------------------- ------------------------- 
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
  
  A : entity cmdParse port map(
		clk	=> clk,
		reset	=> reset,
		rxnow	=> rxnow,
		rxData	=> rxData,
		txData	=> txData,
		rxdone	=> rxdone,
		ovErr	=> ovErr,
		framErr	=> framErr,
		txnow	=> txnow,
		txdone	=> txdone,
		start	=> start,
		--numWords: out std_logic_vector(9 downto 0);
		numWords_bcd	=> numWords_bcd,
		dataReady	=> dataReady,
		byte	=> byte,
		maxIndex	=> maxIndex,
		--dataResults: in std_logic_vector(55 downto 0);
		dataResults	=> dataResults,
		seqDone	=> seqDone
  );
  
end; -- parseCommands
  
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

architecture dataProcess of dataProc is
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
	
  B : entity dataProc port map(
		clk	=> clk,
		reset	=> reset,
		rxnow	=> rxnow,
		rxData	=> rxData,
		txData	=> txData,
		rxdone	=> rxdone,
		ovErr	=> ovErr,
		framErr	=> framErr,
		txnow	=> txnow,
		txdone	=> txdone,
		start	=> start,
		--numWords: out std_logic_vector(9 downto 0);
		numWords_bcd	=> numWords_bcd,
		dataReady	=> dataReady,
		byte	=> byte,
		maxIndex	=> maxIndex,
		--dataResults: in std_logic_vector(55 downto 0);
		dataResults	=> dataResults,
		seqDone	=> seqDone
  );	
end; -- dataProc
