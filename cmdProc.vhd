---
--- author: roy miles
--- top level entity wrapping the sub components
---

library ieee;
use ieee.std_logic_1164.all;
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

architecture behaviour of cmdProc is
  -- Signals between sub components
	signal aNow : std_logic := '0';
	signal aDone : std_logic := '0';
	signal aRecieve : std_logic := '0';

	signal lNow : std_logic := '0';
	signal lDone : std_logic := '0';
	signal lRecieve : std_logic := '0';
	
	signal pNow : std_logic := '0';
	signal pDone : std_logic := '0';
	signal pRecieve : std_logic := '0';	
	
	type state_type is (INIT, WAITING, SPACE);
	signal curState, nextState : state_type;
	signal prntNow : std_logic := '0';
	signal prntSpace : std_logic := '0';
	--variable ascii_reg : CHAR_ARRAY_TYPE(7 downto 0); -- Max queue size of 8 ascii characters
begin
  -- entity for parsing and processing commands
  cmd_parse : entity work.cmdParse(parseCommands) port map (
		      clk	=> clk,
		      reset	=> reset,
		      
		      rxnow	=> rxnow,
		      rxData	=> rxData,
		      rxdone	=> rxdone,
		      
		      txData	=> txData,
		      txnow	=> txnow,
		      txdone	=> txdone,
		      numWords_bcd	=> numWords_bcd,
		      
		      cmdNow => aNow,     
		      cmdDone => aDone, 
		      cmdRecieve => aRecieve,
		      
		      lNow => lNow,
		      lRecieve => lRecieve,

		      pNow => pNow,
		      pRecieve => pRecieve,
		      
		      seqDone => seqDone,
		      
		      prntNow => prntNow,
		      prntSpace => prntSpace
        );
  data_process : entity work.dataProc(processData) port map (      
		      clk	=> clk,
		      reset	=> reset,

		      txData	=> txData,
		      txnow	=> txnow,
		      txdone	=> txdone,
		      
		      start	=> start,
		      dataReady	=> dataReady,
		      byte	=> byte,
		      
		      cmdNow => aNow,     
		      cmdDone => aDone, 
		      cmdRecieve => aRecieve,
		      
		      prntNow => prntNow,
		      prntSpace => prntSpace
        );
        
  l_cmd : entity work.Lcmd(Lcommand) port map (      
		      clk	=> clk,
		      reset	=> reset,

		      txData	=> txData,
		      txnow	=> txnow,
		      txdone	=> txdone,
		      
		      dataResults	=> dataResults,
		         
		      lNow => lNow, 
		      lRecieve => lRecieve,
		      
		      prntNow => prntNow,
		      prntSpace => prntSpace    
        );        

  -----------------------------------------------------
  -- Interface to the Tx module for printing ascii characters
  queue_print: process(clk, curState)
    type state_type is (INIT, WAITING, SPACE); 
    --variable ascii_reg : CHAR_ARRAY_TYPE(7 downto 0); -- Max queue size of 8 ascii characters
  begin
    case curState is
      
      when INIT =>
        if prntNow = '1' then
          txNow <= '1';
          nextState <= WAITING;
        else
          nextState <= INIT;
        end if;
        
      when WAITING =>
        txNow <= '0';
        -- Wait until tx is ready for another byte
        if txDone <= '1' then
          -- This character is at the end of the line and so a new line character needs to be appended to the printed output
          if prntSpace <= '1' then
            nextState <= SPACE;
          else
            nextState <= INIT;  
          end if;
        else
          nextState <= WAITING;
        end if;
        
      when SPACE =>
        -- Append the ascii space to the printing buffer
        txData <= x"50"; -- Space
        txNow <= '1';
        prntSpace <= '0';
        nextState <= WAITING;
        
    end case;   
    
  end process; -- queue_print
  -----------------------------------------------------
  -- Change state on every rising clock edge
  seq_state: process(clk)
  begin
    if reset = '1' AND clk'event AND clk='1' then
		  curState <= INIT;
    elsif clk'event AND clk='1' then
		  curState <= nextState;
    end if;
  end process; -- seq
  ----------------------------------------------------- 

end;
