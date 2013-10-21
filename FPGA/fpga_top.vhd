-- 
-- DsoQuadPlayer.
--

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY dso_quad_top IS
	PORT (clk:      IN     STD_LOGIC;
	      rst_n:    IN     STD_LOGIC;

	      -- Memory bus
	      fsmc_ce:  IN     STD_LOGIC;
	      fsmc_nwr: IN     STD_LOGIC;
	      fsmc_nrd: IN     STD_LOGIC;
	      fsmc_db:  INOUT  STD_LOGIC_VECTOR(15 DOWNTO 0);

	      -- ADC signals
	      adc_mode:  IN    STD_LOGIC;
	      adc_sleep: OUT   STD_LOGIC;
	      cha_clk:   OUT   STD_LOGIC;
	      chb_clk:   OUT   STD_LOGIC;

	      -- Oscilloscope data inputs
	      cha_din:   IN    STD_LOGIC_VECTOR(7 DOWNTO 0);
	      chb_din:   IN    STD_LOGIC_VECTOR(7 DOWNTO 0);
	      chc_din:   IN    STD_LOGIC;
	      chd_din:   IN    STD_LOGIC;

	      -- General-purpose input/output
	      PB0:       OUT   STD_LOGIC;
	      --PB1:       OUT   STD_LOGIC;
	      PB2:       OUT   STD_LOGIC;
	      PA2:       OUT   STD_LOGIC;
	      PA3:       OUT   STD_LOGIC;
	      PA5:       OUT   STD_LOGIC;
	      PA6:       OUT   STD_LOGIC;
	      PA7:       OUT   STD_LOGIC;
	      PC4:       OUT   STD_LOGIC;
	      PC5:       OUT   STD_LOGIC);
END dso_quad_top;

ARCHITECTURE Behavior OF dso_quad_top IS
	-- 9 bit counter example on PIO
	SIGNAL counter          : UNSIGNED         (26 DOWNTO 0); -- 2^26 < 72000000 < 2^27
	SIGNAL temp             : STD_LOGIC_VECTOR (8 DOWNTO 0);
	SIGNAL cntsec           : UNSIGNED         (8 DOWNTO 0);

	-- Basic fsmc example
	SIGNAL fsmc_want_count  : STD_LOGIC;

	SIGNAL fifo_data_out    : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL address          : UNSIGNED (3 DOWNTO 0);
	SIGNAL fifo_count       : UNSIGNED (3 DOWNTO 0);

	SIGNAL fsmc_output_data : STD_LOGIC_VECTOR(15 downto 0);

	BEGIN
		-------------------------------
		-- Fix floating pin warnings --
		-------------------------------
		adc_sleep <= '1';
		cha_clk   <= '0';
		chb_clk   <= '0';

		-----------------
		-- PIO example --
		-----------------
 		PROCESS (clk)
 		BEGIN
 			IF (rising_edge(clk)) THEN
 				IF (rst_n = '0') THEN
					cntsec  <= (OTHERS => '0');
					counter <= (OTHERS => '0');
 				ELSE
					counter <= counter + 1;
					IF (counter = 72000000) THEN
						cntsec <= cntsec + 1;
						counter <= (OTHERS => '0');
 					END IF;
 				END IF;
 			END IF;
		END PROCESS;		

		temp <= STD_LOGIC_VECTOR (cntsec);
		PB0 <= temp (8);
		PB2 <= temp (7);
		PA2 <= temp (6);
		PA3 <= temp (5);
		PA5 <= temp (4);
		PA6 <= temp (3);
		PA7 <= temp (2);
		PC4 <= temp (1);
		PC5 <= temp (0);

		-------------------
		-- FSMC example. --
		-------------------

		fifo_count <= to_unsigned(14, fifo_count'length);  -- Fixed as "MATIASDELELLIS" lenght.

		-- Process to read fsmc from micro.
		-- Read on rising_edge(clk), when fsmc_ce = '1' AND fsmc_nwr = '0'
		-- Used only to detect when micro want the fifo width.
		PROCESS (clk, rst_n)
		BEGIN
			IF rst_n = '0' THEN
				fsmc_want_count <= '0';
			ELSIF rising_edge(clk) THEN
				IF fsmc_ce = '1' AND fsmc_nwr = '0' THEN
					fsmc_want_count <= fsmc_db (0);
				END IF;
			END IF;
		END PROCESS;

		-- Process to configure the address to read on fifo.
		-- Change the pointer when rising_edge(clk).
		-- TODO: Change on any rising_edge(). When have to progress?.
		PROCESS (clk)
		BEGIN
			IF (rising_edge(clk)) THEN
				IF (rst_n = '0') THEN
					address <= (OTHERS => '0');
				ELSE
					IF (address < 13) THEN
						address <= address + 1;
					ELSE
						address <= (OTHERS => '0');
					END IF;
				END IF;
			END IF;
		END PROCESS;

		-- Select the info that would go to the port according to address.
		WITH address SELECT
			fifo_data_out <= X"0077" WHEN "0000", -- M
			                 X"0065" WHEN "0001", -- A
			                 X"0084" WHEN "0010", -- T
			                 X"0073" WHEN "0011", -- I
			                 X"0065" WHEN "0100", -- A
			                 X"0083" WHEN "0101", -- S
			                 X"0068" WHEN "0110", -- D
			                 X"0069" WHEN "0111", -- E
			                 X"0076" WHEN "1000", -- L
			                 X"0069" WHEN "1001", -- E
			                 X"0076" WHEN "1010", -- L
			                 X"0076" WHEN "1011", -- L
			                 X"0073" WHEN "1100", -- I
			                 X"0083" WHEN OTHERS; -- S

		-- Select between the information on the fifo, and their size.
		fsmc_output_data <= fifo_data_out WHEN (fsmc_want_count = '0') ELSE "000000000000" & STD_LOGIC_VECTOR (fifo_count);

		-- Write data on fsmc when fsmc_nrd = '0' and fsmc_ce = '1'. If not, put high impedance to read.
		fsmc_db <= fsmc_output_data WHEN (fsmc_nrd = '0' AND fsmc_ce = '1') ELSE (OTHERS => 'Z');
END Behavior;