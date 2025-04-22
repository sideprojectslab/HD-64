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


package vic_pkg is

	constant c_xres_h63  : positive := 403;
	constant c_yres_h63  : positive := 284;

	constant c_num_regs  : positive := 64;
	constant c_max_xlen  : positive := 65 * 8;
	constant c_max_ylen  : positive := 312;

	constant c_xpos_bits : positive := bits_for_range(c_max_xlen);
	constant c_ypos_bits : positive := bits_for_range(c_max_ylen);
	constant c_ppos_bits : positive := maximum(c_xpos_bits, c_ypos_bits);

	subtype t_colr is unsigned(3 downto 0);
	subtype t_ppos is unsigned(c_ppos_bits - 1 downto 0);
	subtype t_addr is unsigned(5 downto 0);
	subtype t_strb is unsigned(3 downto 0);
	subtype t_regs is std_word_vector(0 to c_num_regs - 1) (7 downto 0);

	subtype t_colr_vector is unsigned_vector(open)(3 downto 0);

	function to_ppos(x : integer) return t_ppos;

	type t_vic_type is
	(
		vic_h63,
		vic_h64,
		vic_h65
	);


	type t_vic_mode is
	(
		mode_std_text,
		mode_mcl_text,
		mode_std_bmap,
		mode_mcl_bmap,
		mode_ecm_text,
		mode_invalid
	);


	-- this implementation

	type t_vic_specs is record
		tvic : t_vic_type;

		cycl : t_ppos; -- Number of characters (visible & invisible) in a line
		xref : t_ppos; -- x position for the synchronization cycle (end of RAM refresh for each line)
		xnul : t_ppos; -- x position of the first visible pixel (line start)
		xend : t_ppos; -- x position of the last visible pixel (line end)
		xlen : t_ppos; -- total pixels in a line (cycl * 8)
		xres : t_ppos; -- total visible pixels in a line
		xfvc : t_ppos; -- first pixel of active area
		xlvc : t_ppos; -- last pixel of active area

		yref : t_ppos; -- y position for the synchronization line (RAM refresh)
		ynul : t_ppos; -- y position of the first visible pixel
		yend : t_ppos; -- y position of the last visible pixel
		ylen : t_ppos; -- total lines in a frame
		yres : t_ppos; -- total visible lines in a frame
		yfvc : t_ppos; -- first line of active area
		ylvc : t_ppos; -- last line of active area

		sprt_dma1_cycl : t_ppos;
		sprt_dma2_cycl : t_ppos;
		sprt_yexp_cycl : t_ppos;
		sprt_disp_cycl : t_ppos;
		sprt_strt_cycl : t_ppos;
	end record;

	-- PAL with 63 lines
	constant c_vic_h63_specs : t_vic_specs :=
	(
		tvic => vic_h63,

		cycl => to_ppos(63),       -- number of character cycles in a line
		xref => to_ppos(16),       -- value of xpos on the 1st clock cycle of the 1st character access after the refresh pattern
		xnul => to_ppos(497 + 2),  -- solely needed to center the picture
		xend => to_ppos(389 + 2),  -- ((xnul + xres) % xlen) - 1
		xlen => to_ppos(504),      -- number of pixels in a line
		xres => to_ppos(396),      -- visible pixels in a line
		xfvc => to_ppos(24),       -- first video coordinate (after border)
		xlvc => to_ppos(24 + 319), -- last video coordinate  (before border)

		yref => to_ppos(0),
		ynul => to_ppos(10),
		yend => to_ppos(289),
		ylen => to_ppos(312),
		yres => to_ppos(280),
		yfvc => to_ppos(51),
		ylvc => to_ppos(51 + 199),

		sprt_dma1_cycl => to_ppos(54),
		sprt_dma2_cycl => to_ppos(55),
		sprt_yexp_cycl => to_ppos(55),
		sprt_disp_cycl => to_ppos(57),
		sprt_strt_cycl => to_ppos(57)
	);

	-- NTSC with 64 lines
	constant c_vic_h64_specs : t_vic_specs :=
	(

--          | Video  | # of  | Visible | Cycles/ |  Visible
--   Type   | system | lines |  lines  |  line   | pixels/line
-- ---------+--------+-------+---------+---------+------------
-- 6567R56A | NTSC-M |  262  |   234   |   64    |    411
--  6567R8  | NTSC-M |  263  |   235   |   65    |    418
--   6569   |  PAL-B |  312  |   284   |   63    |    403
--
--          | First  |  Last  |              |   First    |   Last
--          | vblank | vblank | First X coo. |  visible   |  visible
--   Type   |  line  |  line  |  of a line   |   X coo.   |   X coo.
-- ---------+--------+--------+--------------+------------+-----------
-- 6567R56A |   13   |   40   |  412 ($19c)  | 488 ($1e8) | 388 ($184)
--  6567R8  |   13   |   40   |  412 ($19c)  | 489 ($1e9) | 396 ($18c)
--   6569   |  300   |   15   |  404 ($194)  | 480 ($1e0) | 380 ($17c)

		tvic => vic_h64,

		cycl => to_ppos(64),
		xref => to_ppos(13),
		xnul => to_ppos(490 + 8),
		xend => to_ppos(388 + 8),
		xlen => to_ppos(512),
		xres => to_ppos(411),
		xfvc => to_ppos(21),
		xlvc => to_ppos(21 + 319),

		yref => to_ppos(0),
		ynul => to_ppos(32),
		yend => to_ppos(32 + 233),
		ylen => to_ppos(262),
		yres => to_ppos(234),
		yfvc => to_ppos(51), 
		ylvc => to_ppos(51 + 199),

		sprt_dma1_cycl => to_ppos(55),
		sprt_dma2_cycl => to_ppos(56),
		sprt_yexp_cycl => to_ppos(56),
		sprt_disp_cycl => to_ppos(57),
		sprt_strt_cycl => to_ppos(57)
	);

	-- NTSC with 65 lines
	constant c_vic_h65_specs : t_vic_specs :=
	(
		tvic => vic_h65,

		cycl => to_ppos(65),
		xref => to_ppos(16),
		xnul => to_ppos(505),
		xend => to_ppos(402), -- ((xnul + xres) % xlen) - 1
		xlen => to_ppos(520),
		xres => to_ppos(418),
		xfvc => to_ppos(24),
		xlvc => to_ppos(24 + 319),

		yref => to_ppos(0),
		ynul => to_ppos(33),
		yend => to_ppos(3),
		ylen => to_ppos(263),
		yres => to_ppos(235),
		yfvc => to_ppos(51),
		ylvc => to_ppos(51 + 199),

		sprt_dma1_cycl => to_ppos(55),
		sprt_dma2_cycl => to_ppos(56),
		sprt_yexp_cycl => to_ppos(56),
		sprt_disp_cycl => to_ppos(58),
		sprt_strt_cycl => to_ppos(58)
	);

	constant c_csmp_strb : t_strb := to_unsigned(6, 4);
	constant c_cycl_ref  : t_ppos := to_ppos(14); -- -1 from the docs because they start from 1... :(
	constant c_cycl_vend : t_ppos := to_ppos(54); -- like above :(
	constant c_cycle_yff : t_ppos := to_ppos(62); -- same same :(

	-- these are constants for accessing the system's register bus from the C64
	-- CPU and shall be replicated manually in the C64 code

	constant c_reg_code_idx : natural := 47;
	constant c_reg_trig_idx : natural := 48;

	constant c_reg_adr0_idx : natural := 49;
	constant c_reg_adr1_idx : natural := 50;
	constant c_reg_adr2_idx : natural := 51;
	constant c_reg_adr3_idx : natural := 52;

	constant c_reg_dat0_idx : natural := 53;
	constant c_reg_dat1_idx : natural := 54;
	constant c_reg_dat2_idx : natural := 55;
	constant c_reg_dat3_idx : natural := 56;

	constant c_ext_code : std_word_vector(0 to 5)(7 downto 0) :=
	(
		x"fe",
		x"ed",
		x"60",
		x"0d",
		x"f0",
		x"0d"
	);

end package;


package body vic_pkg is

	function to_ppos(x : integer) return t_ppos is
	begin
		return ltrim(unsigned(to_signed(x, t_ppos'length + 1)), 1);
	end function;

end package body;
