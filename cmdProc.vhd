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
	signal aRecieve : std_logic := '0';

	signal lNow : std_logic := '0';
	signal lDone : std_logic := '0';
	signal lRecieve : std_logic := '0';
	
	signal pNow : std_logic := '0';
	signal pDone : std_logic := '0';
	signal pRecieve : std_logic := '0';	
	
	signal stxDone : std_logic;	
	
	signal stxNow_cmdParse : std_logic := '0';
	signal stxData_cmdParse : std_logic_vector (7 downto 0) := "00011000";

	signal stxNow_dataProc : std_logic := '0';
	signal stxData_dataProc : std_logic_vector (7 downto 0) := "00011000";

	signal stxNow_Lcmd : std_logic := '0';
	signal stxData_Lcmd : std_logic_vector (7 downto 0) := "00011000";

	signal stxNow_Pcmd : std_logic := '0';
	signal stxData_Pcmd : std_logic_vector (7 downto 0) := "00011000";
	
	signal dataProc_TxHold : std_logic;
	signal Lcmd_TxHold : std_logic;
	signal Pcmd_TxHold : std_logic;
	
	--variable ascii_reg : CHAR_ARRAY_TYPE(7 downto 0); -- Max queue size of 8 ascii characters
	signal printNow, printSpace : std_logic := '0';
begin
  -- entity for parsing and processing commands
  cmd_parse : entity work.cmdParse(parseCommands) port map (
		      clk	=> clk,
		      reset	=> reset,
		      
		      rxnow	=> rxnow,
		      rxData	=> rxData,
		      rxdone	=> rxdone,
		      
		      stxData	=> stxData_cmdParse,
		      stxnow	=> stxnow_cmdParse,
		      stxdone	=> stxdone,
		      numWords_bcd	=> numWords_bcd,
		      
		      cmdNow => aNow,     
		      cmdRecieve => aRecieve,
		      
		      lNow => lNow,
		      lRecieve => lRecieve,

		      pNow => pNow,
		      pRecieve => pRecieve,
		      
		      seqDone => seqDone
        );
--  queue_print : entity work.printQueue(queuePrint) port map (
--		      clk	=> clk,
--		      reset	=> reset,		
--		      
--		      stxData	=> stxData,
--		      stxnow	=> stxNow,
--		      stxdone	=> stxDone,
--		         
--		      printNow => printNow,
--		      printSpace => printSpace   
--    
--        );

  data_process : entity work.dataProc(processData) port map (      
		      clk	=> clk,
		      reset	=> reset,

		      stxData	=> stxData_dataProc,
		      stxnow	=> stxnow_dataProc,
		      stxdone	=> stxdone,
		      
		      start	=> start,
		      dataReady	=> dataReady,
		      byte	=> byte,
		      seqDone => seqDone,
		      
		      cmdNow => aNow,
		      cmdRecieve => aRecieve,
		      
		      txHold => dataProc_TxHold
        );
        
  l_cmd : entity work.Lcmd(Lcommand) port map (      
		      clk	=> clk,
		      reset	=> reset,

		      stxData	=> stxData_Lcmd,
		      stxnow	=> stxnow_Lcmd,
		      stxdone	=> stxdone,
		      
		      dataResults	=> dataResults,
		         
		      lNow => lNow, 
		      lRecieve => lRecieve,
		      
		      txHold => Lcmd_TxHold
        );    
            
  ----------------------------------------------------- 
  tx_print: process(clk)
  begin
    if clk'event AND clk='1' then
      
      -- set Tx inputs to value of internal signal
      if dataProc_TxHold = '1' then
        txNow <= stxNow_dataProc;
        txData <= stxData_dataProc;
      elsif Lcmd_TxHold = '1' then
        txNow <= stxNow_Lcmd;
        txData <= stxData_Lcmd;
      elsif Pcmd_TxHold = '1' then
        txNow <= stxNow_Pcmd;
        txData <= stxData_Pcmd;
      else
        txNow <= stxNow_cmdParse;
        txData <= stxData_cmdParse;   
      end if;  
        
           
      -- set signal to value of Tx outputs
      stxDone <= txDone;
    end if;
    
  end process;
  
end;
