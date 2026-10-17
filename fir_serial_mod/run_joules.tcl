################################################################################
# Script de automatizacion para estimacion de potencia en Cadence Joules
# Diseno: fir_serial (Baseline TP7, reloj 2.0 ns / 500 MHz)
################################################################################
set libpath "/home/amslib/PDKs/gpdk045v6"

# 1. Cargar configuracion MMMC (busca en directorio local o padre)
if {[file exists "mmmc.tcl"]} {
    read_mmmc mmmc.tcl
} elseif {[file exists "../mmmc.tcl"]} {
    read_mmmc ../mmmc.tcl
} else {
    puts "ERROR: No se encontro mmmc.tcl"
}

# 2. Cargar vista fisica LEF
if {[file exists "${libpath}/gsclib045_tech/lef/gsclib045_tech.lef"]} {
    read_physical -lef [list \
        "${libpath}/gsclib045_tech/lef/gsclib045_tech.lef" \
        "${libpath}/gsclib045/lef/gsclib045_macro.lef" \
    ]
} elseif {[file exists "3.5.lef"]} {
    read_physical -lef "3.5.lef"
} elseif {[file exists "../3.5.lef"]} {
    read_physical -lef "../3.5.lef"
}

# 3. Cargar RTL y elaborar
read_hdl -sv rtl/fir_serial.sv
elaborate fir_serial

# 4. Inicializar diseno aplicando restricciones SDC
init_design

# 5. Mapeo preliminar de potencia
power_map -effort medium

# 6. Cargar estimulos de conmutacion (VCD generado por Xcelium)
set vcd_candidates [list \
    "run_sim/fir_tb.vcd" \
    "fir_tb.vcd" \
    "../fir_tb.vcd" \
]
set vcd_file ""
foreach f $vcd_candidates {
    if {[file exists $f]} {
        set vcd_file $f
        break
    }
}

if {$vcd_file ne ""} {
    puts "INFO: Cargando archivo de estimulos $vcd_file..."
    read_stimulus -file $vcd_file -dut_instance tb/dut -frame_count 10
    compute_power -mode time_based
} else {
    puts "ADVERTENCIA: No se encontro fir_tb.vcd. Calculando en modo vectorless..."
    compute_power -mode vectorless
}

# 7. Reportes de potencia
puts "\n================== REPORTE DE POTENCIA GLOBAL (fir_serial) ==================\n"
report_power
report_power > reporte_potencia.rpt

puts "\n================== REPORTE DE POTENCIA POR JERARQUIA ==================\n"
catch {report_power -by_hierarchy}
catch {report_power -by_hierarchy >> reporte_potencia.rpt}

puts "\nEstimacion completada exitosamente. Reporte guardado en reporte_potencia.rpt\n"
