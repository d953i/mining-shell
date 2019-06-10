#### -- Set variables / configuration
global argv
global physOpt

source [lindex $argv 0]/scripts/settings.tcl

# Configure vivado for 8 threaded operation (8 threads maximum)
set_param general.maxThreads 8
set_param place.sliceLegEffortLimit 100000

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

set minerMgrs "top_i/stage2_wrapper_i/stage2_i/hub_0/inst/minermgrs\[*\].minermgr_i"
set_false_path -from [get_pins $minerMgrs/performed_hashes_reg\[*\]/C] -to [get_pins $minerMgrs/result_shellmsg_data_reg\[*\]/D]
set_false_path -from [get_pins $minerMgrs/cur_job_id_reg\[*\]/C] -to [get_pins $minerMgrs/result_shellmsg_data_reg\[*\]/D]
set_false_path -from [get_pins $minerMgrs/valid_reg/C] -to [get_pins $minerMgrs/valid_hist_reg*/D]
set_false_path -from [get_pins $minerMgrs/is_unlocked_reg/C] -to [get_pins $minerMgrs/result_accept_reg/D] -quiet
set_false_path -to [get_pins $minerMgrs/job_done_hist_reg\[0\]/D] 
set_false_path -to [get_pins $minerMgrs/nonces_processed_clk_hist_reg\[0\]/D]

#### -- Place design
place_design {*}$placeStrat

saveState "${buildDir}/${designName}_placed_nophysopt"

# Physical optimization
#phys_opt_design -fanout_opt -placement_opt -rewire -insert_negative_edge_ffs -critical_cell_opt -dsp_register_opt -bram_register_opt -uram_register_opt -shift_register_opt -aggressive_hold_fix -retime -sll_reg_hold_fix -placement_opt -critical_pin_opt
#phys_opt_design -directive AlternateReplication
#phys_opt_design -directive AlternateFlowWithRetiming
#phys_opt_design -directive AggressiveExplore

# Save placed design
#saveState "${buildDir}/${designName}_placed_physopt"

report_timing_summary -file "${buildDir}/${designName}_timing_summary.rpt"
report_utilization -file "${buildDir}/${designName}_utilization_summary.rpt"

