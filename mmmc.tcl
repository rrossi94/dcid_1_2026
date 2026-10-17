#################################################################################
#
# Configuracion MMMC para DCID1 - Practico 7 (Cadence Joules)
# Utiliza las librerias GPDK045 instaladas en /home/amslib/PDKs/gpdk045v6
#
#################################################################################

set libpath "/home/amslib/PDKs/gpdk045v6"

## Seleccion de librerias logicas y QRC
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
    -voltage 1.08 \
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

## Resolucion dinamica del archivo SDC
if {[info exists CURRENT_SDC] && [file exists $CURRENT_SDC]} {
    set sdc_file_to_use $CURRENT_SDC
} else {
    set sdc_candidates [list \
        "fir_serial_mod/sdc/fir_serial.sdc" \
        "fir_serial_orig/sdc/fir_serial.sdc" \
        "sdc/fir_serial.sdc" \
        "sdc/multiplicador.sdc" \
        "fir_serial.sdc" \
    ]
    set sdc_file_to_use ""
    foreach cand $sdc_candidates {
        if {[file exists $cand]} {
            set sdc_file_to_use $cand
            break
        }
    }
}

if {$sdc_file_to_use eq ""} {
    set sdc_file_to_use "fir_serial_mod/sdc/fir_serial.sdc"
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
