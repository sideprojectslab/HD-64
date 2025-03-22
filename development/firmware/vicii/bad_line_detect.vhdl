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

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

library work;
use     work.qol_pkg.all;
use     work.vic_pkg.all;


entity bad_line_detect is
port
(
	clk    : in  std_wire;
	rst    : in  std_wire;

	reg    : in  t_regs;
	aec    : in  std_wire;
	strb   : in  t_strb;
	cycl   : in  t_ppos;
	ypos   : in  t_ppos;
	bdln   : out std_wire;
	ccax   : out std_wire
);
end entity;


architecture rtl of bad_line_detect is

	signal rst_1r  : std_wire := '1';
	signal den     : std_wire;
	signal enable  : std_wire;
	signal yscroll : unsigned(2 downto 0);

begin

	yscroll <= unsigned(reg(17)(2 downto 0));
	den     <= reg(17)(4);

	p_detect : process(clk) is
		variable v_enable : std_wire;
	begin
		if rising_edge(clk) then

			v_enable := enable;

			if strb = 1 then
				if ((den = '1') and (ypos = 48)) then
					v_enable := '1';
				end if;

				if ypos >= 48 and ypos <= 247 then
					if (v_enable = '1') and (yscroll = ypos(2 downto 0)) then
						bdln <= '1';
					else
						bdln <= '0';
					end if;
				else
					bdln     <= '0';
					v_enable := '0';
				end if;
			end if;

			if (strb = 9) then
				if (cycl = c_cycl_ref - 1) then
					ccax <= '0';
				else
					ccax <= '0';
					if (ypos >= 48) and (ypos <= 247) and
					   (cycl >= c_cycl_ref) and (cycl < c_cycl_ref + 40)
					then
						ccax <= not aec;
					end if;
				end if;
			end if;

			enable <= v_enable;

			rst_1r <= rst;
			if rst_1r then
				bdln   <= '0';
				ccax   <= '0';
				enable <= '0';
			end if;

		end if;
	end process;

end architecture;
