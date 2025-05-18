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


entity registers is
generic
(
	g_ext_code_tail : std_word_vector(open)(7 downto 0)
);
port
(
	clk     : in  std_wire;
	rst     : in  std_wire;

	-- gp3r master
	o_req   : out t_gp3r_req;
	o_rsp   : in  t_gp3r_rsp;

	strb    : in  t_strb;
	db      : in  std_word(11 downto 0);
	a       : in  unsigned(5 downto 0);
	rw      : in  std_wire;
	cs      : in  std_wire;

	reg     : out t_regs;
	wrt     : out std_word(t_regs'range);
	gdot_en : in  std_wire
);
end entity;


architecture rtl of registers is

	constant c_code_len : positive := c_ext_code'length + g_ext_code_tail'length;
	constant c_code     : std_word_vector(0 to c_code_len - 1) := c_ext_code & g_ext_code_tail;

	signal rst_1r : std_wire := '1';
	signal enable : boolean;
	signal cs_1r  : std_wire;

	signal wen    : boolean;
	signal a_tmp  : a'subtype;
	signal d_tmp  : std_word(7 downto 0);

	signal reg_addr : std_word(31 downto 0);
	signal reg_data : std_word(31 downto 0);

	signal ext_enable : boolean;
	signal count_code : natural range 0 to c_code'length - 1;

	signal reg_i : t_regs;

begin

	reg_addr <= swap_endianness(merge(reg(c_reg_adr0_idx to c_reg_adr3_idx)));
	reg_data <= swap_endianness(merge(reg(c_reg_dat0_idx to c_reg_dat3_idx)));

	p_regs : process(clk) is
	begin
		if rising_edge(clk) then

			cs_1r <= cs;

			if (cs and cs_1r) then
				enable <= true;
			end if;

			-- handshake for the output master bus
			if (o_rsp.read = '1') then
				o_req.push <= '0';
			end if;

			o_req.read <= o_rsp.push;
			o_req.r_nw <= '0';

			-- latching register value and operating master bus
			if (strb = 10) then
				a_tmp <= a;
				wrt <= (others => '0');

				if (cs = '0') and (rw = '0') and enable then
					wen <= true;
					wrt(to_integer(a)) <= '1';
				end if;
			end if;

			if strb = 14 then
				d_tmp <= db(7 downto 0);
			end if;


			if (strb = 15) then
				if wen then
					wen <= false;
					reg  (to_integer(a_tmp)) <= d_tmp;
					reg_i(to_integer(a_tmp)) <= d_tmp;

					-- the VIC contains 47 valid 8-bit registers [0:46] the rest
					-- are used by the CPU to establish a write-only connection to
					-- the HD-64 register bus. The connection does not support
					-- backpressure

					-- first of all, we run a simple state machine that verifies
					-- the special code necessary to enable the extended registes

					if (a_tmp = c_reg_code_idx) then
						if (d_tmp = c_code(count_code)) then
							if (count_code = c_code_len - 1) then
								ext_enable <= true;
							else
								count_code <= count_code + 1;
							end if;
						else
							count_code <= 0;
						end if;
					end if;

					-- then we run a simple gp3r_master that writes to the bus
					-- whenever a write is performed to the trigger register

					if (a_tmp = c_reg_trig_idx) and ext_enable then
						if (o_req.push = '0') or (o_rsp.read = '1') then
							o_req.push <= '1';
							o_req.addr <= vlresize(to_gp3r_addr(unsigned(reg_addr)), o_req.addr'length);
							o_req.data <= vlresize(to_gp3r_data(reg_data), o_req.data'length);
						end if;
					end if;
				end if;
			end if;

			----------------------------------------------------------------
			--                        GREY DOT BUG                        --
			----------------------------------------------------------------

			if strb(0) then
				-- aligned to strb=14 because it operates on all clock cycles
				if (gdot_en = '1') then
					for i in 32 to 46 loop
						if (wrt(i) = '1') then
							if (strb = 13) then
								-- overriding with grey, will get re-overwritten
								-- on the next odd cycle
								reg(i)(3 downto 0) <= x"f";
							end if;
						end if;
					end loop;
				end if;
			end if;


			rst_1r <= rst;
			if rst_1r then
				enable     <= false;
				wen        <= false;
				wrt        <= (others => '0');
				cs_1r      <= '1';
				ext_enable <= false;
				count_code <= 0;
			end if;
		end if;
	end process;

end architecture;
