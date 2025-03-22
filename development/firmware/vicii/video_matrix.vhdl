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


entity video_matrix is
generic
(
	g_mark_bdln : boolean := false
);
port
(
	clk     : in  std_wire;
	rst     : in  std_wire;

	strb    : in  t_strb;
	cycl    : in  t_ppos;
	bdln    : in  std_wire;
	ccax    : in  std_wire;
	ypos    : in  t_ppos;
	specs   : in  t_vic_specs;

	i_db    : in  std_word(11 downto 0);
	o_cc    : out std_word(11 downto 0); -- color info
	o_gg    : out std_word( 7 downto 0); -- graphics info
	o_en    : out std_wire;

	idle_en : in  std_wire := '1'
);
end entity;


architecture rtl of video_matrix is

	constant c_ram_len   : positive := 40;
	constant c_ram_width : positive := i_db'length;
	constant c_addr_bits : positive := bits_for_range(c_ram_len);

	signal rst_1r   : std_wire := '1';
	signal ram_wadd : unsigned(c_addr_bits - 1 downto 0);
	signal ram_wdat : std_word(c_ram_width - 1 downto 0);
	signal ram_wen  : std_wire;
	signal ram_radd : unsigned(c_addr_bits - 1 downto 0);
	signal ram_rdat : std_word(c_ram_width - 1 downto 0);

	signal count_line : natural range 0 to 8;
	signal count_cycl : natural range 0 to c_ram_len;

	signal bdln_1r : std_wire;
	signal idle    : std_wire;

begin

	i_ram : entity work.true_dual_port_ram
	generic map
	(
		g_bit_width => c_ram_width,
		g_size      => 40
	)
	port map
	(
		clk1  => clk,
		addr1 => ram_wadd,
		din1  => ram_wdat,
		dout1 => open,
		wen1  => ram_wen,

		clk2  => clk,
		addr2 => ram_radd,
		din2  => (others => '0'),
		dout2 => ram_rdat,
		wen2  => '0'
	);


	p_control : process(clk) is
	begin
		if rising_edge(clk) then

			ram_wen <= '0';

			-- c-accesses are most stable on strobe 13-14
			if (strb = 13) then

				-- checking this here ensures the effects are properly delayed
				-- to the next (output) cycle
				if (bdln = '1') then
					idle    <= '0';
					bdln_1r <= '1';
				end if;

				if (cycl = 13) then
					if (bdln = '1') then
						count_line <= 0;
					else
						bdln_1r <= '0';
					end if;
				end if;

				if (cycl = c_cycl_ref) then
					ram_wadd <= (others => '0');
				elsif (ram_wadd < c_ram_len - 1) then
					ram_wadd <= ram_wadd + 1;
				end if;

				if (bdln or bdln_1r or ccax) then
					if (cycl = c_cycl_ref) or (ram_wadd < c_ram_len - 1) then
						ram_wen  <= '1';
						if (ccax = '1') then
							ram_wdat <= i_db;
						else
							ram_wdat <= i_db or x"0ff";
						end if;
					end if;
				end if;


				if (cycl = 57) then
					if (count_line /= 7) then
						count_line <= count_line + 1;
					elsif bdln = '0' then
						idle <= '1';
					else
						-- line doubling trick
						count_line <= 0;
					end if;
				end if;

			end if;

			-- start video matrix read soon enough for the data to be available
			-- when it needs to be produced on the output
			if (strb = 2) then
				if count_cycl < c_ram_len then
					count_cycl <= count_cycl + 1;
				end if;

				if (cycl = c_cycl_ref + 1) then
					ram_radd <= (others => '0');
					count_cycl <= 0;

				elsif (ram_radd < c_ram_len - 1) then
					ram_radd <= ram_radd + 1;
				end if;
			end if;

			if (strb = 7) then
				if (count_cycl /= c_ram_len) then
					o_en <= '1';
					o_gg <= i_db(7 downto 0);
					o_cc <= ram_rdat;
				else
					o_en <= '0';
				end if;

				if idle and idle_en then
					o_gg <= i_db(7 downto 0);
					o_cc <= (others => '0');
				end if;
			end if;

			rst_1r <= rst;
			if rst_1r then
				ram_wen <= '0';
				bdln_1r <= '0';
				idle    <= '1';
			end if;
		end if;
	end process;

end architecture;
