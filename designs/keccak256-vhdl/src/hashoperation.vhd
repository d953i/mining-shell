library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;


-- This module is the data pipeline of the actual hash operation.
-- In this example, it's a 5-stage pipeline that builds the XOR sum of all 64 bit
-- words of input data, and then swaps the low and high halves of the result.
entity hashoperation is
  port(
    clk : in std_logic;
    hash_input_data : in std_logic_vector(639 downto 0);
    hash_output_data : out std_logic_vector(47 downto 0)
  );
end hashoperation;


architecture behavioral of hashoperation is

  signal state : std_logic_vector(1599 downto 0);
  signal nonce : std_logic_vector(31 downto 0);
  signal hash : std_logic_vector(255 downto 0);

begin

  state <= hash_input_data(639 downto 32) & x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
  nonce <= hash_input_data(31 downto 0);

  hash_output_data(47 downto 40) <= hash(7 downto 0);
  hash_output_data(39 downto 32) <= hash(15 downto 8);
  hash_output_data(31 downto 24) <= hash(23 downto 16);
  hash_output_data(23 downto 16) <= hash(31 downto 24);
  hash_output_data(15 downto 8) <= hash(39 downto 32);
  hash_output_data(7 downto 0) <= hash(47 downto 40);

  keccak : entity work.keccak
    port map(
      clk => clk,
      state_in => state,
      nonce_in => nonce,
      padding_byte => x"01",
      dout => hash
    );

end behavioral;
