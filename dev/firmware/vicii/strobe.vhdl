--------------------------------------------------------------------------------
--         .XXXXXXXXXXXXXXXX.  .XXXXXXXXXXXXXXXX.  .XX.                       --
--         XXXXXXXXXXXXXXXXX'  XXXXXXXXXXXXXXXXXX  XXXX                       --
--         XXXX                XXXX          XXXX  XXXX                       --
--         XXXXXXXXXXXXXXXXX.  XXXXXXXXXXXXXXXXXX  XXXX                       --
--         'XXXXXXXXXXXXXXXXX  XXXXXXXXXXXXXXXXX'  XXXX                       --
--                       XXXX  XXXX                XXXX                       --
--         .XXXXXXXXXXXXXXXXX  XXXX                XXXXXXXXXXXXXXXXX.         --
--         'XXXXXXXXXXXXXXXX'  'XX'                'XXXXXXXXXXXXXXXX'         --
--------------------------------------------------------------------------------
--             Copyright 2023 Vittorio Pascucci (SideProjectsLab)             --
--                                                                            --
-- Licensed under the GNU General Public License, Version 3 (the "License");  --
-- you may not use this file except in compliance with the License.           --
-- You may obtain a copy of the License at                                    --
--                                                                            --
--     https://www.gnu.org/licenses/gpl-3.0.en.html#license-text              --
--                                                                            --
-- Unless required by applicable law or agreed to in writing, software        --
-- distributed under the License is distributed on an "AS IS" BASIS,          --
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   --
-- See the License for the specific language governing permissions and        --
-- limitations under the License.                                             --
--------------------------------------------------------------------------------
--                                                                            --
-- Crucially, the ph0 signal LEADS slightly compared to the VIC clock, so     --
-- strobe-0 corresponds to the first half-cycle of the VIC clock where ph0    --
-- is zero for the entire time                                                --
--      ______________                 _______________                 _____  --
-- ph0                |_______________|               |_______________|       --
--          _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _     --
-- vic    _| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_   --
--                                                                            --
-- clk  _|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|  --
-- str                  0 1 2 3 4 5 6 7 8 9 A B C D E F 0                     --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

library work;
use     work.qol_pkg.all;
use     work.vic_pkg.all;


entity strobe is
port
(
	clk  : in  std_wire;
	rst  : in  std_wire;
	dot  : in  std_wire;
	ph0  : in  std_wire;
	strb : out t_strb
);
end entity;


architecture rtl of strobe is

	signal rst_1r : std_wire := '1';
	signal ph0_1r : std_wire;

begin

	i_strobe_gen : process(clk) is
	begin
		if rising_edge(clk) then

			-- we make sure that additional edges don't cause wraparounds
			if strb /= 0 then
				strb <= strb + 1;
			end if;

			-- we intentionally skip rising edges of the dot-clock to sample
			-- phi0 because phi0 edges are too close to dot-clock rising edges
			if (dot = '1') then
				ph0_1r <= ph0;
				if (ph0_1r = '1') and (ph0 = '0') then
					strb <= to_unsigned(1, strb'length);
				end if;
			end if;

			rst_1r <= rst;
			if rst_1r then
				ph0_1r <= '0';
				strb   <= (others => '0');
			end if;

		end if;
	end process;

end architecture;
