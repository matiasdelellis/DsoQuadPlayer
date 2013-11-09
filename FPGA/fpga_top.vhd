-- 
-- DsoQuadPlayer.
--

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.all;

ENTITY dso_quad_top IS
	generic (ram_lenght : INTEGER := 4096);

	PORT (clk:      IN     STD_LOGIC;                      -- Main clock input      -> rising edge
	      rst_n:    IN     STD_LOGIC;                      -- Master reset          -> Active low
	      clr_n:    IN     STD_LOGIC;                      -- FIFO status reset     -> Active low

	      -- Memory bus
	      fsmc_ce:  IN     STD_LOGIC;                      -- Databus select enable -> Active high
	      fsmc_nwr: IN     STD_LOGIC;                      -- Databus write enable  -> Active low
	      fsmc_nrd: IN     STD_LOGIC;                      -- Databus read enable   -> Active low
	      fsmc_db:  INOUT  STD_LOGIC_VECTOR(15 DOWNTO 0);  -- Data bus to MCU

	      -- ADC signals
	      adc_mode:  OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);   -- ADC mode              -> "01": Normal Operation.
	      cha_clk:   OUT   STD_LOGIC;                      -- ADC clock channel A   -> rising edge
	      chb_clk:   OUT   STD_LOGIC;                      -- ADC clock channel B   -> rising edge

	      -- Oscilloscope data inputs
	      cha_din:   IN    STD_LOGIC_VECTOR(7 DOWNTO 0);
	      chb_din:   IN    STD_LOGIC_VECTOR(7 DOWNTO 0);
	      chc_din:   IN    STD_LOGIC;
	      chd_din:   IN    STD_LOGIC;

	      -- General-purpose input/output
	      PB0:       IN    STD_LOGIC;                      -- Fill fifo             -> Active high
	      PA2:       OUT   STD_LOGIC;
	      PA3:       OUT   STD_LOGIC;
	      PA5:       OUT   STD_LOGIC;
	      PA6:       OUT   STD_LOGIC;
	      PA7:       OUT   STD_LOGIC;
	      PC4:       OUT   STD_LOGIC;
	      PC5:       OUT   STD_LOGIC);
END dso_quad_top;

ARCHITECTURE Behavior OF dso_quad_top IS
	-- Prescaler to write memory.
	SIGNAL prescale         : STD_LOGIC_VECTOR(2 downto 0);
	SIGNAL prescaler_count  : INTEGER RANGE 0 TO 360000;
	SIGNAL prescaler_flag   : INTEGER RANGE 0 TO 360000;
	SIGNAL w_enable         : STD_LOGIC;

	-- FSMC Bus
	SIGNAL fsmc_want_count  : STD_LOGIC;

	SIGNAL fsmc_output_data : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL fsmc_input_data  : STD_LOGIC_VECTOR(15 downto 0);

	SIGNAL fsmc_nrd_lached  : STD_LOGIC;
	SIGNAL fsmc_nrd_f_edge  : STD_LOGIC;

	-- Memory
	TYPE mem_type IS ARRAY (ram_lenght - 1 DOWNTO 0) OF STD_LOGIC_VECTOR (15 downto 0);

	SIGNAL RAM              : mem_type;
	SIGNAL w_address        : INTEGER RANGE 0 TO ram_lenght - 1;
	SIGNAL r_address        : INTEGER RANGE 0 TO ram_lenght - 1;
	SIGNAL w_data           : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL r_data           : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL d_count          : STD_LOGIC_VECTOR(15 downto 0);

	BEGIN
		-----------------------------------
		-- Settings process reading FSMC --
		-----------------------------------
		-- Micro write Bus on clock when fsmc_ce = '1' AND fsmc_nwr = '0'
		PROCESS (clk, rst_n)
		BEGIN
			IF rst_n = '0' THEN
				fsmc_input_data <= (OTHERS => '0');
			ELSIF rising_edge(clk) THEN
				IF fsmc_ce = '1' AND fsmc_nwr = '0' THEN
					fsmc_input_data <= fsmc_db;
				END IF;
			END IF;
		END PROCESS;

		-- Settings.
		fsmc_want_count <= fsmc_input_data(0);
		prescale        <= fsmc_input_data(3 DOWNTO 1);

		------------------------------------
		-- Prescaler to select samplerate --
		------------------------------------
		WITH prescale SELECT
			prescaler_flag <= 72     WHEN "000", -- 1u
			                  360    WHEN "001", -- 5u
			                  1440   WHEN "010", -- 20u
			                  3600   WHEN "011", -- 50u
			                  7200   WHEN "100", -- 100u
			                  36000  WHEN "101", -- 500u
			                  72000  WHEN "110", -- 1m
			                  360000 WHEN OTHERS; -- 5m

 		PROCESS (clk)
 		BEGIN
			IF rising_edge(clk) THEN
				IF rst_n = '0' THEN
					prescaler_count <= 0;
					w_enable <= '0';
				ELSIF prescaler_count = prescaler_flag THEN
					prescaler_count <= 0;
					w_enable <= '1';
				ELSE
					prescaler_count <= prescaler_count + 1;
					w_enable <= '0';
 				END IF;
 			END IF;
		END PROCESS;

 		--------------------------------
		-- Chanel A and B with Memory --
		--------------------------------

		adc_mode  <= "01";
		cha_clk   <= clk;
		chb_clk   <= clk;

		-- Write process.
		w_data <= chb_din & cha_din;

 		PROCESS (clk)
 		BEGIN
			IF rising_edge(clk) THEN
				IF rst_n = '0' OR clr_n = '0' THEN
					w_address <= 0;
 				ELSIF w_enable = '1' AND PB0 = '1' THEN
 					IF w_address < ram_lenght - 1 THEN
	 					w_address <= w_address + 1;
	 					RAM(w_address) <= w_data;
					END IF;
 				END IF;
 			END IF;
		END PROCESS;
		d_count <= STD_LOGIC_VECTOR (to_unsigned(w_address, 16));

		-- Read process.
		PROCESS (clk)
		BEGIN
			IF rising_edge(clk) THEN
				fsmc_nrd_lached <= fsmc_nrd;
			END IF;
		END PROCESS;
		fsmc_nrd_f_edge <= fsmc_nrd_lached AND (NOT fsmc_nrd);
	
		PROCESS (clk)
		BEGIN
			IF rising_edge(clk) THEN
				IF rst_n = '0' OR clr_n = '0' OR fsmc_want_count = '1' THEN
					r_address <= 0;
				ELSIF fsmc_nrd_f_edge = '1' THEN
					IF r_address < w_address THEN
						r_address <= r_address + 1;
					END IF;
				END IF;
			END IF;
		END PROCESS;
		r_data <= RAM(r_address);

		-- Select between the ram data, and their mem size.
		fsmc_output_data <= r_data WHEN fsmc_want_count = '0' ELSE d_count;

		-- Write data on fsmc when fsmc_nrd = '0' and fsmc_ce = '1'. If not, put high impedance to read.
		fsmc_db <= fsmc_output_data WHEN (fsmc_nrd = '0' AND fsmc_ce = '1') ELSE (OTHERS => 'Z');
END Behavior;