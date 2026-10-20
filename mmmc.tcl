#################################################################################
#
# Configuración MMMC para DCID1 - Práctico 6 (Cadence Joules)
# Utiliza las librerías GPDK045 instaladas en /home/amslib/PDKs/gpdk045v6
#
#################################################################################

set libpath "/home/amslib/PDKs/gpdk045v6"

## Selección de librerías lógicas y QRC
if {[file exists "${libpath}/gsclib045/timing/slow_vdd1v0_basicCells.lib"]} {
    set slow_lib "${libpath}/gsclib045/timing/slow_vdd1v0_basicCells.lib"
    set qrc_file "${libpath}/qrc/rcworst/qrcTechFile"
} elseif {[info exists ::env(DATA_DIR)] && [file exists "$::env(DATA_DIR)/LIBRARIES/slow.lib"]} {
    set slow_lib "$::env(DATA_DIR)/LIBRARIES/slow.lib"
    set qrc_file "$::env(DATA_DIR)/CONSTRAINTS/gpdk045.tch"
} else {
    set slow_lib "${libpath}/gsclib045/timing/slow_vdd1v0_basicCells.lib"
    set qrc_file "${libpath}/qrc/rcworst/qrcTechFile"
}

## library_sets
create_library_set -name ls_of_ld_PVT_1P08V_125C \
    -timing [list $slow_lib]

## opcond
create_opcond -name slow_108V \
    -process 1.0 \
    -voltage 1.0 \
    -temperature 125.0

## timing_condition
create_timing_condition -name tc_of_ld_PVT_1P08V_125C \
    -opcond slow_108V \
    -library_sets { ls_of_ld_PVT_1P08V_125C }

## rc_corner
create_rc_corner -name max_rc_corner \
    -temperature 125.0 \
    -qrc_tech $qrc_file \
    -pre_route_res 1.0 \
    -pre_route_cap 1.0 \
    -pre_route_clock_res 0.0 \
    -pre_route_clock_cap 0.0 \
    -post_route_res {1.0 1.0 1.0} \
    -post_route_cap {1.0 1.0 1.0} \
    -post_route_cross_cap {1.0 1.0 1.0} \
    -post_route_clock_res {1.0 1.0 1.0} \
    -post_route_clock_cap {1.0 1.0 1.0}

## delay_corner
create_delay_corner -name delay_corner_1 \
    -timing_condition { tc_of_ld_PVT_1P08V_125C } \
    -rc_corner max_rc_corner 

## Resolución dinámica del archivo SDC
set script_dir [file dirname [file normalize [info script]]]
set sdc_candidates [list \
    [file join $script_dir "sdc" "multiplicador.sdc"] \
    [file join $script_dir "multiplicador.sdc"] \
    [file normalize "sdc/multiplicador.sdc"] \
    [file normalize "multiplicador.sdc"] \
]

set sdc_file_to_use ""
foreach cand $sdc_candidates {
    if {[file exists $cand]} {
        set sdc_file_to_use $cand
        break
    }
}
if {$sdc_file_to_use eq ""} {
    set sdc_file_to_use [lindex $sdc_candidates 0]
}

## constraint_mode
create_constraint_mode -name constraint_mode_1 \
    -sdc_files [list $sdc_file_to_use]

## analysis_view
create_analysis_view -name view1 \
    -constraint_mode constraint_mode_1 \
    -delay_corner delay_corner_1

## set_analysis_view
set_analysis_view -setup { view1 } \
                  -hold { view1 } \
                  -leakage { view1 } \
                  -dynamic { view1 }
