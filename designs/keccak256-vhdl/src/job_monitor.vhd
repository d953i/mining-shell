library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;
use work.miningshell_types.all;
use work.miningshell_simple_types.all;


-- This module is responsible for estimating the behavior of the hashing cores
-- and reporting back job completion and number of processed hashes to the shell.
entity job_monitor is
  generic(
    NONCE_STEP : natural := 1;  -- Amount to increment nonce by every CLOCKS_PER_HASH, should equal the number of cores.
    CLOCKS_PER_HASH : natural := 1  -- One hash operation is started in this core every CLOCKS_PER_HASH clock cycles.
  );
  port(
    clk : in std_logic;  -- Hashing core clock
    to_core : in mgr_to_miningcore;  -- Input data signals from the shell
    nonces_processed_clk : out std_logic;  -- Hashrate feedback to the shell
    nonces_processed : out unsigned(15 downto 0);  -- Number of hashes per nonces_processed_clk cycle
    job_done : out std_logic  -- Job completion signal to the shell, must go high at least 100ns + edge
                              -- detector delay before the first hashing core runs out of nonce space.
  );
end job_monitor;


architecture behavioral of job_monitor is

  -- This is quite hilarious, but Vivado still can't handle numeric literals
  -- higher than (2**31)-1, so some nasty workarounds are required here.
  constant MAX_32BIT : unsigned(31 downto 0) := (others => '1');
  -- Number of nonces to process per hashing core before running out of nonce
  -- space, i.e. total nonce space size divided by the number of hashing cores.
  constant MAX_NONCE : unsigned(31 downto 0) := MAX_32BIT / NONCE_STEP - 1;
  -- Per-core hash counter for the current job
  signal nonce : unsigned(31 downto 0);
  -- Clock cycle within the current hash operation (if CLOCKS_PER_HASH > 1)
  signal cycle : natural range 0 to CLOCKS_PER_HASH - 1;
  -- Rising edge detector for asynchronous job valid signal from the shell
  signal valid_capture : std_logic_vector(3 downto 0) := (others => '0');
  -- Synchronized job valid signal after edge detector
  signal valid : std_logic;
  -- Clock divider counter for nonces_processed_clk generation
  signal processed_clkdiv : unsigned(6 downto 0) := (others => '0');

begin

  -- The period of nonces_processed_clk equals the time that one hashing core needs
  -- to calculate 128 hashes, so report 128 times the number of cores as the number
  -- of calculated hashes per nonces_processed_clk cycle.
  nonces_processed <= to_unsigned(NONCE_STEP * 128, 16);
  -- Drive the nonces_processed_clk signal with the MSB of the clock divider
  nonces_processed_clk <= processed_clkdiv(6);

  -- Hashing core clock domain process
  process(clk)
  begin
    if rising_edge(clk) then
      -- Hash operation clock cycle counter
      if cycle = CLOCKS_PER_HASH - 1 then
        -- A hash operation was completed during this clock cycle, so reset cycle counter,
        -- increment hash operation counter and tick nonces_processed_clk clock divider input.
        -- if CLOCKS_PER_HASH == 1, this branch is always active and the cycle counter is unused.
        cycle <= 0;
        nonce <= nonce + 1;
        processed_clkdiv <= processed_clkdiv + 1;
      else
        -- No hash operation completed during this clock cycle, so just increment counter.
        cycle <= cycle + 1;
      end if;
      -- If we're almost at the end of our nonce space, signal job completion to the shell.
      -- This must be done a bit in advance to allow for the shell to pull down valid in time,
      -- and our own valid edge detector to detect that change.
      -- The 256 hash (per core) margin should be enough for most designs, but can be increased
      -- when needed. The loss of nonce space and resulting inefficiency is neglibily small.
      if valid = '1' and nonce > MAX_NONCE - 256 then
        job_done <= '1';
      end if;
      -- valid edge detector: Provides clean valid and resets nonce counter on rising edge.
      valid_capture <= to_core.valid & valid_capture(valid_capture'high downto 1);
      if valid_capture(2 downto 1) = "00" then
        -- valid is low, so reset job_done as well.
        valid <= '0';
        job_done <= '0';
      elsif valid_capture(2 downto 0) = "110" then
        -- valid rising edge detected, so reset nonce counter.
        valid <= '1';
        nonce <= (others => '0');
      end if;
    end if;
  end process;

end behavioral;
