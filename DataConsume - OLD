LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.common_pack.ALL;

ENTITY dataConsume IS
	PORT (
		clk : IN std_logic;
		reset : IN std_logic; -- synchronous reset
		start : IN std_logic; -- goes high to signal data transfer
		numWords_bcd : IN BCD_ARRAY_TYPE(2 DOWNTO 0);
		ctrlIn : IN std_logic;
		ctrlOut : OUT std_logic;
		data : IN std_logic_vector(7 DOWNTO 0);
		dataReady : OUT std_logic;
		byte : OUT std_logic_vector(7 DOWNTO 0);
		seqDone : OUT std_logic;
		maxIndex : OUT BCD_ARRAY_TYPE(2 DOWNTO 0);
		dataResults : OUT CHAR_ARRAY_TYPE(0 TO RESULT_BYTE_NUM - 1) -- index 3 holds the peak
	);
END dataConsume;

ARCHITECTURE detectorArch OF dataConsume IS
 
	TYPE state_type IS (S0, S1, S2, S3, S4, S5);
	SIGNAL curState, nextState : state_type;
	SIGNAL peakvalue : std_logic_vector(7 DOWNTO 0) := "00000000";
	SIGNAL ctrlOut_reg, equal, peakValueSmaller, shift_enable, store_enable, count_enable, count_reset, start_enable, subtract_enable, T : std_logic := '0'; 
	SIGNAL ctrlIn_delayed, ctrlIn_detected : std_logic;
	SIGNAL allData : CHAR_ARRAY_TYPE(0 TO 998); 
	SIGNAL index, indexpk, start_index : INTEGER := 0;
	SIGNAL counter1, counter2, counter3, c1, c2, c3 : std_logic_vector(3 DOWNTO 0) := "0000";
	
	SIGNAL hold_en : std_logic := '0';
	SIGNAL hold_reg : std_logic := '0';
	SIGNAL hold : std_logic := '0';
	
	SIGNAL byte_en : std_logic := '0';
	SIGNAL byte_reg : std_logic_vector(7 DOWNTO 0) := "00000000";
	
	SIGNAL maxIndex_en : std_logic := '0';
	SIGNAL maxIndex_reg : BCD_ARRAY_TYPE(2 DOWNTO 0);
	
	SIGNAL counterOut, numWords, indexPk_bcd : std_logic_vector(11 DOWNTO 0);
 
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
	--subtract_enable - Goes high to enable the subtractor.
	--ctrlIn_delayed - Holds the value of the ctrlIn by one delayed clock cycle.
	--ctrlIn_detected - Goes high when the value of CtrlIn and ctrlIn_delayed are different.
	--allData - Stores all of the vlaues that have been recieved from the data generator in an index.
	--index - Counts how many values have been recieved from the data generator.
	--indexpk - Hold the value of the peak value by index.
	--start_index - Records how many start signals have been recieved so that the correct byte in sequence can be sent to the command processor.
	--counter1 - Holds the value of the first counter.
	--counter2 - Holds the value of the second counter.
	--counter3 - Holds the value of the third counter.
	--c1 - Holds a temporary value of the first counter.
	--c2 - Holds a temporary value of the second counter.
	--c3 - Holds a temporary value of the third counter.
	--hold - Goes high when the index is zero to put assign the first byte as the peak value.
	--counterOut - Concantanates the three counters (counter1, counter2 and counter3) to make a 12 bit value.
	--numWords - Stores the number of words that need to be processed by the data generator.
	--indexPk_bcd - Concantanates (c1,c2 and c3) to hold a 12 bit value of the index peak value.

