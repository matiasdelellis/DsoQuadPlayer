-- 
-- DsoQuadPlayer.
--

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY fpga_top IS
	PORT (clk:      in     std_logic;
	      rst_n:    in     std_logic;

	      -- Memory bus
	      fsmc_ce:  in     std_logic;
	      fsmc_nwr: in     std_logic;
	      fsmc_nrd: in     std_logic;
	      fsmc_db:  inout  std_logic_vector(15 downto 0);

	      -- ADC signals
	      adc_mode:  in    std_logic;
	      adc_sleep: out   std_logic;
	      cha_clk:   out   std_logic;
	      chb_clk:   out   std_logic;

	      -- Oscilloscope data inputs
	      cha_din:   in    std_logic_vector(7 downto 0);
	      chb_din:   in    std_logic_vector(7 downto 0);
	      chc_din:   in    std_logic;
	      chd_din:   in    std_logic;

	      -- General-purpose input/output
	      PB0:       out   std_logic;
	      --PB1:       out   std_logic;
	      PB2:       out   std_logic;
	      PA2:       out   std_logic;
	      PA3:       out   std_logic;
	      PA5:       out   std_logic;
	      PA6:       out   std_logic;
	      PA7:       out   std_logic;
	      PC4:       out   std_logic;
	      PC5:       out   std_logic);
END ENTITY;

ARCHITECTURE behavioral OF fpga_top IS
	signal counter : unsigned         (26 downto 0); -- 2^26 < 72000000 < 2^27
	signal temp    : std_logic_vector (8 downto 0);
	signal cntsec  : unsigned         (8 downto 0);
	BEGIN
		PROCESS (clk)
		BEGIN
			if (rising_edge(clk)) then
				if (rst_n = '0') then
					cntsec  <= (others => '0');
					counter <= (others => '0');
				else
					counter <= counter + 1;
					if (counter = 72000000) then
						cntsec <= cntsec + 1;
						counter <= (others => '0');
					end if;
				end if;
			end if;
		END PROCESS;

		temp <= std_logic_vector (cntsec);
		PB0 <= temp (8);
		PB2 <= temp (7);
		PA2 <= temp (6);
		PA3 <= temp (5);
		PA5 <= temp (4);
		PA6 <= temp (3);
		PA7 <= temp (2);
		PC4 <= temp (1);
		PC5 <= temp (0);
END ARCHITECTURE;