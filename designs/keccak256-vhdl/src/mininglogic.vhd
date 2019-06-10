library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;
use work.miningshell_types.all;
use work.miningshell_simple_types.all;
use work.core_internal_types.all;


-- Top-level module to be implemented by the hashing core developer,
-- which will be wrapped into the Allmine mining shell.
entity mininglogic is
  generic(
    -- These generics define the width of some of the module's interface signals,
    -- which need to match the configuration of the shell. The default values here
    -- are used during out-of-context synthesis of this module. During integration,
    -- the values specified in localvars.tcl will be used, overriding the defaults
    -- set here. Please keep both in sync.
    NUM_MINERS : natural := 1;
    NUM_CLOCKS : natural := 1
  );
  port(
    refclk : in std_logic;  -- Reference clock for MMCMs (300MHz on BCU1525 and CVP-13)
    lock : in std_logic;  -- High if bitstream activation was successful (normally not used by this module)
    to_clkgen : in to_clkgen_vector(0 to NUM_CLOCKS - 1);  -- Clock generator control signals from shell
    from_clkgen : out from_clkgen_vector(0 to NUM_CLOCKS - 1);  -- Clock generator status signals to shell
    to_core : in mgr_to_miningcore_vector(0 to NUM_MINERS - 1);  -- Mining core input data from shell
    from_core : out miningcore_to_mgr_vector(0 to NUM_MINERS - 1)  -- Mining core result data to shell
  );
end mininglogic;


architecture structure of mininglogic is

  -- Number of hashing cores to instantiate below
  constant NUM_CORES : natural := 3;
  -- One hash operation is started in each core every CLOCKS_PER_HASH clock cycles.
  constant CLOCKS_PER_HASH : natural := 1;

  -- This example hashing core only has one input clock, provided by this signal
  signal hashing_clk : std_logic;
  -- Result collection bus chained through all cores (with 2 dummy register stages
  -- in between every pair of cores to ease routability, change as needed)
  signal result_bus : resultbus_vector(0 to 3 * NUM_CORES);

begin

  -- Shell status feedback provider
  monitor : entity work.job_monitor
    generic map(
      NONCE_STEP => NUM_CORES,
      CLOCKS_PER_HASH => CLOCKS_PER_HASH
    )
    port map(
      clk => hashing_clk,
      to_core => to_core(0),
      nonces_processed_clk => from_core(0).nonces_processed_clk,
      nonces_processed => from_core(0).nonces_processed,
      job_done => from_core(0).job_done
    );

  -- Hashing core clock generator
  clkgen0 : entity work.clkgen
    port map (
      refclk => refclk,
      to_clkgen => to_clkgen(0),
      from_clkgen => from_clkgen(0),
      hashing_clk => hashing_clk
    );

  -- Dummy result bus input for first hashing core
  result_bus(0).valid <= '0';

  -- Hashing core generator
  cores : for i in 0 to NUM_CORES - 1 generate
    -- An actual hashing core
    core : entity work.hashingcore
      generic map(
        NONCE_OFFSET => i,
        NONCE_STEP => NUM_CORES,
        CLOCKS_PER_HASH => CLOCKS_PER_HASH
      )
      port map(
        clk => hashing_clk,
        to_core => to_core(0),
        bus_in => result_bus(3 * i),
        bus_out => result_bus(3 * i + 1)
      );
    -- First dummy result bus register stage
    reg1 : entity work.resultbus_dummy_stage
      port map(
        clk => hashing_clk,
        bus_in => result_bus(3 * i + 1),
        bus_out => result_bus(3 * i + 2)
      );
    -- Second dummy result bus register stage
    reg2 : entity work.resultbus_dummy_stage
      port map(
        clk => hashing_clk,
        bus_in => result_bus(3 * i + 2),
        bus_out => result_bus(3 * i + 3)
      );
  end generate;

  -- Result bus output deserializer, feeding results to the shell.
  result : entity work.result_decoder
    port map(
      clk => hashing_clk,
      bus_in => result_bus(3 * NUM_CORES),
      result_clk => from_core(0).result_clk,
      result_insert => from_core(0).result_insert,
      result_data => from_core(0).result_data
    );

end structure;
