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


entity graphics_mux is
generic
(
	g_mark_lines : boolean := false
);
port
(
	clk         : in  std_wire;
	rst         : in  std_wire;

	specs       : in  t_vic_specs;
	strb        : in  t_strb;
	i_xpos      : in  t_ppos;
	i_ypos      : in  t_ppos;
	i_bdln      : in  std_wire;

	i_mark_actv : in  std_wire;
	i_mark_colr : in  t_colr;

	i_bord_actv : in  std_wire;
	i_bord_colr : in  t_colr;

	i_grfx_colr : in  t_colr;
	i_grfx_bgnd : in  std_wire;

	i_sprt_actv : in  std_wire;
	i_sprt_prio : in  std_wire;
	i_sprt_colr : in  t_colr;

	o_push      : out std_wire;
	o_lstr      : out std_wire;
	o_lend      : out std_wire;
	o_fstr      : out std_wire;
	o_colr      : out t_colr;

	mark_bdln   : in  std_wire
);
end entity;


architecture rtl of graphics_mux is

	signal rst_1r : std_wire := '1';
	signal xval   : std_wire;
	signal yval   : std_wire;

	signal bord_actv_1r : std_wire;
	signal bord_actv_2r : std_wire;
	signal bord_actv_3r : std_wire;
	signal bord_actv_4r : std_wire;
	signal bord_actv_5r : std_wire;
	signal bord_actv_6r : std_wire;
	signal bord_actv_7r : std_wire;
	signal bord_actv_8r : std_wire;
	signal bord_actv_9r : std_wire;

	signal bord_colr_1r : t_colr;
	signal bord_colr_2r : t_colr;

	signal sprt_actv_1r : std_wire;
	signal sprt_actv_2r : std_wire;

	signal sprt_prio_1r : std_wire;
	signal sprt_prio_2r : std_wire;

	signal sprt_colr_1r : t_colr;
	signal sprt_colr_2r : t_colr;

begin

	o_push <= xval and yval and strb(0);

	p_mux : process(clk) is
	begin
		if rising_edge(clk) then

			if strb(0) = '0' then

				bord_actv_1r <= i_bord_actv;
				bord_actv_2r <= bord_actv_1r;
				bord_actv_3r <= bord_actv_2r;
				bord_actv_4r <= bord_actv_3r;
				bord_actv_5r <= bord_actv_4r;
				bord_actv_6r <= bord_actv_5r;
				bord_actv_7r <= bord_actv_6r;
				bord_actv_8r <= bord_actv_7r;
				bord_actv_9r <= bord_actv_8r;

				bord_colr_1r <= i_bord_colr;
				bord_colr_2r <= bord_colr_1r;

				sprt_actv_1r <= i_sprt_actv;
				sprt_actv_2r <= sprt_actv_1r;

				sprt_prio_1r <= i_sprt_prio;
				sprt_prio_2r <= sprt_prio_1r;

				sprt_colr_1r <= i_sprt_colr;
				sprt_colr_2r <= sprt_colr_1r;


				o_lstr <= '0';
				o_lend <= '0';

				if bord_actv_9r then
					o_colr <= bord_colr_2r;
				else
					if (sprt_actv_2r = '0') or ((sprt_prio_2r = '0') and (i_grfx_bgnd = '0')) then
						o_colr <= i_grfx_colr;
					else
						o_colr <= sprt_colr_2r;
					end if;
				end if;

				if i_mark_actv then
					o_colr <= i_mark_colr;
				end if;

				if g_mark_lines then
					if (i_xpos >= specs.xnul) and (i_xpos <= specs.xnul + 16) and
					   (i_ypos >= specs.ynul) and (i_ypos <= specs.yend     )
					then
						o_colr <= lresize(i_ypos, 4);
					end if;
				end if;

				-- marking badlines cyan
				if mark_bdln and i_bdln then
					o_colr <= x"3";
				end if;

				----------------------------------------------------------------
				--                   FRAME ALIGNMENT SIGNALS                  --
				----------------------------------------------------------------

				if (i_xpos = specs.xnul) then
					o_lstr <= '1';
					xval   <= '1';
					if (i_ypos = specs.ynul) then
						yval   <= '1';
						o_fstr <= '1';
					end if;
				end if;

				if (i_xpos = specs.xend) then
					o_lend <= '1';
				end if;

				if (i_xpos = specs.xend + 1) then
					xval   <= '0';
					o_fstr <= '0';
					if (i_ypos = specs.yend) then
						yval <= '0';
					end if;
				end if;
			end if;

			rst_1r <= rst;
			if rst_1r then
			end if;

		end if;
	end process;

end architecture;
