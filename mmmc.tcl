#################################################################################
#
# Created by Genus(TM) Synthesis Solution 20.10-d885_1 on Wed Jul 08 02:47:05 PDT 2020
#
#################################################################################

## library_sets
create_library_set -name ls_of_ld_PVT_1P08V_125C \
    -timing [list $::env(DATA_DIR)/LIBRARIES/slow.lib \
              $::env(DATA_DIR)/LIBRARIES/gsclib045_v3.5/timing/slow_vdd1v08_extvdd1v32.lib \
              $::env(DATA_DIR)/LIBRARIES/gsclib045_v3.5/timing/slow_vdd1v32_extvdd1v08.lib \
              $::env(DATA_DIR)/MACRO_LIBS/pllclk_slow.lib \
              $::env(DATA_DIR)/MACRO_LIBS/CDK_S128x16.lib \
              $::env(DATA_DIR)/MACRO_LIBS/CDK_S256x16.lib \
              $::env(DATA_DIR)/MACRO_LIBS/CDK_R512x16.lib ]
create_library_set -name ls_of_ld_PVT_1P32V_0C \
    -timing [list $::env(DATA_DIR)/LIBRARIES/fast.lib \
              $::env(DATA_DIR)/LIBRARIES/gsclib045_v3.5/timing/slow_vdd1v08_extvdd1v32.lib \
              $::env(DATA_DIR)/LIBRARIES/gsclib045_v3.5/timing/slow_vdd1v32_extvdd1v08.lib \
              $::env(DATA_DIR)/MACRO_LIBS/pllclk_slow.lib \
              $::env(DATA_DIR)/MACRO_LIBS/CDK_S128x16.lib \
              $::env(DATA_DIR)/MACRO_LIBS/CDK_S256x16.lib \
              $::env(DATA_DIR)/MACRO_LIBS/CDK_R512x16.lib ]
create_library_set -name ls_of_ld_power \
    -timing [list $::env(DATA_DIR)/LIBRARIES/typical.lib \
              $::env(DATA_DIR)/LIBRARIES/gsclib045_v3.5/timing/slow_vdd1v08_extvdd1v32.lib \
              $::env(DATA_DIR)/LIBRARIES/gsclib045_v3.5/timing/slow_vdd1v32_extvdd1v08.lib \
              $::env(DATA_DIR)/MACRO_LIBS/pllclk_slow.lib \
              $::env(DATA_DIR)/MACRO_LIBS/CDK_S128x16.lib \
              $::env(DATA_DIR)/MACRO_LIBS/CDK_S256x16.lib \
              $::env(DATA_DIR)/MACRO_LIBS/CDK_R512x16.lib ]

## opcond
create_opcond -name slow_108V \
    -process 1.0 \
    -voltage 1.08 \
    -temperature 125.0

create_opcond -name fast_132V \
    -process 1.0 \
    -voltage 1.32 \
    -temperature 0.0

create_opcond -name typ_120V \
    -process 1.0 \
    -voltage 1.2 \
    -temperature 25.0

## timing_condition
create_timing_condition -name tc_of_ld_PVT_1P08V_125C \
    -opcond slow_108V \
    -library_sets { ls_of_ld_PVT_1P08V_125C }
create_timing_condition -name tc_of_ld_PVT_1P32V_0C \
    -opcond fast_132V \
    -library_sets { ls_of_ld_PVT_1P32V_0C }
#create_timing_condition -name tc_of_ld_PVT_1P20V_25C \
#    -opcond typ_120V \
#    -library_sets { ls_of_ld_power }

## rc_corner
create_rc_corner -name max_rc_corner \
    -temperature 125.0 \
    -qrc_tech $::env(DATA_DIR)/CONSTRAINTS/gpdk045.tch \
    -pre_route_res 1.0 \
    -pre_route_cap 1.0 \
    -pre_route_clock_res 0.0 \
    -pre_route_clock_cap 0.0 \
    -post_route_res {1.0 1.0 1.0} \
    -post_route_cap {1.0 1.0 1.0} \
    -post_route_cross_cap {1.0 1.0 1.0} \
    -post_route_clock_res {1.0 1.0 1.0} \
    -post_route_clock_cap {1.0 1.0 1.0}

create_rc_corner -name min_rc_corner \
    -temperature 0.0 \
    -qrc_tech $::env(DATA_DIR)/CONSTRAINTS/gpdk045.tch \
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
    -timing_condition { tc_of_ld_PVT_1P08V_125C AO@tc_of_ld_PVT_1P08V_125C TDSPCore@tc_of_ld_PVT_1P32V_0C PLL_PD@tc_of_ld_PVT_1P08V_125C } \
    -rc_corner max_rc_corner 

#create_delay_corner -name delay_corner_2 \
#    -timing_condition { tc_of_ld_PVT_1P20V_25C AO@tc_of_ld_PVT_1P20V_25C TDSPCore@tc_of_ld_PVT_1P32V_0C PLL_PD@tc_of_ld_PVT_1P20V_25C } \
#    -rc_corner min_rc_corner


## constraint_mode
create_constraint_mode -name constraint_mode_1 \
    -sdc_files "/usr/share/cem-dcid/practico_power/multiplicador.sdc"

## analysis_view
create_analysis_view -name view1 \
    -constraint_mode constraint_mode_1 \
    -delay_corner delay_corner_1

#create_analysis_view -name view2 \
#    -constraint_mode constraint_mode_1 \
#    -delay_corner delay_corner_2

## set_analysis_view
#set_analysis_view -setup { view1 view2} \
#                  -hold { view1 } \
#		  -leakage {view2} \
#		  -dynamic {view2}

set_analysis_view -setup { view1 } \
                  -hold { view1 } \
		  -leakage {view1} \
		  -dynamic {view1}
