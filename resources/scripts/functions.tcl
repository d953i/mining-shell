# -- Create functions
proc getCurModule {} {
    return [file dirname [file dirname [info script]]]
}

proc runHook {filename} {
    if {[file exists $filename]} {
        global _runHook_filename
        set _runHook_filename $filename
        uplevel {
            global _runHook_filename
            source $_runHook_filename
        }
    }
}

proc ensureBuilt {filename module action} {
    if {! [file exists "$filename.dcp"]} {
        global baseDir scriptDir part board boardId stage1Version
        source "$module/scripts/$action.tcl"
    }
}

set curOpenStateName "<none>"
proc initProject {} {
    global curOpenStateName part board
    set curOpenStateName "<new>"
    catch close_project
    create_project -in_memory -part $part
    set_property BOARD_PART $board [current_project]
    set_property source_mgmt_mode All [current_project]
}

proc openState {filename module action} {               
    global curOpenStateName part              
    set requestedStateName $filename
    if {$curOpenStateName == $requestedStateName} {return}
    ensureBuilt $filename $module $action
    if {$curOpenStateName == $requestedStateName} {return}
    catch close_project
    open_checkpoint -part $part "$requestedStateName.dcp"
    set curOpenStateName $requestedStateName
}

proc saveState {filename args} {
    global curOpenStateName         
    set curOpenStateName $filename
    write_checkpoint -force {*}$args "$curOpenStateName.dcp"
}

proc destroyState {} {
    global curOpenStateName
    set curOpenStateName "<none>"
    catch close_project
}                  

proc physOptIteration {command} {
    global physOpt      
    incr physOpt(ID)
    set id $physOpt(ID)
    set physOpt($id) $command   
}

proc unplace_paths {max_paths nworst delay_type} {
    foreach path [get_timing_paths -max_paths $max_paths -nworst $nworst -delay_type $delay_type -filter { NAME =~ "*mininglogic_i*" } ] {
        set path_cells [get_cells -of_object $path] 
        puts $path_cells
        unplace_cell [list "$path_cells"]
    }
}

proc churn_placement {iterations place_strat save_loc} {
	set wns_best [get_property SLACK [get_timing_paths]]
	for {set i 0} {$i < $iterations} {incr i} {
		unplace_paths 25 5 min_max
		place_design {*}$place_strat
		set wns_current [get_property SLACK [get_timing_paths]]
		if { $wns_current > $wns_best } {
			set wns_best $wns_current
			write_checkpoint ${save_loc}/placed_${wns_current}.dcp
		}
	}
	open_checkpoint ${save_loc}/placed_${wns_best}.dcp
}

proc churn_physopt {physopt_strat} {
	set wns_best [get_property SLACK [get_timing_paths]]
	# Run phys opt cycles until wns no longer improves
	for {set i 0} {$i = 0} {
		phys_opt_design {*}$physopt_strat
		set wns_current [get_property SLACK [get_timing_paths]]

		if { $wns_current > $wns_best } {
			set wns_best $wns_current		
		}
		
		if { $wns_current = $wns_best } {
			set i 1
		}
	}
}
