library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
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
  
  type state_type is (S0, S1, S2, S3, S4);
  signal curState, nextState: state_type;
  signal peakvalue : std_logic_vector(7 downto 0) := "00000000";
  signal ctrlOut_reg, equal, peakValueSmaller, shift_enable, store_enable, count_enable, count_reset, start_enable : std_logic:='0';  --bit := '0';
  signal ctrlIn_delayed, ctrlIn_detected: std_logic;
  signal allData: CHAR_ARRAY_TYPE(0 to 998);  
  signal index, indexpk, start_index: integer:=0;
  signal counter1, counter2, counter3: std_logic_vector(3 downto 0) := "0000";
  signal debug: std_logic:= '0';
  signal counterOut, numWords, indexPk_bcd: std_logic_vector(11 downto 0);
  
  
  --curState - Current State.
  --nextState - next State.
  --peakvalue - Current Peak Value.
  --ctrlOut_reg - Holds the value of the ctrlOut in a register one clock cycle behind ctrlOut.
  --equal - Goes high when the current peak value and the most recent value from the data genator ire the same.
  --peakValueSmaller - Goes high when the peak value is smaller then the small value.
  --shift_enable - Goes high to enable the shifter.
  --store_enable - Goes high to enable the final values to be stored in the dataResults Array.
  --count_enable - Goes high to enable the counter.
  --count_reset - A reset for the counter. 
  --start_enable - Goes high when a start signal has been sent.
  --ctrlIn_delayed - Holds the value of the ctrlIn by one delayed clock cycle.
  --ctrlIn_detected - Goes high when the value of CtrlIn and ctrlIn_delayed are different.
  --allData - Stores all of the vlaues that have been recieved from the data generator in an index.
  --indexpk - Hold the value of the peak value by index.
  --index - Counts how many values have been recieved from the data generator.
  --start_index - Records how many start signals have been recieved so that the corresponding byte can be sent to the command processor.
  --numWords - Stores the number of words that need to be processed by the data generator.
  

begin
------------------------------------------------------
  combi_nextState: process(clk, curState) --start_enable, index, ctrlIn_detected, peakValueSmaller)
  begin
    
    case curState is
       
       --Reset state
       when S0 =>
       --Checks to see if a start command has been recieved from the command processor.
        if start_enable='1' then
          --Resets the counter, peak index and various enable signals.
          --start_index <= 0;
          ctrlOut_reg <= '0';
          indexpk <= 0;
          count_reset <= '0';
          shift_enable <= '0';
          store_enable <= '0';
          debug <= '1';
          seqDone <= '0';
          nextState <= S1;
        else null; 
        end if;
       
       --Checks to see if all of the data has been processed by the data generator.     
       when S1 => 
          debug <= '1';
         --If all of the data has been processed, the final data is passed to the command processor and the seqdone signal is asserted.
        if counterOut = numWords then
          seqDone <= '1';
          store_enable <= '1';
          maxIndex(2) <= indexPk_bcd(11 downto 8);
          maxIndex(1) <= indexPk_bcd(7 downto 4);
          maxIndex(0) <= indexPk_bcd(3 downto 0);
          nextState <= S0; 
         --If data generation has not finished, then the handshaking protocol starts.
        else
          ctrlOut_reg <= not ctrlOut_reg;
          nextState <= S2;
        end if; 
       
       
       --Waits for the data generator to send back a signal before allowing the new data byte to be shifted as well as incrementing the counter.
       when S2 => 
        if ctrlIn_detected = '1' then   
          shift_enable <= '1';  
          count_enable  <= '1';  
          nextState <= S3; 
        else
          nextState <= S2;
        end if;
       
       
       --Adjusts the peak value if required.
       when S3 =>
        shift_enable <= '0';
        count_enable  <= '0'; 
        --Checks to see if new value from the data generator is greater then the current peak value and if true then changes the peak value and it's index.
        if peakValueSmaller = '1' then
          peakValue <= allData(index-1);
          indexPk <= index-1;
          indexPk_bcd <= counterOut;
        elsif debug = '1' then
          peakValue <= allData(0);
          indexPk <= 0;
          debug <= '0';
        end if;
        nextState <= S4;
      
       --Checks to see if a start signal has been put high and if true sends the next byte in sequence to the command processor. 
       when S4 =>
        if start_enable ='1' then
          dataready <= '1';
          if index/= 0 then
            byte <= allData(start_index-1);
          else byte <= allData(0);
          end if;   
        else null;
        end if;
        nextState <= S1;
                 
      end case;
  end process; 

  counterOut <= counter3 & counter2 & counter1;
  numWords <= numWords_bcd(2)&numWords_bcd(1)&numWords_bcd(0);
