library IEEE;
--use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;



entity VOut is
	port (
		clk :  in STD_LOGIC;
		HS  : out STD_LOGIC;
		VS  : out STD_LOGIC;
		RCH : out STD_LOGIC_VECTOR(3 downto 0);
		GCH : out STD_LOGIC_VECTOR(3 downto 0);
		BCH : out STD_LOGIC_VECTOR(3 downto 0)
	);
end entity;



architecture Behavioral of VOut is
	
	-- 1024x768 @ 60Hz, 65mHz pixel clock - params from tinyvga.com/vga-timing

	constant HorVisArea : INTEGER := 1024;
	constant HorFrPArea : INTEGER := 24;
	constant HorSyPArea : INTEGER := 136;
	constant HorBkPArea : INTEGER := 160;
	constant HorTotArea : INTEGER := HorVisArea + HorFrPArea + HorSyPArea + HorBkPArea;

	constant VerVisArea : INTEGER := 768;
	constant VerFrPArea : INTEGER := 3;
	constant VerSyPArea : INTEGER := 6;
	constant VerBkPArea : INTEGER := 29;
	constant VerTotArea : INTEGER := VerVisArea + VerFrPArea + VerSyPArea + VerBkPArea;

	signal color : STD_LOGIC;
	signal mpos  : INTEGER range 0 to 8979;	
	signal CCNT  : INTEGER range 0 to HorTotArea;
	signal RCNT  : INTEGER range 0 to VerTotArea;
	signal cctmp : INTEGER range 0 to VerVisArea;
	signal picv  : STD_LOGIC_VECTOR (7  downto 0);

	component thpic is
		port (
			clk :  in STD_LOGIC;
			adr :  in STD_LOGIC_VECTOR (13 downto 0);
			q   : out STD_LOGIC_VECTOR (7  downto 0)
		);
	end component;

begin

	TPic:	thpic port map (
			adr => conv_std_logic_vector(mpos,14),
			clk => clk,
			q   => picv
	);

	process(clk)
	begin
	
	if rising_edge(clk) then

		-- Margins test frame
--		if  conv_std_logic_vector(CCNT,1) = b"0" and conv_std_logic_vector(RCNT,1) = b"0" and
--			(CCNT = 0 or RCNT = 0 or CCNT = HorVisArea - 1 or RCNT = VerVisArea - 1) and
--			 CCNT < HorVisArea and RCNT < VerVisArea
--		    	then RCH <= x"F"; GCH <= x"F"; BCH <= x"F"; else RCH <= x"0"; GCH <= x"0"; BCH <= x"0";
--		end if;

		-- Visible area control
		if CCNT < HorVisArea and RCNT < VerVisArea then
			if color = '1'
				then 
					RCH <= b"1111";
					GCH <= b"1111";
					BCH <= b"1111";
				else 
					RCH <= b"0000";
					GCH <= b"0000";
					BCH <= b"0000";
			end if;
		else
			RCH <= b"0000";
			GCH <= b"0000";
			BCH <= b"0000";
		end if;


		-- Owerflow control
		if (CCNT = HorTotArea - 1) then
			CCNT <= 0;
			if RCNT = VerTotArea - 1 then
				RCNT <= 0;
			else
				RCNT <= RCNT + 1;
			end if;
		else
			CCNT <= CCNT + 1;
		end if;


		-- Sync pulse generation - negative polarity
		if (CCNT >= HorVisArea + HorFrPArea) and (CCNT < HorTotArea - HorBkPArea) then
			HS <= '0';
		else
			HS <= '1';
		end if;

		if (RCNT >= VerVisArea + VerFrPArea) and (RCNT < VerTotArea - VerBkPArea) then
			VS <= '0';
		else
			VS <= '1';
		end if;

	end if;

	
	end process;



process(clk)
	begin
	
	if rising_edge(clk) then
		
		-- Fetch new pixel value
		if (cctmp <  HorVisArea) and (CCNT = cctmp) then
			cctmp <= cctmp + conv_integer(picv(6 downto 0));
			color <= picv(7);
			mpos  <= mpos + 1;
		end if;

		-- Fetch the new row
		if CCNT = HorTotArea - 1 then
			cctmp <= 0;
		end if;

		-- Clear memory position each new frame
		if (CCNT = HorTotArea - 2) and (RCNT = VerTotArea - 1) then
			mpos <= 1; -- at 0 in memory placed number of blank rows (not used)
		end if;

	end if;
	
	end process;

end Behavioral;
			




library IEEE, ALTERA;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ALTERA.ALTERA_SYN_ATTRIBUTES.ALL;



entity thpic is
	port (
		clk :  in STD_LOGIC;
		adr :  in STD_LOGIC_VECTOR (13 downto 0);
		q   : out STD_LOGIC_VECTOR (7  downto 0)
	);
end thpic;



architecture rtl of thpic is
	
	type mem_t is array (8979 downto 0) of STD_LOGIC_VECTOR(7 downto 0);
		signal    rom: mem_t;
		attribute ram_init_file: string;
		attribute ram_init_file  of rom: signal is "TPic.mif";
	
	begin
		process(clk)
		begin
			if(rising_edge(clk)) then
				q <= rom(conv_integer(adr));
			end if;
		end process;

	end rtl;