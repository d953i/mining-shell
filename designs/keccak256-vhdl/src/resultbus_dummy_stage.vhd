library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;
use work.miningshell_types.all;
use work.miningshell_simple_types.all;
use work.core_internal_types.all;


-- A simple result bus register stage
entity resultbus_dummy_stage is
  port(
    clk : in std_logic;  -- Result bus clock
    bus_in : in resultbus;  -- Bus input port
    bus_out : out resultbus  -- Bus output, equals input delayed by one clk cycle.
  );
end resultbus_dummy_stage;


architecture behavioral of resultbus_dummy_stage is

begin

  -- Result bus clock domain process
  process(clk)
  begin
    if rising_edge(clk) then
      -- Always propagate bus input to output with one clk cycle of delay
      bus_out <= bus_in;
    end if;
  end process;

end behavioral;
