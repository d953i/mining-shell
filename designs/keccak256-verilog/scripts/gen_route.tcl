#### -- Set variables / configuration
global argv
global physOpt

source [lindex $argv 0]/scripts/settings.tcl

# Configure vivado for 8 threaded operation (8 threads maximum)
set_param general.maxThreads 8

set stage1Name "mcapshell"
set stage2Name "simpleshell"

set resourceDir "${baseDir}/resources"
set designDir "${baseDir}/designs/${designName}"
set buildDir "${designDir}/builds/${buildId}"

source $resourceDir/board-${boardName}/scripts/variables.tcl
source $resourceDir/scripts/functions.tcl

# Misc Configuration
set numMiners 1
set numClocks 1
set bitstreamNamespace 74657374
set bitstreamId 00000000

# Sec module path
set shell "simpleshell_${secImpl}_${numMiners}miners_${numClocks}clocks"
set secDir "${resourceDir}/board-${boardName}/components/${shell}"

# Source Paths
set shellTypesDir "${resourceDir}/stage2-miningshell/components/types/"
set shellTypeDir "${resourceDir}/stage2-miningshell/${stage2Name}/components/type-simple/"

# Mining Core Path
set miningCoreModule "$buildDir/${designName}_core_syn"

# Mining core cell path
set miningCoreCellPath "top_i/stage2_wrapper_i/stage2_i/hub_0/inst/mininglogic_i"

# Copy source code to build directory
file copy -force $coreDCP $buildDir/

#### -- Init project
# Starting to build project from here below
initProject

# Load synth'd core
open_checkpoint ${coreDCP}

#### -- Route design
route_design {*}$routeStrat

# Save routed design
saveState "${buildDir}/${designName}_routed_nophysopt"

#phys_opt_design -routing_opt -slr_crossing_opt -clock_opt
#phys_opt_design -tns_cleanup -slr_crossing_opt
#phys_opt_design -routing_opt -slr_crossing_opt -clock_opt
#phys_opt_design -tns_cleanup -slr_crossing_opt

#route_design {*}$routeStrat

#saveState "${buildDir}/${designName}_routed_physopt

if {$secImpl eq "secure"} {
    # Run encryption setup routine here
} elseif {$secImpl eq "open"} {
    # Write bitstream if this is an open design
    set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
    write_bitstream -force -bin_file -cell [get_cells top_i/stage2_wrapper_i] -file "${buildDir}/${designName}"
}
