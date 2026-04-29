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


entity dot_clock is
generic
(
	g_clk_frq : real
);
port
(
	clk   : in  std_wire;
	rst   : in  std_wire;

	i_phi   : in  std_wire;
	o_dot   : out std_wire;
	o_phi   : out std_wire;
	o_clk   : out std_wire
);
end entity;


architecture rtl of dot_clock is

	function calc_toggle_times(i_phi_frq : real; sys_frq : real; mult : positive)
	return integer_vector is
		variable ret : integer_vector(0 to mult * 2 - 1);
	begin
		for i in 0 to ret'length - 2 loop
			ret(i) := integer(round(((sys_frq / i_phi_frq) / real(ret'length)) * real(i + 1)));
		end loop;
		ret(ret'length - 1) := 0;
		return ret;
	end function;

	constant c_mult         : positive := 16;
	constant c_i_phi_frq_pal  : real := 0.985e6;
	constant c_i_phi_frq_ntsc : real := 1.023e6;

	constant c_max_prd_pal   : integer := integer(ceil(g_clk_frq / c_i_phi_frq_pal));
	constant c_max_prd_ntsc  : integer := integer(ceil(g_clk_frq / c_i_phi_frq_ntsc));
	constant c_prd_thr       : integer := (c_max_prd_pal + c_max_prd_ntsc) / 2;
	constant c_max_prd       : integer := c_max_prd_pal;
	constant c_toggle_pal    : integer_vector := calc_toggle_times(c_i_phi_frq_pal , g_clk_frq, c_mult);
	constant c_toggle_ntsc   : integer_vector := calc_toggle_times(c_i_phi_frq_ntsc, g_clk_frq, c_mult);

	signal rst_1r     : std_wire := '1';
	signal i_phi_mf   : std_wire;
	signal i_phi_1r   : std_wire;
	signal prd        : natural range 0 to c_max_prd;
	signal toggle     : c_toggle_pal'subtype;
	signal toggle_val : integer range 0 to c_max_prd;
	signal count      : natural range 0 to toggle'length;

begin

	i_i_phi_mf : entity work.multi_flop
	generic map
	(
		g_num_stages => 5
	)
	port map
	(
		i_data(0) => i_phi,
		o_clk     => clk,
		o_rst     => rst,
		o_data(0) => i_phi_mf
	);

	o_phi <= i_phi_mf;

	p_dot_clock : process(clk) is
	begin
		if rising_edge(clk) then

			if prd = toggle_val then
				o_clk      <= not o_clk;
				count      <= count + 1; -- cannot wrap because the last element of the toggle array is zero
				toggle_val <= toggle(count);

				-- the "dot"
				if o_clk = '1' then
					o_dot <= not o_dot;
				end if;
			end if;

			-- calculating the period
			if prd /= c_max_prd then
				prd <= prd + 1;
			end if;

			i_phi_1r <= i_phi_mf;
			if (i_phi_1r = '1') and (i_phi_mf = '0') then
				prd   <= 1;
				o_clk <= '1';
				o_dot <= '0';
				count <= 1;

				if prd > c_prd_thr then
					toggle     <= c_toggle_pal;
					toggle_val <= c_toggle_pal(0);
				else
					toggle     <= c_toggle_ntsc;
					toggle_val <= c_toggle_ntsc(0);
				end if;
			end if;

			rst_1r <= rst;
			if rst_1r then
				prd      <= 0;
				i_phi_1r <= '0';
				o_dot    <= '0';
				o_clk    <= '0';
			end if;
		end if;
	end process;

end architecture;
