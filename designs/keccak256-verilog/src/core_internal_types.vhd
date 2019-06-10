library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package core_internal_types is

  -- Example implementation of a narrow result collection bus
  type resultbus is record
    data : std_logic;  -- Data bit to be transferred
    valid : std_logic;  -- High if data is valid (i.e. the bus is not idle)
    complete : std_logic;  -- High during the last bit of a message
  end record;
  type resultbus_vector is array(integer range <>) of resultbus;

end package;
