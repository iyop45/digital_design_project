---
--- author: roy miles
--- top level entity wrapping the sub components
---

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

architecture behaviour of cmdProc is
	signal now : std_logic := '0';
	signal done : std_logic := '0';
	signal recieve : std_logic := '0';
begin
  CP : entity work.cmdParse(parseCommands) port map (
		      clk	=> clk,
		      reset	=> reset,
		      
		      rxnow	=> rxnow,
		      rxData	=> rxData,
		      rxdone	=> rxdone,
		      
		      txData	=> txData,
		      txnow	=> txnow,
		      txdone	=> txdone,
		      numWords_bcd	=> numWords_bcd,
		      
		      cmdNow => now,     
		      cmdDone => done, 
		      cmdRecieve => recieve      
        );
  DP : entity work.dataProc(processData) port map (      
		      clk	=> clk,
		      reset	=> reset,

		      txData	=> txData,
		      txnow	=> txnow,
		      txdone	=> txdone,
		      
		      start	=> start,
		      dataReady	=> dataReady,
		      byte	=> byte,
		      
		      cmdNow => now,     
		      cmdDone => done, 
		      cmdRecieve => recieve  
        );

end;
