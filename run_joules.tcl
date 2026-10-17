################################################################################
# Script Maestro de Automatizacion para Estimacion de Potencia en Cadence Joules
# Materia: DCID1 - Practico 7: Tecnicas de Reduccion de Potencia en Filtros FIR
# Autor: Ramiro Javier Rossi
#
# Caracteriza automaticamente los 4 disenos de FIR y consolida los resultados:
#   1. fir_serial          (Baseline TP7, reloj 2.0 ns / 500 MHz)
#   2. fir_pipe_reg        (Alternativa Pipelined, reloj 2.0 ns / 500 MHz)
#   3. fir_parallel_orig   (Paralelo Original L=2, reloj 4.0 ns / 250 MHz)
#   4. fir_parallel_mod    (Paralelo Modificado L=4, reloj 8.0 ns / 125 MHz, false_path)
################################################################################

# Permite seleccionar un solo diseno mediante 'set TARGET_DESIGN <nombre>'
# Si no esta definida, por defecto corre los 4 casos:
if {![info exists TARGET_DESIGN]} {
    set TARGET_DESIGN "all"
}

set libpath "/home/amslib/PDKs/gpdk045v6"

puts "\n================================================================================"
puts "  INICIANDO FLUJO AUTOMATIZADO DE ESTIMACION EN CADENCE JOULES"
puts "  PDK: GPDK045 (45 nm) - VDD: 1.08 V - Corner: MMMC Nominal (25 C)"
puts "  Objetivo de corrida: $TARGET_DESIGN"
puts "================================================================================\n"

# 1. Cargar configuracion MMMC
if {[file exists "mmmc.tcl"]} {
    read_mmmc mmmc.tcl
} elseif {[file exists "../mmmc.tcl"]} {
    read_mmmc ../mmmc.tcl
} else {
    puts "ERROR: No se encontro el archivo mmmc.tcl"
}

# 2. Cargar vistas fisicas LEF
if {[file exists "${libpath}/gsclib045_tech/lef/gsclib045_tech.lef"]} {
    read_physical -lef [list \
        "${libpath}/gsclib045_tech/lef/gsclib045_tech.lef" \
        "${libpath}/gsclib045/lef/gsclib045_macro.lef" \
    ]
} elseif {[file exists "3.5.lef"]} {
    read_physical -lef "3.5.lef"
}

# Definicion de la matriz de los 4 casos de prueba
set design_configs [list \
    [list "fir_serial" \
          "FIR Serial (Baseline 2ns)" \
          [list "fir_serial_mod/rtl/fir_serial.sv"] \
          "fir_serial" \
          "fir_serial_mod/sdc/fir_serial.sdc" \
          [list "fir_serial_mod/run_sim/fir_tb.vcd" "fir_serial_mod/fir_tb.vcd" "fir_serial.vcd"] \
          "tb/dut" \
          "2.00 ns" "500 MHz" "1.08 V"] \
    [list "fir_pipe_reg" \
          "FIR Serial Pipelined (2ns)" \
          [list "fir_pipe_reg_mod/rtl/fir_pipe_reg.sv"] \
          "fir_pipe_reg" \
          "fir_pipe_reg_mod/sdc/fir_pipe_reg.sdc" \
          [list "fir_pipe_reg_mod/run_sim/fir_tb.vcd" "fir_pipe_reg_mod/fir_tb.vcd" "fir_pipe_reg.vcd"] \
          "tb/dut" \
          "2.00 ns" "500 MHz" "1.08 V"] \
    [list "fir_parallel_orig" \
          "FIR Paralelo Original (L=2)" \
          [list "fir_parallel_orig/rtl/fir_instance.sv" "fir_parallel_orig/rtl/fir_parallel.sv"] \
          "fir_parallel" \
          "fir_parallel_orig/sdc/fir_parallel.sdc" \
          [list "fir_parallel_orig/run_sim/fir_tb.vcd" "fir_parallel_orig/fir_tb.vcd" "fir_parallel_l2.vcd"] \
          "tb/dut" \
          "4.00 ns" "250 MHz" "1.08 V"] \
    [list "fir_parallel_mod" \
          "FIR Paralelo Modificado (L=4)" \
          [list "fir_parallel_mod/rtl/fir_instance.sv" "fir_parallel_mod/rtl/fir_parallel.sv"] \
          "fir_parallel" \
          "fir_parallel_mod/sdc/fir_parallel.sdc" \
          [list "fir_parallel_mod/run_sim/fir_tb.vcd" "fir_parallel_mod/fir_tb.vcd" "fir_parallel_l4.vcd"] \
          "tb/dut" \
          "8.00 ns" "125 MHz" "1.08 V"] \
]

# Estructura para almacenar resultados finales
set summary_rows [list]

