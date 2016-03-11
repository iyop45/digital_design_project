library ieee;
use ieee.std_logic_1164.all;
use work.common_pack.all;

entity dataConsume is
  	port (
	  clk:		in std_logic;
		reset:		in std_logic; -- synchronous reset
		start: in std_logic; -- goes high to signal data transfer
		numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
		ctrlIn: in std_logic;
		ctrlOut: out std_logic;
		data: in std_logic_vector(7 downto 0);
		dataReady: out std_logic;
		byte: out std_logic_vector(7 downto 0);
		seqDone: out std_logic;
		maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
		dataResults: out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) -- index 3 holds the peak
  	);
end dataConsume;

architecture detectorArch of dataConsume is
  
  type state_type is (S0, S1, S2, S3);
  signal curState, nextState: state_type;
  signal peakvalue, newValue: std_logic_vector(7 downto 0) := "00000000";
  signal equal, peakValueSmaller, shift_enable, store_enable, count_enable, loop_enable, count_reset : bit := '0';
  signal ctrlIn_delayed, ctrlIn_detected: std_logic;
  signal ctrlOut_reg: std_logic :='0';
  signal finalResults: CHAR_ARRAY_TYPE(0 to 6);
  signal allData: CHAR_ARRAY_TYPE(0 to 999);  
  signal indexpk, index: integer;
  

begin
------------------------------------------------------
  combi_nextState: process(clk, curState, ctrlIn_detected)
  begin
    
    case curState is
      when S0 => --reset state
        ctrlOut_reg <= '0';
        indexpk <= 0;
        count_reset <= '0';
        shift_enable <= '1';
        nextState <= S1; 
          

      when S1 =>
        shift_enable <= '0';
        peakValue <= newValue;
        loop_enable <='0'; 
        store_enable <= '0';
        ctrlOut_reg <= not ctrlOut_reg;
        nextState <= S2;
       
      when S2 => 
        if ctrlIn_detected = '1' then   
          shift_enable <= '1';  
          count_enable  <= '1';  
          nextState <= S3; 
        else
          nextState <= S2;
        end if;
      
      when S3 =>
        shift_enable <= '0';
        count_enable  <= '0'; 
        if peakValueSmaller='1' then
          peakValue <= newValue;
          indexPk <= index;
          loop_enable <='1';
          nextState <= S1;
        elsif peakValueSmaller='0' and equal='0' then
          store_enable <= '1';
          nextState <= S1;
        end if;
           
        
        
      end case;
  end process; -- combi_nextState
  
------------------------------------------------------

  store : process(clk, store_enable)
  begin
    if rising_edge(clk) and store_enable='1' then 
       if indexpk = index-1 then
          finalResults(4) <= newValue;
        elsif indexpk = index-2 then
          finalResults(5) <= newValue;
        elsif indexpk = index-3 then
          finalResults(6) <= newValue; 
        end if;
     else null;
      end if;
  end process;       

------------------------------------------------------
  
  looper : process (clk, loop_enable)
  begin
    if rising_edge(clk) and loop_enable='1' then 
          for i in 0 to 2 loop
            finalResults(3-i) <= allData(indexpk-i);
          end loop; 
      else null;
      end if;
  end process;     

------------------------------------------------------  
 
  counter : process (clk, count_enable, count_reset)
  begin
      if count_reset = '1' then
        index <= 0;
      elsif rising_edge(clk) and count_enable='1' then 
        index <= index + 1;
      end if;
  end process; 

------------------------------------------------------
  
  shifting : process (clk, shift_enable, data)
  begin
      if rising_edge(clk) and shift_enable='1' then 
        for i in 999 downto 1 loop 
            allData(i) <= allData(i-1); 
        end loop;
        allData(0) <= data; 
      else null;
      end if;
  end process;    
 

------------------------------------------------------
  comparator: process(clk, peakValue, newValue)
  begin
    if peakValue = newValue then
      equal <= '1';
      peakValueSmaller <= '0';
    elsif peakValue > newValue then 
      equal <= '0';
      peakValueSmaller <= '0';  
    elsif peakValue < newValue then
      equal <= '0';
      peakValueSmaller <= '1';  
    end if;
   end process; --comparator 
  
------------------------------------------------------
  seq_state: process (clk, reset)
  begin
    if reset = '1' then
      curState <= S0;
      
    elsif clk'event AND clk='1' then
      curState <= nextState;
      ctrlOut <= ctrlOut_reg;
    end if;
  end process; -- seq
------------------------------------------------------
  delay_CtrlIn: process(clk)     
  begin
    if rising_edge(clk) then
      ctrlIn_delayed <= ctrlIn;
    end if;
  end process;
  
  ctrlIn_detected <= ctrlIn xor ctrlIn_delayed;
------------------------------------------------------
  newValue <= allData(0);
------------------------------------------------------
end; --detectorArch
