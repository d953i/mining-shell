library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package miningshell_simple_types is

  -- Job input interface:
  type mgr_to_miningcore is record

    -- Interface clock, that the following signals are synchronous to.
    -- This is a 125MHz always-on clock, based on the PCIe reference clock.
    intf_clk : std_logic;

    -- This signal indicates whether all clocks required by the hashing core
    -- are stable. Hashing cores using only clocks from a single MMCM, can
    -- usually ignore this signal. Its purpose is to mark output data invalid
    -- in hashing cores with multiple MMCMs while those are being reconfigured
    -- and clocks may temporarily have wrong ratio or phase relationship.
    -- The rising edge of this signal can also be used as a trigger to realign
    -- internal operation once ratio and phase relationship was restored.
    -- Please make sure that this signal does not have any significant
    -- impact on power consumption, or there may be stability issues.
    all_clks_stable : std_logic;

    -- This signal indicates whether the hashing core is unlocked (by fee
    -- enforcement) and valid work is available. It should be carried along
    -- through the hash operation to filter out garbage outputs generated
    -- based on invalid work data. This signal will go low when running out
    -- of nonce space for the current job (i.e. in response to the job_done
    -- signal being high), or when the job is being flushed due to it becoming
    -- stale. It will go high once loading of fresh work data into the hashing
    -- core has completed. This rising edge should be used to trigger a nonce
    -- counter reset. Please make sure that this signal does not have any
    -- significant impact on power consumption, or there may be stability issues.
    valid : std_logic;

    -- Job data is kept in a shift register in the hashing core. The shell provides
    -- new job data by shifting it into that register while the valid signal is low.
    --
    -- By convention (for software compatibility), the job data register contents are defined as follows:
    -- [7 downto 0]: Identifier to tag nonces as originating from this job
    -- [19 downto 8]: data length (data extends from bit 128 to bit 127+X, inclusive)
    -- [31 downto 20]: nonce field position (nonce field extends from bit 128+X to bit 159+X, inclusive)
    -- [63 downto 32]: target (golden nonce condition: result[result'high downto result'high - 47] < x"0000" & X)
    -- [95 downto 64]: nonce range end (inclusive)
    -- [127 downto 96]: nonce range begin (inclusive)
    -- [<variable> downto 128]: data to be hashed, including nonce field, as one huge big-endian integer
    --
    -- Bit 128 of this vector will be the LSB of the "rightmost" (i.e. highest host-side memory address)
    -- byte of the data to be hashed, bit 135 the MSB. Bit 136 will be the LSB of the "2nd from the right"
    -- byte, i.e. memory address one lower than the last byte. And so on.
    -- For the endianness of nonce ranges, please stick to the conventions for the algorithm
    -- that you are implementing, especially if nonce ranges are split by pool servers
    -- (like e.g. "NiceHash mode" for CryptoNight). For high hashrate algorithms where nonce
    -- range partitioning is not commonly used, you can just ignore those fields and always
    -- scan the whole 32 bit space. (For even higher hashrate algorithms where the block header
    -- format supports it, the nonce can be wider than 32 bits.) The data length and nonce
    -- field position fields can also be ignored for algorithms where they are constant anyway.

    -- Job data shift register enable: This signal is high if the job_data_in
    -- signal should be shifted into the job data register as the LSB.
    -- It will generally only ever be high while valid is low.
    job_data_shift : std_logic;
    -- Data bit to be shifted into the job data register if job_data_shift is high
    job_data_in : std_logic;

  end record;

  type mgr_to_miningcore_vector is array(integer range <>) of mgr_to_miningcore;


  -- Job result output interface:
  type miningcore_to_mgr is record

    -- Job completion notification / request for a new job:
    -- This is an asynchronous signal that shall be driven high by the hashing
    -- core shortly before the nonce space of the current job is exhausted.
    -- The shell will pull down the valid signal within 100ns in response to this
    -- signal going high, so the hashing core should drive this high slightly in
    -- advance to stop in time and prevent duplicate/garbage calculations from
    -- confusing the error rate tracking and clock adjustment logic. Once the
    -- shell has pulled the valid signal low, it will start loading of a new job
    -- as soon as possible (immediately if one is buffered).
    -- Once this signal was driven high, it should be kept high until the shell
    -- has driven the valid signal low. The hashing core shall drive this signal
    -- low again within 100ns after the shell has driven the valid signal low.
    job_done : std_logic;

    -- For fee ratio enforcement the shell must know roughly how many hashes have
    -- been processed by the hashing core. This does not need to be cycle-accurate,
    -- but should be very close to reality when averaged across several seconds.
    -- The number of hashes performed is kept track of by the shell in the 125MHz
    -- clock domain, which is asynchronous from the hashing core's operation.
    -- To avoid complicated calculations on the shell side and allow for cores with
    -- arbitrary (and not necessarily constant) hashes per clock ratio, an approach
    -- is taken where the hashing core reports back to the shell whenever it has
    -- has performed a certain number of hash operations. As the hashing core is
    -- typically running in a much higher frequency clock domain than the shell,
    -- a slow clock, usually divided down from the hashing clock to automatically
    -- scale with the hashrate, is used to communicate this information.
    -- The hashing core shall report the number of hashes calculated, irrespective
    -- of the job data being valid at that time. The shell will ensure internally
    -- that hash operations on invalid data are statistically compensated for.

    -- Clock for the nonces_processed signal: The frequency and duty cycle may
    -- be arbitrary (and not necessarily constant) as long as both the high and
    -- low time for this signal are at least 50ns each.
    nonces_processed_clk : std_logic;
    -- Number of nonces processed during one nonces_processed_clk cycle.
    -- This signal may not change while nonces_processed_clk is high.
    -- For cores which have a fixed number of hashes per clock and are
    -- driving nonces_processed_clk with a divided down hashing core clock,
    -- this signal is usually constant (hashes_per_clock * division_factor).
    -- A cleverly chosen division_factor for nonces_processed_clk allows for
    -- this to be a constant integer even if hashes_per_clock is fractional.
    nonces_processed : unsigned(15 downto 0);

    -- Calculation results from the hashing core are stored to a FIFO, the interface
    -- of which is usually running in the hashing core clock domain, or some clock
    -- derived from it. The FIFO interface is 64 bits (subsequently called a "word")
    -- wide. If throughput requirements are low, a shift register could be put
    -- in front of that FIFO to keep the bus width of the result collection system low.
    -- Typical hashing cores which scan a 32 bit nonce range will usually insert one
    -- element (word) into the FIFO per nonce found. For hashing cores which need to
    -- transfer more result data, multiple words can be combined into a message.
    --
    -- By convention (for software compatibility), the result data words are defined as follows:
    -- [63]: Origin identification (shall always be 0, used to tell apart messages
    --       originating from the hashing core from those originating from the shell)
    -- [62]: Whether this is the first word of the message
    -- [61]: Whether this is the last word of the message
    -- (the above two bits shall both be 1 if the message only consists of a single word)
    -- [60]: Message type identification (0 for result messages, 1 for auxiliary messages)
    --
    -- So far, the remaining bits have only been defined for reporting of 32 bit nonces.
    -- For algorithms requiring more than 32 bits of result data, special data formats
    -- will be defined in coordination with the client software development team as needed.
    --
    -- For simple <=52 bit nonce result messages, the remaining bits are defined as follows:
    --     [59 downto 52]: Identifier of the job that the nonce being reported came from
    --                     (bits 7 downto 0 from the job data)
    --     [51 downto 0]: Nonce value to be reported (big endian, just like the job data).
    --                    The number of actually used bits is defined by the block header
    --                    format of the currency (in many cases only allowing 32 bits),
    --                    or, for formats supporting more, by the software implementation
    --                    of the algorithm and/or the bitstream configuration data. If less
    --                    than 52 bits are used, they shall be aligned to the LSB of this
    --                    field, and the unused upper bits may be used to convey arbitrary
    --                    side band data to the mining software, e.g. the number of the
    --                    hashing core, that a nonce was found on, for diagnostic purposes.

    -- Result FIFO Interface clock, that the following signals are synchronized to.
    -- This clock is provided by the hashing core, and is usually based on the hashing
    -- clock. It may also be intf_clock of the other communication direction fed back.
    -- As this clock also runs some shell logic, it should be kept running as long
    -- as the hashing core is provided with both an intf_clock and a hashing clock,
    -- i.e. it should not be abused as a write strobe, but actually be a clock.
    result_clk : std_logic;
    -- Whether result_data should be inserted into the result FIFO
    -- (at the result_clk rising edge).
    result_insert : std_logic;
    -- Data to be pushed into the result FIFO
    -- (at the result_clk rising edge if result_insert is high).
    result_data : std_logic_vector(63 downto 0);

  end record;

  type miningcore_to_mgr_vector is array(integer range <>) of miningcore_to_mgr;

end package;
