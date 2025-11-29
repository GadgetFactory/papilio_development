-- Test synthesis of HQVGA for Gowin FPGA
-- Minimal top-level wrapper to verify VHDL compatibility

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity hqvga_test_top is
  port (
    -- Clock input
    clk_27mhz: in std_logic;
    
    -- VGA outputs (3:3:2 RGB)
    vga_r: out std_logic_vector(2 downto 0);
    vga_g: out std_logic_vector(2 downto 0);
    vga_b: out std_logic_vector(1 downto 0);
    vga_hsync: out std_logic;
    vga_vsync: out std_logic;
    
    -- Simple test inputs
    btn_reset: in std_logic
  );
end entity hqvga_test_top;

architecture behave of hqvga_test_top is

  component HQVGA is
    generic(
      vgaclk_divider: integer := 1
    );
    port (
      wishbone_in : in std_logic_vector(100 downto 0);
      wishbone_out : out std_logic_vector(100 downto 0);
      VGA_Bus : inout std_logic_vector(32 downto 0);
      clk_50Mhz: in std_logic;
      vga_hsync: out std_logic;
      vga_vsync: out std_logic;
      vga_r2: out std_logic;
      vga_r1: out std_logic;
      vga_r0: out std_logic;
      vga_g2: out std_logic;
      vga_g1: out std_logic;
      vga_g0: out std_logic;
      vga_b1: out std_logic;
      vga_b0: out std_logic
    );
  end component HQVGA;

  -- Clock generation (placeholder - would use rPLL in real design)
  signal clk_50mhz: std_logic;
  signal rst: std_logic;
  
  -- Wishbone signals (tied off for synthesis test)
  signal wb_in: std_logic_vector(100 downto 0);
  signal wb_out: std_logic_vector(100 downto 0);
  signal vga_bus: std_logic_vector(32 downto 0);

begin

  -- Simple clock passthrough for synthesis test
  -- In real design, use Gowin rPLL to generate 50MHz from 27MHz
  clk_50mhz <= clk_27mhz;
  rst <= not btn_reset;

  -- Build wishbone bus for synthesis test
  process(clk_27mhz, rst)
  begin
    wb_in <= (others => '0');
    wb_in(61) <= clk_27mhz;  -- wb_clk
    wb_in(60) <= rst;         -- wb_rst
  end process;

  -- Instantiate HQVGA
  hqvga_inst: HQVGA
    generic map (
      vgaclk_divider => 1
    )
    port map (
      wishbone_in => wb_in,
      wishbone_out => wb_out,
      VGA_Bus => vga_bus,
      clk_50Mhz => clk_50mhz,
      vga_hsync => vga_hsync,
      vga_vsync => vga_vsync,
      vga_r2 => vga_r(2),
      vga_r1 => vga_r(1),
      vga_r0 => vga_r(0),
      vga_g2 => vga_g(2),
      vga_g1 => vga_g(1),
      vga_g0 => vga_g(0),
      vga_b1 => vga_b(1),
      vga_b0 => vga_b(0)
    );

end behave;
