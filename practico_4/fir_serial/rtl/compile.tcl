if {![info exists DESIGN_LIST]} {
    error "ERROR: Debe definir DESIGN_LIST (ej: -execute 'set DESIGN_LIST {fir_serial fir_serial_pipe}')"
}

set freq_list {100 200 300 400 500 600 700 800 900 1000}

set_db library /home/amslib/PDKs/gpdk045v6/gsclib045/timing/slow_vdd1v0_basicCells.lib

foreach DESIGN $DESIGN_LIST {
    puts "=============================================="
    puts "===> INICIANDO BARRIDO PARA: $DESIGN"
    puts "=============================================="
    
    file mkdir "reports_${DESIGN}"
    set csv_file [open "resumen_barrido_${DESIGN}.csv" w]
    puts $csv_file "Reporte de frecuencia maxima para diseño ${DESIGN}.sv"
    puts $csv_file "Freq_MHz,Periodo_ps,WNS_ps,Inst_Seq,Inst_Buf_Inv,Inst_Logic,Area_Total"

    foreach freq $freq_list {
        set period_ns [expr {1000.0 / $freq}]
        set period_ps [expr {1000000.0 / $freq}]
        
        if {[llength [get_db designs *]] > 0} {
            delete_obj [get_db designs *]
        }
        
        read_hdl "${DESIGN}.sv"
        elaborate $DESIGN
        
        create_clock -name "i_clock" -period $period_ns [get_ports i_clock]
        
        syn_generic
        syn_map
        syn_opt
        
        report_timing > "reports_${DESIGN}/timing_${freq}MHz.rpt"
        report_gates  > "reports_${DESIGN}/gates_${freq}MHz.rpt"
        
        set paths [report_timing -collection]
        set wns [expr {[llength $paths] > 0 ? [get_db $paths .slack] : "N/A"}]
        
        set seq_cnt  [llength [get_db insts -if {.is_sequential == true}]]
        set buf_cnt  [llength [get_db insts -if {.is_buffer == true || .is_inverter == true}]]
        set comb_cnt [llength [get_db insts -if {.is_combinational == true && .is_buffer == false && .is_inverter == false}]]
        set area_tot [get_db current_design .area]
        
        puts $csv_file "${freq},${period_ps},${wns},${seq_cnt},${buf_cnt},${comb_cnt},${area_tot}"
    }
    close $csv_file
}
exit
