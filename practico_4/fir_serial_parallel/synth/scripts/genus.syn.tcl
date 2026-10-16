#### Template Script for RTL->Gate-Level Flow (generated from GENUS 23.10-p004_1) 

if {[file exists /proc/cpuinfo]} {
  sh grep "model name" /proc/cpuinfo
  sh grep "cpu MHz"    /proc/cpuinfo
}

puts "Hostname : [info hostname]"

##############################################################################
## Preset global variables and attributes
##############################################################################

# load config file
puts "Sourcing file ./scripts/config.tcl"
source ./scripts/config.tcl
puts "file ./scripts/config.tcl has loaded - review Error/Warning messages"

set DESIGN $design
set GEN_EFF $gen_eff
set MAP_OPT_EFF $map_opt_eff
set DATE [clock format [clock seconds] -format "%b%d-%T"] 
set _OUTPUTS_PATH outputs_${DATE}
set _REPORTS_PATH reports_${DATE}
set _LOG_PATH logs_${DATE}
##set MODUS_WORKDIR <MODUS work directory>
set_db / .init_lib_search_path {. ./lib \
				/home/amslib/PDKs/gpdk045v6/gsclib045_hvt/timing \
				/home/amslib/PDKs/gpdk045v6/gsclib045_lvt/timing \
				/home/amslib/PDKs/gpdk045v6/gsclib045/timing \
				}

#set_db / .script_search_path ". ./sdc ./rtl ./scripts /usr/share/cem-dcid/rtl/${design}/sdc"
#set_db / .init_hdl_search_path ". ./rtl /usr/share/cem-dcid/rtl/${design}/code"

set_db / .init_hdl_search_path ". ./rtl ${codepath}"
set_db / .script_search_path ". ./sdc ./rtl ./scripts ${sdcpath}" 

##Uncomment and specify machine names to enable super-threading.
##set_db / .super_thread_servers {<machine names>} 
##For design size of 1.5M - 5M gates, use 8 to 16 CPUs. For designs > 5M gates, use 16 to 32 CPUs
##set_db / .max_cpus_per_server 8

##Default undriven/unconnected setting is 'none'.  
##set_db / .hdl_unconnected_value 0 | 1 | x | none

set_db / .information_level 7 

###############################################################
## Library setup
###############################################################
set libpath "/home/amslib/PDKs/gpdk045v6"

set hvt_lib "${libpath}/gsclib045_hvt/timing/slow_vdd1v0_basicCells_hvt.lib"
set svt_lib "${libpath}/gsclib045/timing/slow_vdd1v0_basicCells.lib"
set lvt_lib "${libpath}/gsclib045_lvt/timing/slow_vdd1v0_basicCells_lvt.lib"

set tech_lef "${libpath}/gsclib045_tech/lef/gsclib045_tech.lef"
set hvt_lef  "${libpath}/gsclib045_hvt/lef/gsclib045_hvt_macro.lef"
set svt_lef  "${libpath}/gsclib045/lef/gsclib045_macro.lef"
set lvt_lef  "${libpath}/gsclib045_lvt/lef/gsclib045_lvt_macro.lef"


read_libs "$hvt_lib $svt_lib $lvt_lib"
read_physical -lef "$tech_lef $hvt_lef $svt_lef $lvt_lef"
## Provide either cap_table_file or the qrc_tech_file
#set_db / .cap_table_file <file> 
#read_qrc <qrcTechFile name>
read_qrc /home/amslib/PDKs/gpdk045v6/qrc/rcworst/qrcTechFile 

set_db / .lp_insert_clock_gating true 

####################################################################
## Load Design
####################################################################

read_hdl -sv $vlist
elaborate $DESIGN
puts "Runtime & Memory after 'read_hdl'"
time_info Elaboration



check_design -unresolved

####################################################################
## Constraints Setup
####################################################################

read_sdc $sdclist
puts "The number of exceptions is [llength [vfind "design:$DESIGN" -exception *]]"


if {![file exists ${_OUTPUTS_PATH}]} {
  file mkdir ${_OUTPUTS_PATH}
  puts "Creating directory ${_OUTPUTS_PATH}"
}

if {![file exists ${_REPORTS_PATH}]} {
  file mkdir ${_REPORTS_PATH}
  puts "Creating directory ${_REPORTS_PATH}"
}


#### To turn off sequential merging on the design 
#### uncomment & use the following attributes.
##set_db / .optimize_merge_flops false 
##set_db / .optimize_merge_latches false 
#### For a particular instance use attribute 'optimize_merge_seqs' to turn off sequential merging. 



####################################################################################################
## Synthesizing to generic 
####################################################################################################

set_db / .syn_generic_effort $GEN_EFF
syn_generic
puts "Runtime & Memory after 'syn_generic'"
time_info GENERIC
report_dp > $_REPORTS_PATH/generic/${DESIGN}_datapath.rpt
write_snapshot -outdir $_REPORTS_PATH -tag generic
report_summary -directory $_REPORTS_PATH





####################################################################################################
## Synthesizing to gates
####################################################################################################


set_db / .syn_map_effort $MAP_OPT_EFF
syn_map
puts "Runtime & Memory after 'syn_map'"
time_info MAPPED
write_snapshot -outdir $_REPORTS_PATH -tag map
report_summary -directory $_REPORTS_PATH
report_dp > $_REPORTS_PATH/map/${DESIGN}_datapath.rpt



write_do_lec -revised_design fv_map -logfile ${_LOG_PATH}/rtl2intermediate.lec.log > ${_OUTPUTS_PATH}/rtl2intermediate.lec.do

## ungroup -threshold <value>

#######################################################################################################
## Optimize Netlist
#######################################################################################################

## Uncomment to remove assigns & insert tiehilo cells during Incremental synthesis
##set_db / .remove_assigns true 
##set_remove_assign_options -buffer_or_inverter <libcell> -design <design|subdesign> 
##set_db / .use_tiehilo_for_const <none|duplicate|unique> 
set_db / .syn_opt_effort $MAP_OPT_EFF
syn_opt
write_snapshot -outdir $_REPORTS_PATH -tag syn_opt
report_summary -directory $_REPORTS_PATH

puts "Runtime & Memory after 'syn_opt'"
time_info OPT




write_snapshot -outdir $_REPORTS_PATH -tag final
report_summary -directory $_REPORTS_PATH
write_hdl  > ${_OUTPUTS_PATH}/${DESIGN}_m.v
## write_script > ${_OUTPUTS_PATH}/${DESIGN}_m.script
write_sdc > ${_OUTPUTS_PATH}/${DESIGN}_m.sdc
write_sdf -design $design > ${_OUTPUTS_PATH}/${DESIGN}.netlist.sdf
write_db -design $design -all_root_attributes ${_OUTPUTS_PATH}/${DESIGN}.db

#################################
### write_do_lec
#################################


write_do_lec -golden_design fv_map -revised_design ${_OUTPUTS_PATH}/${DESIGN}_m.v -logfile  ${_LOG_PATH}/intermediate2final.lec.log > ${_OUTPUTS_PATH}/intermediate2final.lec.do
##Uncomment if the RTL is to be compared with the final netlist..
##write_do_lec -revised_design ${_OUTPUTS_PATH}/${DESIGN}_m.v -logfile ${_LOG_PATH}/rtl2final.lec.log > ${_OUTPUTS_PATH}/rtl2final.lec.do

puts "Final Runtime & Memory."
time_info FINAL
puts "============================"
puts "Synthesis Finished ........."
puts "============================"

file copy [get_db / .stdout_log] ${_LOG_PATH}/

##quit
