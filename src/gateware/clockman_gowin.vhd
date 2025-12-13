----------------------------------------------------------------------------------
-- clockman_gowin.vhd
--
-- Gowin version of clockman wrapper for SUMP Logic Analyzer
-- Replaces Xilinx DCM with Gowin rPLL primitive
--
-- Takes 27MHz input and generates 100MHz output for SUMP analyzer
-- PLL Settings: FCLKIN=27, IDIV=6, FBDIV=25, ODIV=8
-- Formula: (27 * 25 / 6) / 8 = 100.875 MHz ≈ 100 MHz
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity clockman is
    port(
        clkin : in std_logic;       -- 27 MHz clock input
        clk0 : out std_logic        -- 100 MHz clock output
    );
end clockman;

architecture behavioral of clockman is

    component Gowin_rPLL_27_to_100
        port(
            clkout : out std_logic;
            clkin : in std_logic
        );
    end component;

begin

    pll_inst : Gowin_rPLL_27_to_100
    port map(
        clkin => clkin,
        clkout => clk0
    );

end behavioral;
