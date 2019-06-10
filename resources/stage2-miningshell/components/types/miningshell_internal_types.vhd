library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package miningshell_internal_types is

  -- These constants and types are for internal use in the shell code. Don't bother about them.
  constant ROW_BITS : natural := 3;
  constant REG_BITS : natural := 9;
  constant SLAVE_BITS : natural := 5;
  constant DATA_WIDTH : natural := (2 ** ROW_BITS) * 8;

  subtype word is std_logic_vector(DATA_WIDTH - 1 downto 0);
  type word_vector is array (integer range <>) of word;
  subtype regaddr is unsigned(REG_BITS - 1 downto 0);
  subtype regaddr_int is integer range 0 to (2 ** REG_BITS) - 1;
  subtype slvaddr is unsigned(SLAVE_BITS - 1 downto 0);
  subtype slvaddr_int is integer range 0 to (2 ** SLAVE_BITS) - 1;

  type clkreq_to_clkmgr is record
    desired_state : std_logic;
  end record;
  type clkreq_to_clkmgr_vector is array(integer range <>) of clkreq_to_clkmgr;

  type clkmgr_to_clkreq is record
    clk_is_on : std_logic;
    clk_is_off : std_logic;
    clk_in_transition : std_logic;
    mgr_busy : std_logic;
  end record;
  type clkmgr_to_clkreq_vector is array(integer range <>) of clkmgr_to_clkreq;

end package;
