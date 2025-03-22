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


entity graphics_gen is
port
(
	clk    : in  std_wire;
	rst    : in  std_wire;

	reg    : in  t_regs;
	strb   : in  t_strb;

	i_actv : in  std_wire;
	i_grfx : in  std_word( 7 downto 0);
	i_data : in  std_word(11 downto 0);
	o_bgnd : out std_wire;
	o_colr : out t_colr;

	-- diagnostics & debug
	mark_mode : in  std_wire
);
end entity;


architecture rtl of graphics_gen is

	constant c_shreg_len : natural := 8;

	signal rst_1r    : std_wire := '1';

	signal shreg     : unsigned(c_shreg_len - 1 downto 0);
	signal xscroll   : natural range 0 to 7;

	signal actv_1r   : std_wire;
	signal actv_2r   : std_wire;

	signal grfx_1r   : i_grfx'subtype;
	signal grfx_2r   : i_grfx'subtype;

	signal data_1r   : i_data'subtype;
	signal data_2r   : i_data'subtype;
	signal data_3r   : i_data'subtype;
	signal mc_phy    : std_wire;
	signal bg_colr_1r : t_colr_vector(0 to 3);
	signal bg_colr_2r : t_colr_vector(0 to 3);

	signal ecm_1r     : std_wire;
	signal ecm_2r     : std_wire;
	signal ecm_3r     : std_wire;

	signal mcm_1r     : std_wire;
	signal mcm_2r     : std_wire;
	signal mcm_3r     : std_wire;

	signal bmm_1r     : std_wire;
	signal bmm_2r     : std_wire;
	signal bmm_3r     : std_wire;

	signal ecm        : std_wire;
	signal mcm        : std_wire;
	signal bmm        : std_wire;
	signal mcm_old    : std_wire;

	signal gfx_val    : unsigned(1 downto 0);
	signal gfx_bgnd   : std_wire;


	function get_mode(ecm : std_wire; bmm : std_wire; mcm : std_wire) return t_vic_mode is
		variable mode : std_word(2 downto 0) := ecm & bmm & mcm;
	begin
		case mode is
			when "000" =>
				return MODE_STD_TEXT;
			when "001" =>
				return MODE_MCL_TEXT;
			when "010" =>
				return MODE_STD_BMAP;
			when "011" =>
				return MODE_MCL_BMAP;
			when "100" =>
				return MODE_ECM_TEXT;
			when others =>
				return MODE_INVALID;
		end case;
	end function;

