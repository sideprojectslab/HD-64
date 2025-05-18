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


entity border is
port
(
	clk    : in  std_wire;
	rst    : in  std_wire;

	strb   : in  t_strb;
	specs  : in  t_vic_specs;
	cycl   : in  t_ppos;
	xpos   : in  t_ppos;
	ypos   : in  t_ppos;
	reg    : in  t_regs;

	o_vbrd : out std_wire;
	o_bord : out std_wire;
	o_colr : out t_colr;

	enable : in  std_word(1 downto 0);

	mark_bord : out std_wire;
	mark_colr : out t_colr
);
end entity;


architecture rtl of border is

	signal rst_1r   : std_wire := '1';

	signal ff_main  : std_wire;
	signal ff_vert  : std_wire;

	signal edge_ll  : t_ppos;
	signal edge_rr  : t_ppos;
	signal edge_hi  : t_ppos;
	signal edge_lo  : t_ppos;

	signal reg_rsel : std_wire;
	signal reg_csel : std_wire;

	signal reg_rsel_1r : std_wire;
	signal reg_csel_1r : std_wire;

	alias  reg_ec   : std_word is reg(32)(3 downto 0);
	alias  reg_den  : std_wire is reg(17)(4);

begin

	process(all) is
	begin
		reg_rsel <= reg(17)(3);
		reg_csel <= reg(22)(3);

		if enable = "01" then
			-- force wide border
			reg_rsel <= '1';
			reg_csel <= '1';
		elsif enable = "10" then
			-- force narrow border
			reg_rsel <= '0';
			reg_csel <= '0';
		end if;
	end process;

	edge_ll <= specs.xfvc + 7 when (reg_csel = '0') else specs.xfvc;
	edge_rr <= specs.xlvc - 8 when (reg_csel = '0') else specs.xlvc + 1;
	edge_hi <= specs.yfvc + 4 when (reg_rsel = '0') else specs.yfvc;
	edge_lo <= specs.ylvc - 3 when (reg_rsel = '0') else specs.ylvc + 1;

	P_border : process(clk) is
		variable v_ff_main : std_wire;
		variable v_ff_vert : std_wire;
	begin
		if rising_edge(clk) then

			v_ff_main := ff_main;
			v_ff_vert := ff_vert;

			if strb(0) = '1' then
				-- vertical ff control
				if (cycl = c_cycle_yff) then
					if (ypos = edge_lo) then
						v_ff_vert := '1';
					end if;
					if (ypos = edge_hi) and (reg_den = '1') then
						v_ff_vert := '0';
					end if;
				end if;

				if (xpos = edge_ll) then
					if (ypos = edge_lo) then
						v_ff_vert := '1';
					end if;
					if (ypos = edge_hi) and (reg_den = '1') then
						v_ff_vert := '0';
					end if;
				end if;

				-- main ff control
				if (xpos = edge_rr) then
					v_ff_main := '1';
				end if;
				if (xpos = edge_ll) and (v_ff_vert = '0') then
					v_ff_main := '0';
				end if;

				o_bord <= v_ff_main;
				o_vbrd <= v_ff_vert;
				o_colr <= t_colr(reg_ec);

				ff_vert <= v_ff_vert;
				ff_main <= v_ff_main;

				-- turning off border
				if enable = "00" then
					o_bord <= '0';
				end if;

				-- marking csel and rsel changes (opening border)
				reg_csel_1r <= reg_csel;
				reg_rsel_1r <= reg_rsel;

				mark_bord <= '0';
				if reg_csel_1r /= reg_csel then
					mark_bord <= '1';
					mark_colr <= x"d"; -- LIGHT GREEN
				end if;

				if reg_rsel_1r /= reg_rsel then
					mark_bord <= '1';
					mark_colr <= x"4"; -- PURPLE
				end if;

			end if;

			rst_1r <= rst;
			if rst_1r then
				ff_main <= '0';
				ff_vert <= '0';
			end if;

		end if;
	end process;

end architecture;
