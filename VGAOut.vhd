library IEEE;
--use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;



entity VOut is
	port (
		CLK :  in STD_LOGIC;
		TM  :  in STD_LOGIC := '1'; -- Negative
		HS  : out STD_LOGIC;        -- Negative
		VS  : out STD_LOGIC;        -- Negative
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
	signal VTest : STD_LOGIC;
	signal mpos  : INTEGER range 0 to 8979;	
	signal CCNT  : INTEGER range 0 to HorTotArea;
	signal RCNT  : INTEGER range 0 to VerTotArea;
	signal cctmp : INTEGER range 0 to VerVisArea;
	signal picv  : STD_LOGIC_VECTOR (7  downto 0);

	component thpic is
		port (
			CLK :  in STD_LOGIC;
			adr :  in STD_LOGIC_VECTOR (13 downto 0);
			q   : out STD_LOGIC_VECTOR (7  downto 0)
		);
	end component;

begin

	TPic:	thpic port map (
			adr => conv_std_logic_vector(mpos,14),
			clk => CLK,
			q   => picv
	);

	process(CLK)
	begin
	
	if rising_edge(CLK) then

		-- Video test mode control
		VTest <= not TM;

		-- Video output
		if CCNT < HorVisArea and RCNT < VerVisArea 
			then
				if VTest = '0' then 
				-- Visible area control
					if color = '1'
						then RCH <= x"F"; GCH <= x"F"; BCH <= x"F";
						else RCH <= x"0"; GCH <= x"0"; BCH <= x"0";
					end if;
				-- Grid for display test
				elsif conv_std_logic_vector(CCNT,1) = b"0" and conv_std_logic_vector(RCNT,1) = b"0" and
				      CCNT /=  2  and RCNT /= 2 and CCNT /= HorVisArea - 4 and RCNT /= VerVisArea - 4
					then RCH <= x"F"; GCH <= x"F"; BCH <= x"F";
					else RCH <= x"0"; GCH <= x"0"; BCH <= x"0";
				end if;
			else 
				RCH <= x"0"; GCH <= x"0"; BCH <= x"0";
		end if;

		-- Overflow control
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



process(CLK)
	begin
	
	if rising_edge(CLK) then
		
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
			mpos <= 1;
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