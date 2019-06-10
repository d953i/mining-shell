library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;
use work.miningshell_types.all;
use work.miningshell_simple_types.all;
use work.core_internal_types.all;


-- Result bus output deserializer:
-- Takes a serial bit stream from the result bus, detects message boundaries and
-- writes the received messages into the result FIFO of the shell.
entity result_decoder is
  port(
    clk : in std_logic;  -- Result bus clock
    bus_in : in resultbus;  -- Result bus input port
    result_clk : out std_logic;  -- Shell result FIFO interface clock
    result_insert : out std_logic;  -- Shell result FIFO write enable
    result_data : out std_logic_vector(63 downto 0)  -- Shell result FIFO write data
  );
end result_decoder;


architecture behavioral of result_decoder is

  -- Message buffer shift register
  signal data : std_logic_vector(59 downto 1);

begin

  -- Make shell result FIFO interface run on the result bus clock
  result_clk <= clk;
  -- Combinatorially determine whether the current bit on the bus input is the last one of the message
  result_insert <= bus_in.valid and bus_in.complete;
  -- Combinatorially assemble message from buffer shift register and the current bit on the bus
  result_data <= "0110" & data & bus_in.data;

  -- Result bus clock domain process
  process(clk)
  begin
    if rising_edge(clk) then
      -- Always shift message buffer shift register
      data <= data(58 downto 1) & bus_in.data;
    end if;
  end process;

end behavioral;