------------------------------------------------------  
  --Checks to see if a start signal has been sent from the command processor during data generation.
  start_proc : process (clk, start)
  begin
    if rising_edge(clk) and start = '1' then
      start_enable <= '1';
    else null;
    end if;
  end process;
  
---------------------------------------------------  
  DataStore : process (clk, shift_enable, data)
  begin
      if rising_edge(clk) and shift_enable='1' then 
        allData(index) <= data;
      end if;
  end process;    
  
------------------------------------------------------
  --After data generation, the peak value and values three above and below are put into dataresults.
  stored_result : process (clk, store_enable)
  begin
    if rising_edge(clk) and store_enable = '1' then
        dataResults(0) <= allData(indexpk - 3);
        dataResults(1) <= allData(indexpk - 2);
        dataResults(2) <= allData(indexpk - 1);
        dataResults(3) <= allData(indexpk);
        dataResults(4) <= allData(indexpk + 1);
        dataResults(5) <= allData(indexpk + 2);
        dataResults(6) <= allData(indexpk + 3);
    else null;
    end if;
  end process;   
        
------------------------------------------------------  
--  --Counts the index value for the number of words that have been processed.
--  counter : process (clk, count_enable, count_reset)
--  begin
--      if count_reset = '1' then
--        index <= 0;
--      elsif rising_edge(clk) and count_enable='1' then 
--       -- if debug = '1' then
--         index <= index + 1;
--         start_index <= start_index+1; 
--        --else debug <= '1';
--        
--      end if;
--  end process; 
  
------------------------------------------------------  
--Thanks Josh
  counter: process (clk, count_enable, count_reset)
  begin
    if count_reset = '1' then
        
        index <= 0;
        counter3 <= "0000";
        counter2 <= "0000";
        counter1 <= "0000";
        
    elsif rising_edge(clk) and count_enable='1' then
        index <= index + 1;
        start_index <= start_index+1;
        counter1 <= std_logic_vector(unsigned(counter1) + "0001");
        if counter1 = "1001" then
           counter2 <= std_logic_vector(unsigned(counter2) + "0001");
           counter1 <= "0000";
           if counter2 = "1001" then
              counter3 <= std_logic_vector(unsigned(counter3) + "0001");
              counter2 <= "0000";
              if counter3 = "1001" then
                 counter3 <= "0000";
              end if;
            end if;
        end if;
     end if;
  end process;

------------------------------------------------------
  --Compares the new value with the current peak value and see which is greater.
  comparator: process(clk, peakValue, allData, index)
  begin
      if index /= 0 then 
        debug <= '0';
        if peakValue = allData(index-1) then
          equal <= '1';
          peakValueSmaller <= '0';
        elsif peakValue > allData(index-1) then 
          equal <= '0';
          peakValueSmaller <= '0';  
        elsif peakValue < allData(index-1) then
          equal <= '0';
          peakValueSmaller <= '1';  
        end if;
      else debug <= '1'; 
      end if;
 end process; 
  
------------------------------------------------------
  --Goes back to the first state when reset, else chnages state on a rising clock edge. 
  seq_state: process (clk, reset)
  begin
    if reset = '1' then
      curState <= S0;
    elsif clk'event AND clk='1' then
      curState <= nextState;
      ctrlOut <= ctrlOut_reg;
    end if;
  end process;
  
------------------------------------------------------
  --Hand shaking protocool for the communication with the data generator.
  delay_CtrlIn: process(clk)     
  begin
    if rising_edge(clk) then
      ctrlIn_delayed <= ctrlIn;
    end if;
  end process;
  
  ctrlIn_detected <= ctrlIn xor ctrlIn_delayed;
------------------------------------------------------
 -- newValue <= allData(index);
------------------------------------------------------
end; --detectorArch

