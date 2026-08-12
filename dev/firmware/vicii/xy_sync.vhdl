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


entity xy_sync is
port
(
	clk     : in  std_wire;
	rst     : in  std_wire;
	a       : in  t_addr;
	strb    : in  t_strb;

	enable  : in  std_wire;
	specs   : in  t_vic_specs;

	lock    : out std_wire;
	cycl    : out t_ppos;
	xpos    : out t_ppos;
	ypos    : out t_ppos;

	dgn_out : out std_word(3 downto 0) := (others => '0')
);
end entity;


architecture rtl of xy_sync is

	constant c_unlock_cycles : natural := 3;

	type t_state is
	(
		st_unlocked,
		st_llocking,
		st_llocked,
		st_locked
	);

	signal rst_1r       : std_wire := '1';
	signal state        : t_state;
	signal shreg        : unsigned(9 downto 0);
	signal shreg_old    : shreg'subtype;
	signal refpat       : shreg'subtype;
	signal count_unlock : natural range 0 to c_unlock_cycles;
	signal cycl_i       : t_ppos;

	signal ypos_i       : t_ppos;

	function is_refresh(shreg : unsigned) return boolean is
	begin
		return (shreg = "1110010011") or
			   (shreg = "1001001110") or
			   (shreg = "0100111001") or
			   (shreg = "0011100100");
	end function;

begin

	shreg <= ltrim(shreg_old, 2) & lresize(a, 2);
	lock  <= '1' when state = st_locked else '0';

	p_xy_pos : process(clk) is
	begin
		if rising_edge(clk) then
			if (strb = 1) and (enable = '1') then

				shreg_old <= shreg;

				if (cycl_i < specs.cycl - 1) then
					cycl_i <= cycl_i + 1;
				else
					cycl_i <= (others => '0');

					if (ypos_i < specs.ylen - 1) then
						ypos_i <= ypos_i + 1;
					else
						ypos_i <= (others => '0');
					end if;
				end if;


				if (cycl_i = c_cycl_ref) then

					-- always checking for cycl_i allows us to scan the line one
					-- character-cycle at a time, thus guaranteeing a finite
					-- lock time

					case state is
						when st_unlocked =>
							if is_refresh(shreg) then
								state  <= st_llocking;
								refpat <= ltrim(shreg, 2) & shreg(7 downto 6);
							else
								-- skip a cycle and try again
								cycl_i <= c_cycl_ref + 2;
							end if;

						when st_llocking =>
							if (shreg = refpat) then
							--if is_refresh(shreg) then
								state        <= st_llocked;
								count_unlock <= c_unlock_cycles;
								refpat       <= ltrim(shreg, 2) & shreg(7 downto 6);
							else
								-- skip a cycle and start over
								state  <= st_unlocked;
								cycl_i <= c_cycl_ref + 2;
							end if;

						when st_llocked =>
							if (shreg = "1111111111") then
								state        <= st_locked;
								ypos_i       <= specs.ylen - 1;
								refpat       <= "1110010011";
								count_unlock <= c_unlock_cycles;

							elsif (shreg = refpat) then
							--elsif is_refresh(shreg) then
								refpat       <= ltrim(refpat, 2) & refpat(7 downto 6);
								count_unlock <= c_unlock_cycles;

							elsif count_unlock /= 0 then
								refpat       <= ltrim(refpat, 2) & refpat(7 downto 6);
								count_unlock <= count_unlock - 1;

							else
								-- skip a cycle and start over
								state  <= st_unlocked;
								cycl_i <= c_cycl_ref + 2;
							end if;

						when st_locked =>
							if (ypos_i = specs.ylen - 1) then
								if (shreg = "1111111111") then
									refpat       <= "1110010011";
									count_unlock <= c_unlock_cycles;

								elsif count_unlock /= 0 then
									refpat       <= "1110010011";
									count_unlock <= count_unlock - 1;

								else
									-- skip a cycle and start over
									state  <= st_unlocked;
									cycl_i <= c_cycl_ref + 2;
								end if;

							else
								if (shreg = refpat) then
								--if is_refresh(shreg) then
									refpat       <= ltrim(refpat, 2) & refpat(7 downto 6);
									count_unlock <= c_unlock_cycles;

								elsif count_unlock /= 0 then
									count_unlock <= count_unlock - 1;
									refpat       <= ltrim(refpat, 2) & refpat(7 downto 6);

								else
									-- skip a cycle and start over
									state  <= st_unlocked;
									cycl_i <= c_cycl_ref + 2;
								end if;
							end if;

						when others =>
					end case;
				end if;
			end if;


			-- advancing the pixel counter on odd strobe cycles
			if (strb(0) = '1') then
				if (xpos < specs.xlen - 1) then
					xpos <= xpos + 1;
				else
					xpos <= to_ppos(0);
				end if;
			end if;

			-- position outputs are latched on the last strobe of a character
			-- cycle, so that they are constant and correct during the whole
			-- cycle
			if (strb = 15) then
				-- cycl_i already contains the next cycle index
				cycl <= cycl_i;

				-- y coordinate cycles automatically
				if (cycl_i = 0) then
					if (ypos < specs.ylen - 1) then
						ypos <= ypos + 1;
					else
						ypos <= to_ppos(0);
					end if;
				end if;

				-- on the reference cycle we re-synchronize all counters with
				-- appropriate offsets
				if (cycl_i = c_cycl_ref + 1) then
					xpos <= specs.xref;

					if (ypos_i = 0) then
						ypos <= specs.yref;
					end if;
				end if;
			end if;


			rst_1r <= rst;
			if (rst_1r = '1') then
				state     <= st_unlocked;
				shreg_old <= (others => '0');
				cycl_i    <= (others => '0');
				ypos_i    <= (others => '0');
			end if;

		end if;

	end process;

end architecture;
