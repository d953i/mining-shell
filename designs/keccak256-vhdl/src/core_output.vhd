library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;
use work.miningshell_types.all;
use work.miningshell_simple_types.all;
use work.core_internal_types.all;


-- Result bus port for one hashing core:
-- If found_nonce is high, this module assembles a 60 bit wide nonce found message from the
-- job_id, sideband and nonce_value signals. The message is temporarily buffered inside the
-- module, and as soon as the bus input port is idle, it will be transmitted on the bus output
-- port one bit at a time. Forwarding data from the input port has priority over sending a
-- buffered message, and even if transmission of the buffered message is already in progress,
-- it will be aborted if the input port becomes active. Transmission of it will then be
-- restarted as soon as the bus input port becomes idle again.
-- TODO: Currently the whole result bus operates in the hashing core clock domain. To
-- facilitate SLR crossings if the hashing core is operating at frequencies above 600MHz,
-- it may be required to introduce a separate bus clock at a lower frequency and implement
-- the required clock domain crossing for the nonce found message buffer in this module.
entity core_output is
  port(
    clk : in std_logic;  -- Clock, both for the result bus and and hashing core signals.
    bus_in : in resultbus;  -- Result bus input port (from previous core).
    bus_out : out resultbus;  -- Result bus output port (to next core).
    found_nonce : in std_logic;  -- Trigger to send nonce found message with the following data:
    job_id : in std_logic_vector(7 downto 0);  -- Job ID that the reported nonce is coming from.
    nonce_value : in std_logic_vector(39 downto 0);  -- Value of the nonce that satisfies the target.
    sideband : in std_logic_vector(11 downto 0)  -- Additional diag data, e.g. core ID that found the nonce.
  );
end core_output;


architecture behavioral of core_output is

  -- Nonce found message buffer shift register ring
  -- (The message may cycle around for retransmissions)
  signal captured_data : std_logic_vector(59 downto 0);
  -- Number of captured_data bits left to be transmitted
  signal bits_left : natural range 60 downto 0 := 0;
  -- Nonce found message pending flag
  signal start : std_logic;

begin

  -- Result bus and hashing core clock domain process
  process(clk)
  begin
    if rising_edge(clk) then
      -- By default the output isn't valid. Will be set high later if it actually is.
      bus_out.valid <= '0';
      -- If the bus input port is idle, rotate the message in the buffer while transmitting.
      -- If a transmission attempt is being aborted, continue rotating it until it is back
      -- to its original state (i.e. bits_left == 0). Also decrement bits_left.
      if bus_in.valid = '0' or bits_left > 0 then
        captured_data <= captured_data(58 downto 0) & captured_data(59);
      end if;
      if bits_left > 0 then
        bits_left <= bits_left - 1;
      end if;
      -- If there is data coming in on the bus input port, forward that no matter what.
      if bus_in.valid = '1' then
        bus_out.valid <= '1';
        bus_out.data <= bus_in.data;
        bus_out.complete <= bus_in.complete;
        if bits_left > 0 then
          -- If this aborts an ongoing transmission, mark the message as pending again.
          start <= '1';
        end if;
      -- Otherwise, if we still have bits to transmit (or even a full pending message),
      -- transmit its most significant bit and signal that the bus output is active/valid.
      elsif start = '1' or bits_left > 0 then
        bus_out.valid <= '1';
        bus_out.data <= captured_data(59);
        bus_out.complete <= '0';
        if start = '1' then
          -- If we're just starting to transmit a message, initialize the number of remaining bits.
          bits_left <= 59;
        end if;
        if bits_left = 1 then
          -- If this is the last bit of the message, signal that on the bus output.
          bus_out.complete <= '1';
        end if;
        -- In any case, we now do not have a full pending message anymore.
        start <= '0';
      end if;
      -- If we aren't currently transmitting a message and a nonce was just found,
      -- assemble the message in the buffer and mark it as pending. This may overwrite
      -- an earlier message if the transmission of that was not started yet.
      if bits_left = 0 and found_nonce = '1' then
        captured_data <= job_id & sideband & nonce_value;
        bits_left <= 60;
        start <= '1';
      end if;
    end if;
  end process;

end behavioral;