foreach cfg $design_configs {
    set id        [lindex $cfg 0]
    set desc      [lindex $cfg 1]
    set rtl_files [lindex $cfg 2]
    set top_mod   [lindex $cfg 3]
    set sdc_file  [lindex $cfg 4]
    set vcd_list  [lindex $cfg 5]
    set dut_inst  [lindex $cfg 6]
    set tclk      [lindex $cfg 7]
    set freq      [lindex $cfg 8]
    set vdd       [lindex $cfg 9]

    if {$TARGET_DESIGN ne "all" && $TARGET_DESIGN ne $id} {
        continue
    }

    puts "\n================================================================================"
    puts ">>> PROCESANDO: $desc ($id)"
    puts "================================================================================\n"

    # Reset de diseno anterior en la sesion
    catch {reset_design}

    # Carga de RTL
    puts "INFO: Leyendo archivos RTL: $rtl_files..."
    read_hdl -sv $rtl_files
    puts "INFO: Elaborando top module: $top_mod..."
    elaborate $top_mod

    # Carga de restricciones SDC
    puts "INFO: Aplicando restricciones SDC desde $sdc_file..."
    if {[file exists $sdc_file]} {
        catch {update_constraint_mode -name constraint_mode_1 -sdc_files [list $sdc_file]}
        catch {read_sdc $sdc_file}
    } else {
        puts "ADVERTENCIA: No se encontro $sdc_file. Ejecutando init_design generico..."
    }
    init_design

    # Mapeo de potencia
    puts "INFO: Ejecutando power_map (effort medium)..."
    power_map -effort medium

    # Carga de estimulos VCD
    set found_vcd ""
    foreach v $vcd_list {
        if {[file exists $v]} {
            set found_vcd $v
            break
        }
    }

    if {$found_vcd ne ""} {
        puts "INFO: Estimulos encontrados en $found_vcd. Calculando potencia time-based..."
        read_stimulus -file $found_vcd -dut_instance $dut_inst -frame_count 10
        compute_power -mode time_based
    } else {
        puts "ADVERTENCIA: No se encontraron archivos VCD. Calculando en modo vectorless..."
        compute_power -mode vectorless
    }

    # Emision de reportes individuales
    set rpt_file "rpt_${id}.rpt"
    puts "INFO: Generando reporte detallado en $rpt_file..."
    report_power > $rpt_file
    catch {report_power -by_hierarchy >> $rpt_file}

    # Parseo de potencia desde el reporte generado
    set p_int "N/A"
    set p_sw  "N/A"
    set p_leak "N/A"
    set p_tot "N/A"

    if {[file exists $rpt_file]} {
        set fp [open $rpt_file r]
        while {[gets $fp line] >= 0} {
            if {[regexp -nocase {Internal\s+Power\s*:\s*([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)} $line -> val]} {
                set p_int [string trim $val]
            } elseif {[regexp -nocase {Switching\s+Power\s*:\s*([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)} $line -> val]} {
                set p_sw [string trim $val]
            } elseif {[regexp -nocase {Leakage\s+Power\s*:\s*([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)} $line -> val]} {
                set p_leak [string trim $val]
            } elseif {[regexp -nocase {Total\s+Power\s*:\s*([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)} $line -> val]} {
                set p_tot [string trim $val]
            }
        }
        close $fp
    }

    # Guardar fila para la tabla final
    lappend summary_rows [list $desc $tclk $freq $vdd $p_int $p_sw $p_leak $p_tot]
}

# ==============================================================================
# GENERACION DE LA TABLA RESUMEN COMPARATIVA
# ==============================================================================
set sep_line "+--------------------------------------+-----------+----------+-------+---------------+---------------+---------------+---------------+"
set hdr_fmt  "| %-36s | %-9s | %-8s | %-5s | %-13s | %-13s | %-13s | %-13s |"

set tabla_text ""
append tabla_text "\n========================================================================================================================\n"
append tabla_text "                              TABLA RESUMEN COMPARATIVA DE CONSUMO DE POTENCIA (CADENCE JOULES)\n"
append tabla_text "                                        PDK: GPDK045 (45 nm) - VDD Nominal: 1.08 V\n"
append tabla_text "========================================================================================================================\n"
append tabla_text "$sep_line\n"
append tabla_text [format $hdr_fmt "Diseno / Arquitectura" "Tclk" "Freq" "VDD" "P. Interna" "P. Switching" "P. Leakage" "P. Total"] "\n"
append tabla_text "$sep_line\n"

foreach row $summary_rows {
    append tabla_text [format $hdr_fmt \
        [lindex $row 0] \
        [lindex $row 1] \
        [lindex $row 2] \
        [lindex $row 3] \
        [lindex $row 4] \
        [lindex $row 5] \
        [lindex $row 6] \
        [lindex $row 7]] "\n"
}
append tabla_text "$sep_line\n"

# Imprimir por consola
puts $tabla_text

# Guardar en archivo de texto plano
set out_rpt [open "reporte_potencia_general.rpt" w]
puts $out_rpt $tabla_text
close $out_rpt
puts "INFO: Tabla resumen guardada en: reporte_potencia_general.rpt"

# Exportar en formato CSV
set out_csv [open "tabla_potencia.csv" w]
puts $out_csv "Arquitectura,Tclk,Frecuencia,VDD,P_Interna,P_Switching,P_Leakage,P_Total"
foreach row $summary_rows {
    puts $out_csv "[lindex $row 0],[lindex $row 1],[lindex $row 2],[lindex $row 3],[lindex $row 4],[lindex $row 5],[lindex $row 6],[lindex $row 7]"
}
close $out_csv
puts "INFO: Datos exportados a CSV en: tabla_potencia.csv"

# Exportar snippet en formato LaTeX listo para main.tex
set out_tex [open "tabla_latex_snippet.tex" w]
puts $out_tex "% --- Snippet generado automaticamente por run_joules.tcl ---"
foreach row $summary_rows {
    set name [lindex $row 0]
    set tc   [lindex $row 1]
    set vd   [lindex $row 3]
    set pi   [lindex $row 4]
    set ps   [lindex $row 5]
    set pl   [lindex $row 6]
    set pt   [lindex $row 7]
    puts $out_tex "$name & $tc & $vd & $pi & $ps & $pl & $pt \\\\"
}
close $out_tex
puts "INFO: Snippet LaTeX generado en: tabla_latex_snippet.tex"

puts "\n================================================================================"
puts "  FLUJO COMPLETADO EXITOSAMENTE PARA TODOS LOS DISENOS"
puts "================================================================================\n"
