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
	SIGNAL counter : UNSIGNED         (26 DOWNTO 0); -- 2^26 < 72000000 < 2^27
	SIGNAL temp    : STD_LOGIC_VECTOR (8 DOWNTO 0);
	SIGNAL cntsec  : UNSIGNED         (8 DOWNTO 0);
	BEGIN
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
END Behavior;