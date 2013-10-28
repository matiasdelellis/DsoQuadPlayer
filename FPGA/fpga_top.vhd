-- 
-- DsoQuadPlayer.
--

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY dso_quad_top IS
	generic (ram_lenght : INTEGER := 4096);

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
	      PB0:       IN   STD_LOGIC;    -- Fill when PB0 = '0'
	      --PB1:       OUT   STD_LOGIC; -- Used as reset.
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
	-- 8 bit counter example on PIO
	SIGNAL counter          : UNSIGNED         (26 DOWNTO 0); -- 2^26 < 72000000 < 2^27
	SIGNAL cntsec           : UNSIGNED         (7 DOWNTO 0);
	SIGNAL temp             : STD_LOGIC_VECTOR (7 DOWNTO 0);

	-- FSMC Bus
	SIGNAL fsmc_want_count  : STD_LOGIC;
	SIGNAL fsmc_was_read_r  : STD_LOGIC;

	SIGNAL fsmc_output_data : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL fsmc_input_data  : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL fsmc_nrd_edge    : STD_LOGIC;

	-- Memory
	TYPE mem_type IS ARRAY (ram_lenght - 1 DOWNTO 0) OF STD_LOGIC_VECTOR (15 downto 0);

	SIGNAL RAM              : mem_type;
	SIGNAL mem_read         : STD_LOGIC;
	SIGNAL w_address        : INTEGER RANGE 0 TO ram_lenght - 1;
	SIGNAL r_address        : INTEGER RANGE 0 TO ram_lenght - 1;
	SIGNAL l_address        : INTEGER RANGE 0 TO ram_lenght - 1;
	SIGNAL w_data           : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL r_data           : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL d_count          : STD_LOGIC_VECTOR(15 downto 0);

	BEGIN
		--------------------------------
		-- Chanel A and B with Memory --
		--------------------------------

		adc_sleep <= '1';
		cha_clk   <= clk;
		chb_clk   <= clk;

		-- Write process.
		w_data <= chb_din & cha_din;

 		PROCESS (clk)
 		BEGIN
 			IF rising_edge(clk) THEN
 				IF rst_n = '0' THEN
 					w_address <= 0;
 				ELSE
 					IF PB0 = '1' THEN
 						IF w_address < ram_lenght - 1 THEN
	 						w_address <= w_address + 1;
	 						RAM(w_address) <= w_data;
	 					END IF;
					END IF;
 				END IF;
 			END IF;
		END PROCESS;

		-- Infer a lach to save last write address.
 		PROCESS (clk)
 		BEGIN
 			IF rising_edge(clk) THEN
 				IF (rst_n = '0') THEN
					l_address <= 0;
 				ELSE
 					IF PB0 = '1' THEN
						l_address <= w_address;
					END IF;
 				END IF;
 			END IF;
		END PROCESS;
		d_count <= STD_LOGIC_VECTOR (to_unsigned(l_address, 16));

		-- Read process.
		PROCESS (clk)
		BEGIN
			IF rising_edge(clk) THEN
				IF rst_n = '0' THEN
					r_address <= 0;
				ELSIF mem_read = '1' THEN
					IF r_address < l_address THEN
						r_address <= r_address + 1;
					END IF;
				END IF;
			END IF;
		END PROCESS;
		r_data <= RAM(r_address);
		mem_read <= fsmc_nrd_edge WHEN (fsmc_want_count = '0') ELSE '0';

		-------------------
		-- FSMC example. --
		-------------------

		-- Micro write Bus on clock when fsmc_ce = '1' AND fsmc_nwr = '0'
		-- Only used to know when micro want count or mem data.
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
		fsmc_want_count <= '1' WHEN fsmc_input_data = X"0001" ELSE '0';

		-- Micro read Bus on clock when fsmc_ce = '1' AND fsmc_nwr = '0'
		PROCESS (clk, rst_n)
		BEGIN
			IF rst_n = '0' THEN
				fsmc_was_read_r <= '0';
			ELSIF rising_edge(clk) THEN
				IF fsmc_ce = '1' AND fsmc_nrd = '0' THEN
					fsmc_was_read_r <= '1';
				ELSE
					fsmc_was_read_r <= '0';
				END IF;
			END IF;
		END PROCESS;
		fsmc_nrd_edge <= '1' WHEN fsmc_nrd = '1' AND fsmc_was_read_r = '1' ELSE '0';

		-- Select between the ram data, and their mem size.
		fsmc_output_data <= r_data WHEN fsmc_want_count = '0' ELSE d_count;

		-- Write data on fsmc when fsmc_nrd = '0' and fsmc_ce = '1'. If not, put high impedance to read.
		-- fsmc_db <= fsmc_output_data WHEN fsmc_was_read_r = '1' ELSE (OTHERS => 'Z');
		fsmc_db <= fsmc_output_data WHEN (fsmc_nrd = '0' AND fsmc_ce = '1') ELSE (OTHERS => 'Z');
END Behavior;