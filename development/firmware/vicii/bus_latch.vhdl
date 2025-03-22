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
use     work.gp3r_pkg.all;
use     work.vic_pkg.all;

entity bus_latch is
generic
(
	g_enable : boolean := True
);
port
(
	clk      : in  std_wire; -- must be twice the video clock (16 times ph0)
	rst      : in  std_wire;

	-- VIC signals
	i_ph0    : in  std_wire;
	i_db     : in  std_word(11 downto 0);
	i_a      : in  t_addr;
	i_rw     : in  std_wire;
	i_cs     : in  std_wire;
	i_aec    : in  std_wire;

	o_ph0    : out std_wire;
	o_db     : out std_word(11 downto 0);
	o_a      : out t_addr;
	o_rw     : out std_wire;
	o_cs     : out std_wire;
	o_aec    : out std_wire
);
end entity;


architecture rtl of bus_latch is

	signal vector_in  : std_word(21 downto 0);
	signal vector_out : std_word(21 downto 0);

begin

	process(all) is
	begin
		vector_in <= i_ph0 & i_db & std_word(i_a) & i_rw & i_cs & i_aec;
		o_ph0     <= vector_out(21);
		o_db      <= vector_out(20 downto 9);
		o_a       <= unsigned(vector_out(8 downto 3));
		o_rw      <= vector_out(2);
		o_cs      <= vector_out(1);
		o_aec     <= vector_out(0);
	end process;


	i_multi_flop : entity work.multi_flop
	generic map
	(
		g_num_stages => switch(g_enable, 2, 0),
		g_input_reg  => false
	)
	port map
	(
		i_clk  => clk,
		i_rst  => rst,
		i_data => vector_in,

		o_clk  => clk,
		o_rst  => rst,
		o_data => vector_out
	);

end architecture;