begin

	p_serialize : process(clk) is
		variable v_mode      : t_vic_mode;
		variable v_mc_flag   : std_wire;
		variable v_data_colr : i_data'subtype;
		variable v_gfx_colr  : t_colr_vector(0 to 3);
		variable v_gfx_val   : unsigned(1 downto 0);
		variable v_gfx_bgnd  : std_wire;
		variable v_bg_sel    : unsigned(1 downto 0);
	begin
		if rising_edge(clk) then

			if strb(0) = '1' then

				----------------------------------------------------------------
				--                   LATCHING NEW CHARACTER                   --
				----------------------------------------------------------------

				if strb = 15 then
					actv_2r <= actv_1r;
					grfx_2r <= grfx_1r;
					data_2r <= data_1r;

					if i_actv then
						xscroll <= to_integer(unsigned(reg(22)(2 downto 0)));
					end if;

					if i_actv then
						grfx_1r <= i_grfx;
						data_1r <= i_data;
						actv_1r <= i_actv;
					else
						data_1r <= (others => '0');
						actv_1r <= '0';
					end if;
				end if;

				----------------------------------------------------------------
				--                     LATCHING MODE FLAGS                    --
				----------------------------------------------------------------

				mc_phy <= not mc_phy;

				ecm_1r <= reg(17)(6);
				ecm_2r <= ecm_1r;
				ecm_3r <= ecm_2r;

				bmm_1r <= reg(17)(5);
				bmm_2r <= bmm_1r;
				bmm_3r <= bmm_2r;

				mcm_1r <= reg(22)(4);
				mcm_2r <= mcm_1r;
				mcm_3r <= mcm_2r;

				if strb = 1 then
					ecm <= ecm or ecm_3r;
					bmm <= bmm or bmm_3r;
				end if;

				if strb = 3 then
					ecm <= ecm and ecm_3r;
					bmm <= bmm and bmm_3r;
				end if;

				if strb = 9 then
					mcm <= mcm_3r;
				end if;

				if strb = 15 then
					mcm_old <= mcm;
					if mcm_old /= mcm then
						mc_phy <= '1';
					end if;
				end if;

				----------------------------------------------------------------
				--                   LOADING SHIFT REGISTER                   --
				----------------------------------------------------------------

				shreg <= lshift(shreg, 1);

				if rshift(strb, 1) = xscroll then
					if (actv_2r = '1') or (strb < 7) then
						mc_phy <= '0';
					end if;

					if actv_2r then
						data_3r           <= data_2r;
						shreg(7 downto 0) <= unsigned(grfx_2r);
					end if;
				end if;

				----------------------------------------------------------------
				--                      COLOR SELECTION                       --
				----------------------------------------------------------------

				bg_colr_1r(0) <= unsigned(reg(33)(3 downto 0));
				bg_colr_1r(1) <= unsigned(reg(34)(3 downto 0));
				bg_colr_1r(2) <= unsigned(reg(35)(3 downto 0));
				bg_colr_1r(3) <= unsigned(reg(36)(3 downto 0));
				bg_colr_2r <= bg_colr_1r;

				v_mc_flag := data_3r(11);

				if mcm_old then
					if bmm or v_mc_flag then
						if mc_phy = '0' then
							v_gfx_val  := rresize(shreg, 2);
							v_gfx_bgnd := not shreg(shreg'high);
						else
							v_gfx_val  := gfx_val;
							v_gfx_bgnd := gfx_bgnd;
						end if;
					else
						v_gfx_val  := (others => shreg(shreg'high));
						v_gfx_bgnd := not shreg(shreg'high);
					end if;
				else
					if bmm or v_mc_flag then
						v_gfx_val  := shreg(shreg'high) & '0';
						v_gfx_bgnd := not shreg(shreg'high);
					else
						v_gfx_val  := (others => shreg(shreg'high));
						v_gfx_bgnd := not shreg(shreg'high);
					end if;
				end if;

				-- saving former pixel values
				gfx_val  <= v_gfx_val;
				gfx_bgnd <= v_gfx_bgnd;

				-- color selection is based on current mode flags
				v_mode := get_mode(ecm, bmm, mcm);

				v_gfx_colr(0) := (others => '0');
				v_gfx_colr(1) := (others => '0');
				v_gfx_colr(2) := (others => '0');
				v_gfx_colr(3) := (others => '0');

				v_data_colr := data_3r;

				case v_mode is
					when MODE_STD_TEXT =>
						v_gfx_colr(0) := bg_colr_2r(0);
						v_gfx_colr(1) := bg_colr_2r(0);
						v_gfx_colr(2) := unsigned(v_data_colr(11 downto 8));
						v_gfx_colr(3) := unsigned(v_data_colr(11 downto 8));

					when MODE_MCL_TEXT =>
						if v_mc_flag then
							v_gfx_colr(0) := bg_colr_2r(0);
							v_gfx_colr(1) := bg_colr_2r(1);
							v_gfx_colr(2) := bg_colr_2r(2);
							v_gfx_colr(3) := '0' & unsigned(v_data_colr(10 downto 8));
						else
							v_gfx_colr(0) := bg_colr_2r(0);
							v_gfx_colr(1) := bg_colr_2r(0);
							v_gfx_colr(2) := '0' & unsigned(v_data_colr(10 downto 8));
							v_gfx_colr(3) := '0' & unsigned(v_data_colr(10 downto 8));
						end if;

					when MODE_STD_BMAP =>
						v_gfx_colr(0) := unsigned(v_data_colr(3 downto 0));
						v_gfx_colr(1) := unsigned(v_data_colr(3 downto 0));
						v_gfx_colr(2) := unsigned(v_data_colr(7 downto 4));
						v_gfx_colr(3) := unsigned(v_data_colr(7 downto 4));

					when MODE_MCL_BMAP =>
						v_gfx_colr(0) := bg_colr_2r(0);
						v_gfx_colr(1) := unsigned(v_data_colr( 7 downto 4));
						v_gfx_colr(2) := unsigned(v_data_colr( 3 downto 0));
						v_gfx_colr(3) := unsigned(v_data_colr(11 downto 8));

					when MODE_ECM_TEXT =>
						v_bg_sel      := unsigned(v_data_colr(7 downto 6));
						v_gfx_colr(0) := bg_colr_2r(to_integer(v_bg_sel));
						v_gfx_colr(1) := bg_colr_2r(to_integer(v_bg_sel));
						v_gfx_colr(2) := unsigned(v_data_colr(11 downto 8));
						v_gfx_colr(3) := unsigned(v_data_colr(11 downto 8));

					when others =>
						-- NOP
				end case;

				----------------------------------------------------------------
				--                           OUTPUT                           --
				----------------------------------------------------------------

				o_colr <= v_gfx_colr(to_integer(v_gfx_val));
				o_bgnd <= v_gfx_bgnd;


				if mark_mode then
					o_bgnd <= '0';

					case v_mode is
						when MODE_STD_TEXT =>
							o_colr <= x"0";     -- BLACK
						when MODE_MCL_TEXT =>
							if v_mc_flag then
								o_colr <= x"1"; -- WHITE
							else
								o_colr <= x"2"; -- RED
							end if;
						when MODE_STD_BMAP =>
							o_colr <= x"2";     -- CYAN
						when MODE_MCL_BMAP =>
							o_colr <= x"3";     -- PURPLE
						when MODE_ECM_TEXT =>
							o_colr <= x"4";     -- GREEN
						when others =>
							o_colr <= x"5";     -- BLUE
					end case;
				end if;

			end if;


			rst_1r <= rst;
			if rst_1r then

			end if;
		end if;
	end process;

end architecture;
