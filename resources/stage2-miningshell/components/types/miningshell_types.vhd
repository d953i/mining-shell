library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package miningshell_types is

  -- MMCM/PLL DRP port and multiplexer control for software-controlled clock adjustment.
  -- Just hook these up to your MMCMs/PLLs, the shell takes care of the rest.
  type to_pll is record
    rst : std_logic;
    pwrdwn : std_logic;
    daddr : std_logic_vector(6 downto 0);
    di : std_logic_vector(15 downto 0);
    dwe : std_logic;
    den : std_logic;
    dclk : std_logic;
  end record;
  type to_pll_vector is array(integer range <>) of to_pll;

  type from_pll is record
    do : std_logic_vector(15 downto 0);
    drdy : std_logic;
    locked : std_logic;
  end record;
  type from_pll_vector is array(integer range <>) of from_pll;

  type to_clkgen is record
    pll_drp : to_pll_vector(0 to 1);
    mux_sel : std_logic;
  end record;
  type to_clkgen_vector is array(integer range <>) of to_clkgen;

  type from_clkgen is record
    pll_drp : from_pll_vector(0 to 1);
  end record;
  type from_clkgen_vector is array(integer range <>) of from_clkgen;

end package;
