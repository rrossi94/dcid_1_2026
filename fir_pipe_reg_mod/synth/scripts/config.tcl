
# name of design
set design "fir_pipe_reg"

# path to rtl and sdc containers, where the rtl code and sdc will be placed
set rtlpath "/home/finsaurralde/Escritorio/vlsi_course/modulo3"
set codepath "${rtlpath}/${design}/rtl"
set sdcpath  "${rtlpath}/${design}/sdc"

# create verilog file list and sdc lists
set vlist "fir_pipe_reg.sv"
set sdclist "fir_pipe_reg.sdc"

# libraries
#set libpath "/home/amslib/PDKs/gpdk045v6"
#set hvt_lib_slow "${libpath}/gsclib045_hvt/timing/slow_vdd1v0_basicCells_hvt.lib"
#set svt_lib_slow "${libpath}/gsclib045/timing/slow_vdd1v0_basicCells.lib"
#set lvt_lib_slow "${libpath}/gsclib045_lvt/timing/slow_vdd1v0_basicCells_lvt.lib"

# syn settings

set gen_eff     "medium"
set map_opt_eff "high"
