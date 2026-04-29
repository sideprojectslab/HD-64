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


entity sync_flex is
port
(
	clk     : in  std_wire;
	rst     : in  std_wire;
	a       : in  t_addr;
	strb    : in  t_strb;

	enable  : in  std_wire;

	specs   : out t_vic_specs;
	lock    : out std_wire;
	cycl    : out t_ppos;
	xpos    : out t_ppos;
	ypos    : out t_ppos;

	dgn_out : out std_word(3 downto 0) := (others => '0')
);
end entity;


architecture rtl of sync_flex is

	signal h63_lock  : std_wire;
	signal h63_cycl  : t_ppos;
	signal h63_xpos  : t_ppos;
	signal h63_ypos  : t_ppos;

	signal h64_lock  : std_wire;
	signal h64_cycl  : t_ppos;
	signal h64_xpos  : t_ppos;
	signal h64_ypos  : t_ppos;

	signal h65_lock  : std_wire;
	signal h65_cycl  : t_ppos;
	signal h65_xpos  : t_ppos;
	signal h65_ypos  : t_ppos;

begin

	i_h63_sync : entity work.xy_sync
	port map
	(
		clk     => clk,
		rst     => rst,
		a       => a,
		strb    => strb,
		enable  => enable,
		specs   => c_vic_h63_specs,
		lock    => h63_lock,
		cycl    => h63_cycl,
		xpos    => h63_xpos,
		ypos    => h63_ypos,
		dgn_out => open --dgn_out
	);


	i_h64_sync : entity work.xy_sync
	port map
	(
		clk     => clk,
		rst     => rst,
		a       => a,
		strb    => strb,
		enable  => enable,
		specs   => c_vic_h64_specs,
		lock    => h64_lock,
		cycl    => h64_cycl,
		xpos    => h64_xpos,
		ypos    => h64_ypos,
		dgn_out => open --dgn_out
	);


	i_h65_sync : entity work.xy_sync
	port map
	(
		clk     => clk,
		rst     => rst,
		a       => a,
		strb    => strb,
		enable  => enable,
		specs   => c_vic_h65_specs,
		lock    => h65_lock,
		cycl    => h65_cycl,
		xpos    => h65_xpos,
		ypos    => h65_ypos,
		dgn_out => open --dgn_out
	);


	p_mux : process(all) is
	begin
		if (h63_lock = '1') then
			lock  <= h63_lock;
			cycl  <= h63_cycl;
			xpos  <= h63_xpos;
			ypos  <= h63_ypos;
			specs <= c_vic_h63_specs;

		elsif h64_lock then
			lock  <= h64_lock;
			cycl  <= h64_cycl;
			xpos  <= h64_xpos;
			ypos  <= h64_ypos;
			specs <= c_vic_h64_specs;

		elsif h65_lock then
			lock  <= h65_lock;
			cycl  <= h65_cycl;
			xpos  <= h65_xpos;
			ypos  <= h65_ypos;
			specs <= c_vic_h65_specs;

		else
			lock  <= '0';
			cycl  <= (others => '0');
			xpos  <= (others => '0');
			ypos  <= (others => '0');
			specs <= c_vic_h63_specs;
		end if;
	end process;

end architecture;
