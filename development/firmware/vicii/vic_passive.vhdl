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
use     work.memmap_vicii_pkg.all;


entity vic_passive is
generic
(
	g_ext_code_tail : std_word_vector(open)(7 downto 0);
	g_log_only : boolean := false
);
port
(
	-- VIC signals
	clk          : in  std_wire; -- must be twice the video clock (16 times ph0)
	rst          : in  std_wire;
	dot          : in  std_wire;

	-- gp3r master
	o_req        : out t_gp3r_req;
	o_rsp        : in  t_gp3r_rsp;

	-- gp3r_slave
	i_req        : in  t_gp3r_req;
	i_rsp        : out t_gp3r_rsp;

	-- vic detection
	vic_type     : out t_vic_type;

	-- memory bus
	ph0          : in  std_wire;
	db           : in  std_word(11 downto 0);
	a            : in  t_addr;
	rw           : in  std_wire;
	cs           : in  std_wire;
	aec          : in  std_wire;

	o_push       : out std_wire;
	o_lstr       : out std_wire;
	o_fstr       : out std_wire;
	o_lend       : out std_wire;
	o_colr       : out t_colr;

	-- feature switches
	gdot_en      : in  std_wire;

	-- diagnostics
	sprt_en      : in  std_word(7 downto 0) := (others => '1');
	bord_en      : in  std_word(1 downto 0) := (others => '1');
	idle_en      : in  std_wire := '1';
	mark_mode    : in  std_wire := '0';
	mark_bdln    : in  std_wire := '0';
	mark_sprt    : in  std_word(7 downto 0) := (others => '0');
	lock         : out std_wire
);
end entity;


