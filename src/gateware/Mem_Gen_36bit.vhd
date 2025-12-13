----------------------------------------------------------------------------------
-- Mem_Gen_36bit.vhd
--
-- Copyright (C) 2013 Jack Gassett
-- 
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
--
----------------------------------------------------------------------------------
--
-- Details: http://papilio.cc
--
-- Single Ported RAM, 36bit wide, depth is configurable.
-- 
-- Set the depth by setting the brams generic variable.
-- Depth will be 512 x brams so 12 brams will be 6K depth.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Gowin version: Using inferred Block RAM instead of vendor primitives
-- Gowin synthesizer will automatically use BSRAM (Block SRAM) for this pattern

entity Mem_Gen_36bit is
	generic (
	 brams: integer := 12
	);
	Port ( CLK : in  STD_LOGIC;
		  ADDR : in  STD_LOGIC_VECTOR (13 downto 0);
		  WE : in  STD_LOGIC;
		  DOUT : out  STD_LOGIC_VECTOR (35 downto 0);
		  DIN : in  STD_LOGIC_VECTOR (35 downto 0));
end Mem_Gen_36bit;

architecture Behavioral of Mem_Gen_36bit is

	-- Inferred Block RAM - Gowin will automatically use BSRAM
	type ram_type is array (0 to (brams*512)-1) of std_logic_vector(35 downto 0);
	signal ram : ram_type := (others => (others => '0'));
	
	-- Force synthesis to use Block RAM
	attribute syn_ramstyle : string;
	attribute syn_ramstyle of ram : signal is "block_ram";

begin

	-- Simple synchronous RAM with write-first behavior
	process(CLK)
	begin
		if rising_edge(CLK) then
			if WE = '1' then
				ram(CONV_INTEGER(ADDR)) <= DIN;
			end if;
			DOUT <= ram(CONV_INTEGER(ADDR));
		end if;
	end process;

end Behavioral;

