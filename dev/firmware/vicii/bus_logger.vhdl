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

entity bus_logger is
generic
(
	g_enable : boolean
);
port
(
	clk      : in  std_wire; -- must be twice the video clock (16 times ph0)
	rst      : in  std_wire;

	-- gp3r master
	req      : in  t_gp3r_req;
	rsp      : out t_gp3r_rsp;

	xpos     : in  t_ppos;
	ypos     : in  t_ppos;

	-- VIC signals
	strb     : in  t_strb;
	ph0      : in  std_wire;
	db       : in  std_word(11 downto 0);
	a        : in  t_addr;
	rw       : in  std_wire;
	cs       : in  std_wire;
	aec      : in  std_wire
);
end entity;


architecture rtl of bus_logger is

	constant c_bit_width   : positive := 32;
	constant c_fifo_depth  : positive := 2048;

	signal   rst_1r        : std_wire := '1';

	signal   req_fifo      : req'subtype;
	signal   rsp_fifo      : rsp'subtype;

	signal   count         : natural range 0 to c_fifo_depth;
	signal   dumping       : std_wire;
	signal   pixl_num      : unsigned(bits_for_value(c_fifo_depth) - 1 downto 0);
	signal   line_num      : unsigned(31 downto 0);
	signal   line_num_push : std_wire;

	signal   data_in       : std_word(c_bit_width - 1 downto 0);
	signal   push_in       : std_wire;

	signal   data_out      : std_word(c_bit_width - 1 downto 0);
	signal   read_out      : std_wire;
	signal   push_out      : std_wire;

begin

	r_enable : if g_enable generate
		i_memmap : entity work.memmap_bus_logger
		generic map
		(
			g_decouple => true
		)
		port map
		(
			clk           => clk,
			rst           => rst,
			req           => req,
			rsp           => rsp,
			line_num      => line_num,
			pixl_num      => lresize(pixl_num, 32),
			line_num_push => line_num_push,
			req_line_read => req_fifo,
			rsp_line_read => rsp_fifo
		);


		p_input : process(clk) is
		begin
			if rising_edge(clk) then

				push_in <= '0';

				if ((ypos = line_num) and (xpos = 0) and (count = 0)) or
				   ((dumping = '1') and (xpos = count)              )
				then
					dumping <= '1';
					push_in <= '1';
					data_in <= "000000"       &
					           std_word(strb) & -- 25 downto 22
					           ph0            & -- 21
					           db             & -- 20 downto 9
					           std_word(a)    & -- 8 downto 3
					           rw             & -- 2
					           cs             & -- 1
					           aec;             -- 0

					if strb(0) = '1' then
						count <= count + 1;
					end if;
				end if;

				if line_num_push then
					count   <= 0;
					dumping <= '0';
				end if;

				rst_1r <= rst;
				if rst_1r then
					count   <= c_fifo_depth;
					dumping <= '0';
					push_in <= '0';
				end if;

			end if;
		end process;


		i_fifo : entity work.fifo
		generic map
		(
			g_depth => c_fifo_depth,
			g_width => c_bit_width
		)
		port map
		(
			i_clk   => clk,
			i_rst   => rst,
			i_push  => push_in,
			i_read  => open,
			i_data  => data_in,

			o_clk   => clk,
			o_rst   => rst,
			o_flush => '0',
			o_push  => push_out,
			o_read  => read_out,
			o_data  => data_out,
			o_nfull => pixl_num
		);


		i_stream_to_gp3r : entity work.gp3r_istream
		port map
		(
			clk    => clk,
			rst    => rst,
			req    => req_fifo,
			rsp    => rsp_fifo,
			data   => data_out,
			read   => read_out,
			push   => push_out
		);

	else generate

		i_nack : entity work.gp3r_dummy
		generic map
		(
			g_nack  => c_gp3r_nack_addr
		)
		port map
		(
			clk    => clk,
			rst    => rst,
			req    => req,
			rsp    => rsp
		);

	end generate;

end architecture;