architecture rtl of vic_passive is

	signal req_bus_logger : t_gp3r_req_tpl := c_gp3r_req_tpl;
	signal rsp_bus_logger : t_gp3r_rsp_tpl := c_gp3r_rsp_tpl;

	signal mf_ph0  : ph0'subtype;
	signal mf_db   : db 'subtype;
	signal mf_a    : a  'subtype;
	signal mf_rw   : rw 'subtype;
	signal mf_cs   : cs 'subtype;
	signal mf_aec  : aec'subtype;

	signal reg   : t_regs;
	signal wrt   : std_word(t_regs'range);
	signal strb  : t_strb;
	signal specs : t_vic_specs;
	signal cycl  : t_ppos;
	signal bdln  : std_wire;
	signal ccax  : std_wire;
	signal xpos  : t_ppos;
	signal ypos  : t_ppos;

	signal cc_vm     : db'subtype;
	signal gg_vm     : std_word(7 downto 0);
	signal grfx_actv : std_wire;
	signal vbrd_actv : std_wire;
	signal bord_actv : std_wire;
	signal bord_colr : t_colr;

	signal mark_actv : std_wire := '0';
	signal mark_colr : t_colr   := x"0";

	signal grfx_colr : t_colr;
	signal grfx_bgnd : std_wire;

	signal sprt_actv : std_wire;
	signal sprt_prio : std_wire;
	signal sprt_colr : t_colr;

begin

	vic_type <= specs.tvic;

	i_bus_latch : entity work.bus_latch
	generic map
	(
		g_enable => false
	)
	port map
	(
		clk   => clk,
		rst   => rst,

		i_ph0 => ph0,
		i_db  => db ,
		i_a   => a  ,
		i_rw  => rw ,
		i_cs  => cs ,
		i_aec => aec,

		o_ph0 => mf_ph0,
		o_db  => mf_db ,
		o_a   => mf_a  ,
		o_rw  => mf_rw ,
		o_cs  => mf_cs ,
		o_aec => mf_aec
	);


	i_strobe : entity work.strobe
	port map
	(
		clk  => clk,
		rst  => rst,
		dot  => dot,
		ph0  => mf_ph0,
		strb => strb
	);


	i_registers : entity work.registers
	generic map
	(
		g_ext_code_tail => g_ext_code_tail
	)
	port map
	(
		-- VIC signals
		clk     => clk,
		rst     => rst,

		o_req   => o_req,
		o_rsp   => o_rsp,

		strb    => strb,
		db      => mf_db ,
		a       => mf_a  ,
		rw      => mf_rw ,
		cs      => mf_cs ,
		reg     => reg,
		wrt     => wrt,
		gdot_en => gdot_en
	);


	i_frame_sync : entity work.sync_flex
	port map
	(
		clk     => clk,
		rst     => rst,
		a       => mf_a,
		strb    => strb,
		enable  => '1',
		specs   => specs,
		lock    => lock,
		cycl    => cycl,
		xpos    => xpos,
		ypos    => ypos,
		dgn_out => open --dgn_out
	);


	r_graphics : if not g_log_only generate

		------------------------------------------------------------------------
		--                         BADLINE DETECTION                          --
		------------------------------------------------------------------------

		i_bdln_detect : entity work.bad_line_detect
		port map
		(
			clk    => clk,
			rst    => rst,
			reg    => reg,
			aec    => mf_aec,
			strb   => strb,
			cycl   => cycl,
			ypos   => ypos,
			bdln   => bdln,
			ccax   => ccax
		);

		------------------------------------------------------------------------
		--                            VIDEO MATRIX                            --
		------------------------------------------------------------------------

		i_video_matrix : entity work.video_matrix
		port map
		(
			clk     => clk,
			rst     => rst,
			strb    => strb,
			cycl    => cycl,
			bdln    => bdln,
			ccax    => ccax,
			ypos    => ypos,
			specs   => specs,
			i_db    => mf_db,
			o_cc    => cc_vm,
			o_gg    => gg_vm,
			o_en    => grfx_actv,
			idle_en => idle_en
		);

		------------------------------------------------------------------------
		--                         GRAPHICS GENERATOR                         --
		------------------------------------------------------------------------

		i_graphics_gen : entity work.graphics_gen
		port map
		(
			clk       => clk,
			rst       => rst,
			reg       => reg,
			strb      => strb,
			i_actv    => grfx_actv,
			i_vbrd    => vbrd_actv,
			i_grfx    => gg_vm,
			i_data    => cc_vm,
			o_bgnd    => grfx_bgnd,
			o_colr    => grfx_colr,

			mark_mode => mark_mode
		);

		------------------------------------------------------------------------
		--                          BORDER GENERATOR                          --
		------------------------------------------------------------------------

		i_border : entity work.border
		port map
		(
			clk    => clk,
			rst    => rst,
			strb   => strb,
			specs  => specs,
			cycl   => cycl,
			xpos   => xpos,
			ypos   => ypos,
			reg    => reg,
			o_vbrd => vbrd_actv,
			o_bord => bord_actv,
			o_colr => bord_colr,
			enable => bord_en

--			-- marking border events
--			mark_bord => mark_actv,
--			mark_colr => mark_colr
		);

		------------------------------------------------------------------------
		--                          SPRITE GENERATOR                          --
		------------------------------------------------------------------------

		i_sprites : entity work.sprites
		port map
		(
			clk     => clk,
			rst     => rst,
			specs   => specs,
			reg     => reg,
			wrt     => wrt,
			strb    => strb,
			cycl    => cycl,
			xpos    => xpos,
			ypos    => ypos,
			enable  => sprt_en,
			mark    => mark_sprt,

			i_data  => mf_db(7 downto 0),
			o_prio  => sprt_prio,
			o_actv  => sprt_actv,
			o_colr  => sprt_colr
		);

		------------------------------------------------------------------------
		--                        GRAPHICS MULTIPLEXER                        --
		------------------------------------------------------------------------

		i_graphics_mux : entity work.graphics_mux
		generic map
		(
			g_mark_lines => false
		)
		port map
		(
			clk         => clk,
			rst         => rst,
			specs       => specs,
			strb        => strb,
			i_bdln      => bdln,
			i_xpos      => xpos,
			i_ypos      => ypos,

			i_mark_actv => mark_actv,
			i_mark_colr => mark_colr,

			i_bord_actv => bord_actv,
			i_bord_colr => bord_colr,

			i_sprt_actv => sprt_actv,
			i_sprt_prio => sprt_prio,
			i_sprt_colr => sprt_colr,

			i_grfx_colr => grfx_colr,
			i_grfx_bgnd => grfx_bgnd,

			o_push      => o_push,
			o_lstr      => o_lstr,
			o_lend      => o_lend,
			o_fstr      => o_fstr,
			o_colr      => o_colr,

			mark_bdln   => mark_bdln
		);


		-- dummy to terminate the logger bus
		i_nack : entity work.gp3r_dummy
		generic map
		(
			g_nack => c_gp3r_nack_addr
		)
		port map
		(
			clk  => clk,
			rst  => rst,
			req  => i_req,
			rsp  => i_rsp
		);

	else generate

		i_bus_logger : entity work.bus_logger
		generic map
		(
			g_enable => false
		)
		port map
		(
			clk      => clk,
			rst      => rst,
			req      => req_bus_logger,
			rsp      => rsp_bus_logger,
			xpos     => xpos,
			ypos     => ypos,
			strb     => strb,
			ph0      => mf_ph0,
			db       => mf_db,
			a        => mf_a,
			rw       => mf_rw,
			cs       => mf_cs,
			aec      => mf_aec
		);


		i_memmap_vicii : entity work.memmap_vicii
		port map
		(
			clk            => clk,
			rst            => rst,
			req            => i_req,
			rsp            => i_rsp,
			req_bus_logger => req_bus_logger,
			rsp_bus_logger => rsp_bus_logger,
			reg_0          => reg(0 ),
			reg_1          => reg(1 ),
			reg_2          => reg(2 ),
			reg_3          => reg(3 ),
			reg_4          => reg(4 ),
			reg_5          => reg(5 ),
			reg_6          => reg(6 ),
			reg_7          => reg(7 ),
			reg_8          => reg(8 ),
			reg_9          => reg(9 ),
			reg_10         => reg(10),
			reg_11         => reg(11),
			reg_12         => reg(12),
			reg_13         => reg(13),
			reg_14         => reg(14),
			reg_15         => reg(15),
			reg_16         => reg(16),
			reg_17         => reg(17),
			reg_18         => reg(18),
			reg_19         => reg(19),
			reg_20         => reg(20),
			reg_21         => reg(21),
			reg_22         => reg(22),
			reg_23         => reg(23),
			reg_24         => reg(24),
			reg_25         => reg(25),
			reg_26         => reg(26),
			reg_27         => reg(27),
			reg_28         => reg(28),
			reg_29         => reg(29),
			reg_30         => reg(30),
			reg_31         => reg(31),
			reg_32         => reg(32),
			reg_33         => reg(33),
			reg_34         => reg(34),
			reg_35         => reg(35),
			reg_36         => reg(36),
			reg_37         => reg(37),
			reg_38         => reg(38),
			reg_39         => reg(39),
			reg_40         => reg(40),
			reg_41         => reg(41),
			reg_42         => reg(42),
			reg_43         => reg(43),
			reg_44         => reg(44),
			reg_45         => reg(45),
			reg_46         => reg(46)
		);

	end generate;

end architecture;