BEGIN
	------------------------------------------------------
	combi_nextState : PROCESS(clk, curState, start, counterOut, numWords, ctrlIn_detected, peakValueSmaller, hold, index, indexpk_bcd, alldata, start_index)
	BEGIN
	  
	  --Setting the signals to an initial value to remove latches.
		count_reset <= '0';
		shift_enable <= '0';
		store_enable <= '0';
		dataReady <= '0';
		count_enable <= '0';
		subtract_enable <= '0';
		seqDone <= '0';
		
		--peakvalue <= "00000000";
		
		T <= '0';
		
		hold_en <= '0';
		hold_reg <= '0';
		
		byte_en <= '0';
		byte_reg <= "00000000";
		
		--maxIndex <= ("0000", "0000", "0000");
		maxIndex_en <='0';
		--maxIndex_reg <= ("0000", "0000", "0000");
		maxIndex_reg(0) <= "0000";
	  maxIndex_reg(1) <= "0000";
	  maxIndex_reg(2) <= "0000";
	  
		CASE curState IS
 
			--Reset state.
			WHEN S0 => 
				seqDone <= '0'; 
				count_reset <= '1';
				--Checks to see if a start command has been recieved before starting the retreival process.
				IF start = '1' THEN
					--ctrlOut_reg <= '0';
					T <= '0';
					shift_enable <= '0';
					store_enable <= '0';
					
				  hold_en <= '1';	
					hold_reg <= '1';
					
					nextState <= S1;
				ELSE NULL;
				END IF;
 
				--Checks to see if all of the data has been processed by the data generator. 
			WHEN S1 => 
				count_reset <= '0';
				dataReady <= '0';
				--If all of the data has been processed then the final data values are passed to the command processor.
				IF counterOut = numWords THEN
					store_enable <= '1';
					maxIndex_en <= '1';
					maxIndex_reg(2) <= indexPk_bcd(11 DOWNTO 8);
					maxIndex_reg(1) <= indexPk_bcd(7 DOWNTO 4);
					maxIndex_reg(0) <= indexPk_bcd(3 DOWNTO 0);
					nextState <= S5;
					--If data generation has not finished, then the handshaking protocol starts.
				ELSE
					--ctrlOut_reg <= NOT ctrlOut_reg;
					T <= '1';
					nextState <= S2;
				END IF;
 
				--Waits for the data generator to send back a signal before allowing the new data byte to be shifted as well as incrementing the counter.
			WHEN S2 => 
				IF ctrlIn_detected = '1' THEN 
					shift_enable <= '1'; 
					count_enable <= '1'; 
					nextState <= S3;
				ELSE
					nextState <= S2;
				END IF;
 
				--Adjusts the peak value if the new data byte is greater then the current largest value.
			WHEN S3 => 
				shift_enable <= '0';
				count_enable <= '0';
				nextState <= S4;
				--If the new value is greater the peak value and the inedex peak are changed.
				IF peakValueSmaller = '1' THEN
					peakValue <= allData(index - 1);
					indexPk <= index - 1;
					subtract_enable <= '1';
				ELSIF hold = '1' THEN
					peakValue <= allData(0);
					indexPk <= 0;
					
					hold_en <= '1';
					hold_reg <= '0';
				END IF;
 
				--Checks if the start signal is high and if true then send the next byte in sequence to the command processor.
			WHEN S4 => 
				subtract_enable <= '0';
				nextState <= S1;
				IF start = '1' THEN
					dataready <= '1';
					IF index /= 0 THEN
						byte_en <= '1';
						byte_reg <= allData(start_index - 1);
					ELSE
						byte_en <= '1';
						byte_reg <= allData(0);
					END IF; 
				ELSE NULL;
				END IF;
 
				--Enters this state to assert that the data sequence and peak are ready to be outputted.
			WHEN S5 => 
				seqDone <= '1';
				nextState <= S0;
				
				--Enters initial state otherwise.
			WHEN OTHERS =>
			  nextState <= S0;
 
		END CASE;
	END PROCESS;
 
	--Casts various signals to output signals.
	counterOut <= counter3 & counter2 & counter1;
	numWords <= numWords_bcd(2) & numWords_bcd(1) & numWords_bcd(0);
	indexPk_bcd <= c3 & c2 & c1;
	ctrlIn_detected <= ctrlIn XOR ctrlIn_delayed;
	
	------------------------------------------------------ 
	ctrl_out_toggle : PROCESS (clk, T)
	BEGIN
	  IF clk'EVENT AND clk = '1' THEN
	    if T = '0' then
	      ctrlOut_reg <= ctrlOut_reg;
	    elsif T = '1' then
	      ctrlOut_reg <= not(ctrlOut_reg);
	    end if;
	   end if;
	  end PROCESS; 
	------------------------------------------------------ 
	-- Registers to stop latches from being inferred
	reg : PROCESS (clk, hold_en, byte_en, maxIndex_en)
	BEGIN 
	   IF rising_edge(clk) AND hold_en = '1' THEN 
	     hold <= hold_reg;
	   END IF;
		
		IF rising_edge(clk) AND byte_en = '1' THEN 
			byte <= byte_reg;
		END IF;
		
		
		IF rising_edge(clk) AND maxIndex_en = '1' THEN 
			maxIndex <= maxIndex_reg;
		END IF;
	END PROCESS;
	------------------------------------------------------ 
	--Used to subtract one bit / value from the current index in oder to correctly adjust the value of the peak index.
	subtractor : PROCESS (counter1, counter2, counter3, subtract_enable)
	BEGIN
	  IF subtract_enable = '1' THEN
			-- counter1 = LSB counter3 = MSB
			IF counter1 > "0000" AND counter1 < "1010" THEN
					-- If counter1 is between 1-9 just subtract 1 from LSB
				c1 <= std_logic_vector(unsigned(counter1(3 DOWNTO 0)) - ("0001"));
				c2 <= counter2;
				c3 <= counter3;
			ELSIF counter1 = "0000" AND counter2 /= "0000" THEN
				-- If counter1 is X0 then subtract 1 from counter2 and set LSB to 9
				c1 <= "1001";
				c2 <= std_logic_vector(unsigned(counter2(3 DOWNTO 0)) - ("0001"));
				c3 <= counter3;
			ELSIF counter1 = "0000" AND counter2 = "0000" AND counter3 /= "0000" THEN
				-- If counter1 and counter2 are X0 then subtract 1 from counter3(MSB) and set LSB and counter2 to 9
				c1 <= "1001";
				c2 <= "1001";
				c3 <= std_logic_vector(unsigned(counter3(3 DOWNTO 0)) - ("0001"));
			ELSIF counter1 = "0000" AND counter2 = "0000" AND counter3 = "0000" THEN
				-- Cant subtract from counter = 0
				c1 <= "0000";
				c2 <= "0000";
				c3 <= "0000";
