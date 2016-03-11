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
	signal cmdNow : std_logic := '0';
	signal cmdDone : std_logic := '0';
	signal cmdRecieve : std_logic := '0';
begin
  RM : entity work.cmdParse(parseCommands) port map (
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
		      numWords_bcd	=> numWords_bcd,
		      dataReady	=> dataReady,
		      byte	=> byte,
		      maxIndex	=> maxIndex,
		      dataResults	=> dataResults,
		      seqDone	=> seqDone          
        );
  JC : entity work.dataProc(processData) port map (      
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
		      numWords_bcd	=> numWords_bcd,
		      dataReady	=> dataReady,
		      byte	=> byte,
		      maxIndex	=> maxIndex,
		      dataResults	=> dataResults,
		      seqDone	=> seqDone   
        );

end;
