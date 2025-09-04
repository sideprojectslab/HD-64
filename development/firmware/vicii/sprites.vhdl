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


entity sprites is
port
(
	clk     : in  std_wire;
	rst     : in  std_wire;

	specs   : in  t_vic_specs;
	wrt     : in  std_word(t_regs'range);

	reg     : in  t_regs;
	strb    : in  t_strb;
	cycl    : in  t_ppos;
	xpos    : in  t_ppos;
	ypos    : in  t_ppos;

	enable  : in  std_word(7 downto 0);
	mark    : in  std_word(7 downto 0);
	enforce : in  std_word(7 downto 0);

	i_data  : in  std_word(7 downto 0);
	o_prio  : out std_wire;
	o_actv  : out std_wire;
	o_colr  : out t_colr
);
end entity;


architecture rtl of sprites is

	subtype t_xcount is natural range 0 to 24; -- generic counter
	type    t_xcount_vector is array(natural range <>) of t_xcount;

	subtype t_ycount is unsigned(5 downto 0);
	type    t_ycount_vector is array(natural range <>) of t_ycount;

	signal acquire    : std_wire;
	signal spen       : std_word(7 downto 0);
	signal prio       : std_word(7 downto 0);
	signal mxmc       : std_word(7 downto 0);
	signal xexp_1r    : std_word(7 downto 0);
	signal xexp_2r    : std_word(7 downto 0);
	signal xexp_3r    : std_word(7 downto 0);
	signal xexp_4r    : std_word(7 downto 0);
	signal yexp       : std_word(7 downto 0);
	signal yexp_1r    : std_word(7 downto 0);
	signal colr       : t_colr_vector(0 to 7);
	signal mclr       : t_colr_vector(0 to 1);
	signal sp_xpos    : unsigned_vector(0 to 8)(8 downto 0);
	signal sp_ypos    : unsigned_vector(0 to 8)(7 downto 0);

	signal xpos_1r    : t_ppos;
	signal xpos_2r    : t_ppos;
	signal xpos_3r    : t_ppos;
	signal xpos_4r    : t_ppos;
	signal xpos_5r    : t_ppos;
	signal xpos_6r    : t_ppos;

	signal ydisp      : unsigned(7 downto 0);
	signal ypend      : unsigned(7 downto 0);
	signal xdisp      : unsigned(7 downto 0);
	signal yincr      : unsigned(7 downto 0);
	signal xincr      : unsigned(7 downto 0);
	signal spdma      : unsigned(7 downto 0);

	signal count_sprt : integer range 0 to 7;
	signal count_data : integer range 0 to 3;
	signal count_mc   : t_ycount_vector(0 to 7);
	signal count_mb   : t_ycount_vector(0 to 7);
	signal count_xlen : t_xcount_vector(0 to 7);
	signal shreg      : unsigned_vector(0 to 7)(23 downto 0);
	signal sprt_val   : unsigned_vector(0 to 7)( 1 downto 0);
	signal mc_phy     : unsigned(7 downto 0);

	signal rst_1r     : std_wire := '1';

begin

	p_sprites : process(clk) is
		variable v_sprt_val : sprt_val'element'subtype;
	begin
		if rising_edge(clk) then

			--------------------------------------------------------------------
			-- these behave as sequential assignments as they operate on odd
			-- cycles too

			spen <=     reg(21);
			prio <= not reg(27);
			mxmc <=     reg(28);
			yexp <=     reg(23);

			for i in 0 to 7 loop
				colr   (i) <= unsigned(reg(39 + i)(3 downto 0));
				sp_ypos(i) <= unsigned(reg(i*2 + 1));
				sp_xpos(i) <= unsigned(reg(16)(i) & reg(i*2));
			end loop;

			mclr(0) <= unsigned(reg(37)(3 downto 0));
			mclr(1) <= unsigned(reg(38)(3 downto 0));

			--------------------------------------------------------------------
			-- rising edges of DOT clock

			if strb(0) then

				xpos_1r <= xpos;
				xpos_2r <= xpos_1r;
				xpos_3r <= xpos_2r;
				xpos_4r <= xpos_3r;
				xpos_5r <= xpos_4r;
				xpos_6r <= xpos_5r;

				xexp_1r  <= reg(29);
				xexp_2r  <= xexp_1r;
				xexp_3r  <= xexp_2r;
				xexp_4r  <= xexp_3r;


				o_actv <= '0';
				o_prio <= '0';

				-- looping over the sprites
				for i in 7 downto 0 loop

					------------------------------------------------------------
					--                    SPRITE PLAYBACK                     --
					------------------------------------------------------------

					-- horizontal trigger
					if ydisp(i) then
						if (xpos_6r = sp_xpos(i))
						then
							count_xlen(i) <= 0;
							xdisp (i)     <= '1';
							xincr (i)     <= not xexp_4r(i);
							mc_phy(i)     <= '0';
						end if;
					end if;

					-- execution
					if xdisp(i) then
						-- handle multi-color here
						if mxmc(i) then
							if mc_phy(i) = '0' then
								v_sprt_val := shreg(i)(23 downto 22);
							else
								v_sprt_val := sprt_val(i);
							end if;
						else
							v_sprt_val := shreg(i)(23) & '0';
						end if;

						sprt_val(i) <= v_sprt_val;

						-- selecting color and transparency
						if (v_sprt_val /= "00") and (enable(i) = '1') then
							o_actv <= '1';
							o_prio <= prio(i);
						end if;

						-- bringing sprites forward when marking
						if mark(i) then
							o_prio <= '1';
						end if;

						if v_sprt_val = "01" then
							o_colr <= mclr(0);
						elsif v_sprt_val = "10" then
							o_colr <= colr(i);
						elsif v_sprt_val = "11" then
							o_colr <= mclr(1);
						end if;

						if (count_xlen(i) = 23) and (xincr(i) = '1') then
							-- horizontal end of a sprite
							xdisp(i) <= '0';

						else
							if (xincr(i) = '1') then
								count_xlen(i) <= count_xlen(i) + 1;
								shreg(i)      <= lshift(shreg(i), 1);
								shreg(i)(0)   <= '0';
								mc_phy(i)     <= not mc_phy(i);
							end if;

							if xexp_4r(i) then
								xincr(i) <= not xincr(i);
							else
								xincr(i) <= '1';
							end if;
						end if;

						if mark(i) then
							if (count_xlen(i) = 0                            ) or
							   (count_xlen(i) = 23                           ) or
							   (((count_mc(i) = 3  ) or (count_mc(i) = 63  )) and
							    ((count_xlen(i) < 4) or (count_xlen(i) > 19)))
							then
								o_actv <= '1';
								o_prio <= '1';
								o_colr <= to_unsigned(i, 4);
							end if;
						end if;

					end if;

					------------------------------------------------------------
					--                    VERTICAL TRIGGER                    --
					------------------------------------------------------------

					if strb = 3 then

						yexp_1r(i) <= yexp(i);

						-- delaying display by one character cycle
						ydisp(i)   <= ypend(i) or enforce(i);

						if (yexp(i) = '0') and (yincr(i) = '0') then
							yincr(i) <= '1';
						end if;

						if ((cycl = specs.sprt_dma1_cycl)) then
							if (spdma(i) = '0') and (spen(i) = '1') and
							   (sp_ypos(i) = ypos(7 downto 0))
							then
								spdma(i)    <= '1';
								yincr(i)    <= '1';
								count_mb(i) <= (others => '0');
							end if;
						end if;

						if ((cycl = specs.sprt_dma2_cycl)) then
							if (spdma(i) = '0') and (spen(i) = '1') and
							   (sp_ypos(i) = ypos(7 downto 0))
							then
								spdma(i)    <= '1';
								yincr(i)    <= '1';
								count_mb(i) <= (others => '0');
							end if;
						end if;

						if (cycl = specs.sprt_yexp_cycl) then
							if (spdma(i) and yexp(i)) then
								yincr(i) <= not yincr(i);
							end if;
						end if;

						-- turning on the display
						if (cycl = specs.sprt_disp_cycl) then
							count_mc(i) <= count_mb(i);

							if (spdma(i) = '1') then
								if (sp_ypos(i) = ypos(7 downto 0)) and (spen(i) = '1') then
									ypend(i) <= '1';
								end if;
							else
								ypend(i) <= '0';
							end if;
						end if;

						-- updating MC
						if (cycl = 14) then
							-- doesn't really matter when we update the counter as long as it is
							-- after (if) the DMA has been turned on and before it is turned off
							count_mc(i) <= count_mc(i) + 3;
						end if;

						-- upddating MCBASE
						if (cycl = 15) then
							if yincr(i) = '1' then
								count_mb(i) <= count_mc(i);
							end if;

							-- handle sprite crunch
							if yincr(i) = '0' then
								if (spdma(i) = '1') and (yexp(i) = '0') and (yexp_1r(i) = '1') and (wrt(23) = '1') then
									count_mb(i) <= ("101010" and (count_mb(i) and count_mc(i))) or
									               ("010101" and (count_mb(i) or  count_mc(i)));
								end if;
							end if;
						end if;

						-- we could turn off the DMA anywhere between the update of mb and the
						-- check for start
						if (cycl = specs.sprt_dma1_cycl - 1) then
							if count_mb(i) = 63 then
								spdma(i) <= '0';
							end if;
						end if;
					end if;
				end loop;

				----------------------------------------------------------------
				--                     SPRITE ACQUISITION                     --
				----------------------------------------------------------------

				if (strb = 1) and (cycl = specs.sprt_strt_cycl) then
					-- initiate sprite data acquisition on all lines
					count_sprt <= 0;
					count_data <= 3;
					acquire    <= '1';
				end if;

				-- sprite data acquisition
				if acquire then
					if count_data /= 3 then
						-- holding the shift register while it's being filled
						shreg(count_sprt) <= shreg(count_sprt);
					end if;

					if (strb = 7) or (strb = 15) then
						if (count_data /= 3) then
							if count_data = 0 then
								shreg(count_sprt)(23 downto 16) <= unsigned(i_data(7 downto 0));
							end if;
							if count_data = 1 then
								shreg(count_sprt)(15 downto 8) <= unsigned(i_data(7 downto 0));
							end if;
							if count_data = 2 then
								shreg(count_sprt)(7 downto 0) <= unsigned(i_data(7 downto 0));
							end if;

							if (count_data = 2) then
								if (count_sprt = 7) then
									acquire <= '0';
								else
									count_sprt <= count_sprt + 1;
								end if;
							end if;

							count_data <= count_data + 1;
						else
							count_data <= 0;
						end if;
					end if;
				end if;

				----------------------------------------------------------------
				--                          OTHER                             --
				----------------------------------------------------------------

				if false then
					-- just marking a specific column
					if (strb = 1) and (cycl = specs.sprt_disp_cycl) then
						o_actv <= '1';
						o_prio <= '1';
						o_colr <= to_unsigned(1, 4);
					end if;
				end if;

			end if;


			rst_1r <= rst;
			if rst_1r then
				acquire <= '0';
				xdisp   <= (others => '0');
				ydisp   <= (others => '0');
				spdma   <= (others => '0');
			end if;

		end if;
	end process;

end architecture;
