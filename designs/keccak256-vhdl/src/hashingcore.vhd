library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;
use work.miningshell_types.all;
use work.miningshell_simple_types.all;
use work.core_internal_types.all;


-- Skeleton for one hashing core:
-- Receives a clock signal and (asynchronous) input data from the shell, performs
-- the required hashing operations iterating through its partition of the nonce space,
-- compares the result against the target and if it meets the condition and the input
-- data was valid, reports the nonce on the result bus. Multiple cores are chained
-- on that result bus and forward data from the previous core(s) to the next.
-- This example implementation assumes a hash_input_data length of 512 bits with the
-- nonce in the lowest 32 bits. These values will have to be adjusted for your hash
-- algorithm / block header format both in this module and in core_input.
-- NOTE: It is critical that independent of the input data validity status, the power
-- consumption of the hashing core does not vary other than with the clock frequency.
entity hashingcore is
  generic(
    NONCE_OFFSET : natural := 0;  -- Initial nonce value, to spread cores across the nonce space. Should equal the core ID.
    NONCE_STEP : natural := 1;  -- Amount to increment nonce by every CLOCKS_PER_HASH, should equal the number of cores.
    CLOCKS_PER_HASH : natural := 1  -- One hash operation is started in this core every CLOCKS_PER_HASH clock cycles.
  );
  port(
    clk : in std_logic;  -- Hashing core clock
    to_core : in mgr_to_miningcore;  -- Input data signals from the shell
    bus_in : in resultbus;  -- Result bus input port (from previous core).
    bus_out : out resultbus  -- Result bus output port (to next core).
  );

  -- Prevent resource sharing across core boundaries. Primarily intended to reduce
  -- routing congestion and avoid register sharing across SLR boundaries. YMMV.
  attribute keep_hierarchy : string;
  attribute keep_hierarchy of hashingcore : entity is "yes";

end hashingcore;


architecture structure of hashingcore is
 
  -- Number of clock cycles that hash_output_data is delayed relative to hash_input_data,
  -- i.e. number of pipeline stages inside the hashoperation module if CLOCKS_PER_HASH == 1.
  -- This must be an integer multiple of CLOCKS_PER_HASH.
  constant PIPELINE_LATENCY : natural := 47;

  -- ID of the current job at the pipeline input side
  signal job_id : std_logic_vector(7 downto 0);
  -- Data to be hashes, including nonce, at the pipeline input side.
  signal hash_input_data : std_logic_vector(639 downto 0);
  -- Resulting hash value at the pipeline output side
  signal hash_output_data : std_logic_vector(47 downto 0);
  -- Target to compare hash_output_data against. By convention, if the most significant
  -- bits of hash_output_data are less than (and not equal to) this, the nonce shall be
  -- reported. Deviations are possible if required by an algorithm, but must be discussed
  -- with the software team first, to agree on a proper definition of this field.
  signal target : std_logic_vector(47 downto 0);
  -- Whether the current hash_input_data value is valid and its results shall be
  -- reported if they meet the target. This signal must not affect power consumption!
  signal valid : std_logic;
  -- History of valid carried along with the hash data path pipeline
  signal valid_hist : std_logic_vector(1 to PIPELINE_LATENCY) := (others => '0');
  -- Hash target comparison result if valid (high if nonce shall be reported)
  signal found_nonce : std_logic := '0';
  -- Nonce value to be reported if found_nonce is high
  signal nonce_value : std_logic_vector(39 downto 0) := (others => '0');

begin

  -- Shell input decoding, valid synchronization and nonce counting/injection
  input : entity work.core_input
    generic map(
      NONCE_OFFSET => NONCE_OFFSET,
      NONCE_STEP => NONCE_STEP,
      CLOCKS_PER_HASH => CLOCKS_PER_HASH
    )
    port map(
      clk => clk,
      to_core => to_core,
      valid => valid,
      job_id => job_id,
      hash_input_data => hash_input_data,
      target => target
    );

  -- The actual hash operation to perform on the data
  hash : entity work.hashoperation
    port map(
      clk => clk,
      hash_input_data => hash_input_data,
      hash_output_data => hash_output_data
    );

  -- Hashing core clock domain process
  process(clk)
  begin
    if rising_edge(clk) then
      -- Carry input validity history along with the data path pipeline
      valid_hist <= valid & valid_hist(1 to valid_hist'high - 1);
      -- We cheat a bit here by not keeping a history of the job ID and nonce value.
      -- Instead we assume that our pipeline latency is less than the job loading time.
      -- So if the input data that this hash was based on was valid when it was inserted
      -- into the pipeline, and the input data is still valid for the hash being started
      -- right now, we can conclude that the job ID cannot have changed in the meantime
      -- and the nonce counter must have counted monotonically. We can thus report the
      -- nonce for the current input job ID and calculate the nonce value based on the
      -- current input nonce value, PIPELINE_LATENCY and CLOCKS_PER_HASH.
      -- This saves some area at the expense of a few wasted clock cycles for every job.
      nonce_value(31 downto 0) <= std_logic_vector(unsigned(hash_input_data(31 downto 0))
                                                 - to_unsigned(PIPELINE_LATENCY / CLOCKS_PER_HASH * NONCE_STEP, 32));
      -- Determine if the nonce should be reported
      found_nonce <= '0';
      if unsigned(hash_output_data) < unsigned(target) and valid_hist(PIPELINE_LATENCY) = '1' and valid = '1' then
        found_nonce <= '1';
      end if;
    end if;
  end process;

  -- Result bus interface
  output : entity work.core_output
    port map(
      clk => clk,
      bus_in => bus_in,
      bus_out => bus_out,
      found_nonce => found_nonce,
      job_id => job_id,
      nonce_value => nonce_value,
      sideband => std_logic_vector(to_unsigned(NONCE_OFFSET, 12))
    );

end structure;
