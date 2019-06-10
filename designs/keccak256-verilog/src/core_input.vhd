library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;
use work.miningshell_types.all;
use work.miningshell_simple_types.all;


-- Input data bus generator for a hashing core:
-- It provides a new set of valid, job_id, hash_input_value and target values every CLOCKS_PER_HASH
-- cycles of clk. The nonce part of hash_input_data starts at NONCE_OFFSET and is incremented by
-- NONCE_STEP for every new set of data, so that every hashing core processes every NONCE_STEPth
-- nonce, thus partitioning the nonce space across cores.
-- The nonce is incremented even while valid is low, to ensure that power consumption of the hashing
-- core does not change significantly during job loading, to avoid power supply load dump issues.
-- The hashing core should thus also always fully process hash_input_data, even if valid is low.
-- Any results from hash_input_data values of clock cycles where valid was low must be discarded.
-- Spurious reporting of such nonces would confuse the error rate tracking and clock adjustment logic.
-- This example implementation ignores the nonce range, data length and nonce position fields from
-- the job message, assuming a hash_input_data length of 512 bits with the nonce in the lowest 32 bits.
-- For most algorithms these parameters are constant, but their value may need to be adjusted.
-- Taking the values from the fields from the job messages is only required for algorithms where
-- these parameters are not constant, and would otherwise increase overhead unnecessarily.
entity core_input is
  generic(
    NONCE_OFFSET : natural := 0;  -- Initial nonce value, to spread cores across the nonce space. Should equal the core ID.
    NONCE_STEP : natural := 1;  -- Amount to increment nonce by every CLOCKS_PER_HASH, should equal the number of cores.
    CLOCKS_PER_HASH : natural := 1  -- One hash operation is started in this core every CLOCKS_PER_HASH clock cycles.
  );
  port(
    clk : in std_logic;  -- Hashing core clock
    to_core : in mgr_to_miningcore;  -- Input data signals from the shell
    valid : out std_logic;  -- Whether hash results based on hash_input_data and target from this clock cycle should be reported
    job_id : out std_logic_vector(7 downto 0);  -- Job ID that should be reported back along with hash results
    hash_input_data : out std_logic_vector(639 downto 0);  -- Data to be inserted into the hash pipeline
    target : out std_logic_vector(47 downto 0)  -- Condition for hash results to be reported
  );
end core_input;


architecture behavioral of core_input is

  signal job_data : std_logic_vector(767 downto 0);  -- Shift register to hold the job message
  signal nonce : unsigned(31 downto 0);  -- Nonce counter register
  signal valid_capture : std_logic_vector(3 downto 0) := (others => '0');  -- valid edge detector for clock domain crossing
  signal cycle : natural range 0 to CLOCKS_PER_HASH - 1;  -- Hash operation clock cycle counter (0 bits wide if 1 hash per clock)

begin

  -- Alias job ID bits from the job message to the job_id output
  job_id <= job_data(7 downto 0);
  -- Assemble the hash input data from the job message contents and nonce counter
  hash_input_data <= job_data(767 downto 160) & std_logic_vector(nonce);
  -- Alias target bits from the job message to the target output and pad it with
  -- zero bits to align it for comparison against the high bits of the hash output
  target <= x"0000" & job_data(63 downto 32);

  -- Job message shift register (runs in intf_clk domain)
  process(to_core.intf_clk)
  begin
    if rising_edge(to_core.intf_clk) then
      if to_core.job_data_shift = '1' then
        job_data <= job_data(job_data'high - 1 downto 0) & to_core.job_data_in;
      end if;
    end if;
  end process;

  -- Hashing clock domain process
  process(clk)
  begin
    if rising_edge(clk) then
      -- Hash operation clock cycle counter, increments nonce by NONCE_STEP when it wraps.
      if cycle = CLOCKS_PER_HASH - 1 then
        cycle <= 0;
        nonce <= nonce + NONCE_STEP;
      else
        cycle <= cycle + 1;
      end if;
      -- valid edge detector: Provides clean valid signal for hashing core and resets nonce on rising edge.
      valid_capture <= to_core.valid & valid_capture(valid_capture'high downto 1);
      if valid_capture(2 downto 1) = "00" then
        valid <= '0';
      elsif valid_capture(2 downto 0) = "110" then
        valid <= '1';
        nonce <= unsigned(job_data(127 downto 96)) + NONCE_OFFSET;
      end if;
    end if;
  end process;

end behavioral;