--			ELSE 
--			  c1 <= "0000";
--				c2 <= "0000";
--				c3 <= "0000";
			END IF;
--		ELSE
--			c1 <= "0000";
--			c2 <= "0000";
--			c3 <= "0000";	
		END IF;
	END PROCESS; 
	------------------------------------------------------
	--Stores the bytes of data from the generator into an index.
	data_store : PROCESS (clk, shift_enable)
	BEGIN
		IF rising_edge(clk) AND shift_enable = '1' THEN
			allData(index) <= data;
		END IF;
	END PROCESS; 
	------------------------------------------------------
	--After data generation, the peak value and values three above and below are put into dataresults.
	stored_result : PROCESS (clk, store_enable)
	BEGIN
		IF rising_edge(clk) AND store_enable = '1' THEN
			dataResults(6) <= allData(indexpk - 3);
			dataResults(5) <= allData(indexpk - 2);
			dataResults(4) <= allData(indexpk - 1);
			dataResults(3) <= allData(indexpk);
			dataResults(2) <= allData(indexpk + 1);
			dataResults(1) <= allData(indexpk + 2);
			dataResults(0) <= allData(indexpk + 3);
		ELSE NULL;
		END IF;
	END PROCESS; 
	------------------------------------------------------ 
	--Three counters that are used for concantination purposes with respect to asserting BCD values.
	counter : PROCESS (clk, count_enable, count_reset, counter1, counter2, counter3)
	BEGIN
	  --resets all of the counters upon request.
		IF count_reset = '1' THEN
			start_index <= 0;
			index <= 0;
			counter3 <= "0000";
			counter2 <= "0000";
			counter1 <= "0000";
			--increase the value of index, start_index and the counters per clock cycle.
		ELSIF rising_edge(clk) AND count_enable = '1' THEN
			index <= index + 1;
			start_index <= start_index + 1;
			counter1 <= std_logic_vector(unsigned(counter1) + "0001");
			--If counter1 is 9 then incriment counter2 and reset counter1.
			IF counter1 = "1001" THEN
				counter2 <= std_logic_vector(unsigned(counter2) + "0001");
				counter1 <= "0000";
				--If counter2 is 9 then incriment counter3 and reset counter1.
				IF counter2 = "1001" THEN
					counter3 <= std_logic_vector(unsigned(counter3) + "0001");
					counter2 <= "0000";
					--If counter3 is 9 then reset counter3.
					IF counter3 = "1001" THEN
						counter3 <= "0000";
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	------------------------------------------------------
	--Compares the newest value from the data generator with the current peak value and sees which is greater.
	comparator : PROCESS(peakValue, allData, index)
	BEGIN
		peakValueSmaller <= '0';
		equal <= '0';
		IF index /= 0 THEN
			--hold <= '0';
			--If the peak and the latest byte are the same, assert the 'equal' signal.
			IF peakValue = allData(index - 1) THEN
				equal <= '1';
				peakValueSmaller <= '0';
		  --If the peak is greatest then the latest byte don't assert any of the signals.
			ELSIF peakValue > allData(index - 1) THEN
				equal <= '0';
				peakValueSmaller <= '0'; 
				--If the peak is smaller then the latest byte assert peakValueSmaller.
			ELSIF peakValue < allData(index - 1) THEN
				equal <= '0';
				peakValueSmaller <= '1'; 
			END IF;
			--if index = 0
		--ELSE hold <= '1';
		END IF;
	END PROCESS;
	------------------------------------------------------
	--Goes back to the first state when reset, else chnages state on a rising clock edge.
	seq_state : PROCESS (clk, reset)
	BEGIN
		IF reset = '1' AND clk'EVENT AND clk = '1' THEN
			curState <= S0;
		ELSIF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
			ctrlOut <= ctrlOut_reg;
		END IF;
	END PROCESS;
	------------------------------------------------------
	--Hand shaking protocool for the communication with the data generator.
	delay_CtrlIn : PROCESS(clk) 
	BEGIN
		IF rising_edge(clk) THEN
			ctrlIn_delayed <= ctrlIn;
		END IF;
	END PROCESS;
	------------------------------------------------------
	END; --detectorArch

