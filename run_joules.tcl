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

# Permite seleccionar el diseno mediante variable Tcl o variable de entorno
if {![info exists TARGET_DESIGN]} {
    if {[info exists ::env(TARGET_DESIGN)]} {
        set TARGET_DESIGN $::env(TARGET_DESIGN)
    } else {
        set TARGET_DESIGN "all"
    }
}

set libpath "/home/amslib/PDKs/gpdk045v6"

# Matriz completa de configuracion para los 4 disenos de prueba
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

# ==============================================================================
# Procedimiento: Parseo de potencia desde el reporte individual de Joules
# ==============================================================================
proc parse_joules_report {rpt_file} {
    set p_int  "N/A"
    set p_sw   "N/A"
    set p_leak "N/A"
    set p_tot  "N/A"

    if {![file exists $rpt_file]} {
        return [list $p_int $p_sw $p_leak $p_tot]
    }

    set fp [open $rpt_file r]
    while {[gets $fp line] >= 0} {
        # Formato de lineas individuales: Internal Power: <val>
        if {[regexp -nocase {(?:Total\s+)?Internal\s+Power\s*:\s*([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)} $line -> val]} {
            set p_int [string trim $val]
        } elseif {[regexp -nocase {(?:Total\s+)?Switching\s+Power\s*:\s*([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)} $line -> val]} {
            set p_sw [string trim $val]
        } elseif {[regexp -nocase {(?:Total\s+)?Leakage\s+Power\s*:\s*([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)} $line -> val]} {
            set p_leak [string trim $val]
        } elseif {[regexp -nocase {^Total\s+Power\s*:\s*([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)} $line -> val]} {
            set p_tot [string trim $val]
        # Formato tabular Joules / Genus: Total  <int>  <sw>  <leak>  <tot>
        } elseif {[regexp -nocase {^\s*Total\s+([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)\s+([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)\s+([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)\s+([0-9.eE+-]+(?:\s*[a-zA-Z]+)?)} $line -> pi ps pl pt]} {
            if {$p_int eq "N/A"}  { set p_int  [string trim $pi] }
            if {$p_sw eq "N/A"}   { set p_sw   [string trim $ps] }
            if {$p_leak eq "N/A"} { set p_leak [string trim $pl] }
            if {$p_tot eq "N/A"}  { set p_tot  [string trim $pt] }
        }
    }
    close $fp
    return [list $p_int $p_sw $p_leak $p_tot]
}

# ==============================================================================
# Procedimiento: Generacion y exportacion de las tablas consolidadas
# ==============================================================================
proc generate_consolidated_tables {configs} {
    set summary_rows [list]
    foreach cfg $configs {
        set id   [lindex $cfg 0]
        set desc [lindex $cfg 1]
        set tclk [lindex $cfg 7]
        set freq [lindex $cfg 8]
        set vdd  [lindex $cfg 9]
        set rpt_file "rpt_${id}.rpt"

        set p_vals [parse_joules_report $rpt_file]
        set p_int  [lindex $p_vals 0]
        set p_sw   [lindex $p_vals 1]
        set p_leak [lindex $p_vals 2]
        set p_tot  [lindex $p_vals 3]

        lappend summary_rows [list $desc $tclk $freq $vdd $p_int $p_sw $p_leak $p_tot]
    }

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

    puts $tabla_text

    # Guardar reporte en archivo de texto plano
    set out_rpt [open "reporte_potencia_general.rpt" w]
    puts $out_rpt $tabla_text
    close $out_rpt
    puts "INFO: Tabla resumen guardada en: reporte_potencia_general.rpt"

    # Exportar archivo CSV
    set out_csv [open "tabla_potencia.csv" w]
    puts $out_csv "Arquitectura,Tclk,Frecuencia,VDD,P_Interna,P_Switching,P_Leakage,P_Total"
    foreach row $summary_rows {
        puts $out_csv "[lindex $row 0],[lindex $row 1],[lindex $row 2],[lindex $row 3],[lindex $row 4],[lindex $row 5],[lindex $row 6],[lindex $row 7]"
    }
    close $out_csv
    puts "INFO: Datos exportados a CSV en: tabla_potencia.csv"

    # Exportar filas listas para insertar en main.tex
    set out_tex [open "tabla_latex_snippet.tex" w]
    puts $out_tex "% --- Snippet generado automaticamente por Cadence Joules ---"
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
}

# ==============================================================================
# MODO RESUMEN / CONSOLIDACION
# ==============================================================================
if {$TARGET_DESIGN eq "summary" || $TARGET_DESIGN eq "consolidate"} {
    puts "\n================================================================================"
    puts "  CONSOLIDANDO REPORTES DE POTENCIA EXISTENTES (CADENCE JOULES)"
    puts "================================================================================\n"
    generate_consolidated_tables $design_configs
    return
}

# ==============================================================================
# EJECUCION DE ESTIMACION DE POTENCIA
# ==============================================================================
puts "\n================================================================================"
puts "  INICIANDO ESTIMACION DE POTENCIA EN CADENCE JOULES"
puts "  PDK: GPDK045 (45 nm) - VDD: 1.08 V - Corner: MMMC Nominal (25 C)"
puts "  Objetivo de corrida: $TARGET_DESIGN"
puts "================================================================================\n"

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

    # Informar SDC activo para que mmmc.tcl configure el constraint_mode correspondiente
    set CURRENT_SDC $sdc_file

    # 1. Cargar configuracion MMMC (si aun no fue cargada)
    if {![info exists MMMC_INITIALIZED]} {
        if {[file exists "mmmc.tcl"]} {
            read_mmmc mmmc.tcl
            set MMMC_INITIALIZED 1
        } elseif {[file exists "../mmmc.tcl"]} {
            read_mmmc ../mmmc.tcl
            set MMMC_INITIALIZED 1
        } else {
            puts "ERROR: No se encontro el archivo mmmc.tcl"
        }
    }

    # 2. Cargar vistas fisicas LEF (si aun no fueron cargadas)
    if {![info exists LEF_INITIALIZED]} {
        if {[file exists "${libpath}/gsclib045_tech/lef/gsclib045_tech.lef"]} {
            read_physical -lef [list \
                "${libpath}/gsclib045_tech/lef/gsclib045_tech.lef" \
                "${libpath}/gsclib045/lef/gsclib045_macro.lef" \
            ]
            set LEF_INITIALIZED 1
        } elseif {[file exists "3.5.lef"]} {
            read_physical -lef "3.5.lef"
            set LEF_INITIALIZED 1
        }
    }

    # 3. Cargar RTL y elaborar top module
    puts "INFO: Leyendo archivos RTL: $rtl_files..."
    read_hdl -sv $rtl_files
    puts "INFO: Elaborando top module: $top_mod..."
    elaborate $top_mod

    # 4. Inicializar diseno (Joules aplica automaticamente el constraint_mode de mmmc.tcl)
    puts "INFO: Inicializando diseno (init_design)..."
    init_design

    # 5. Mapeo preliminar de potencia
    puts "INFO: Ejecutando power_map (effort medium)..."
    power_map -effort medium

    # 6. Carga de estimulos VCD y calculo de potencia
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
        puts "ADVERTENCIA: No se encontro archivo VCD. Calculando en modo vectorless..."
        compute_power -mode vectorless
    }

    # 7. Generacion de reportes individuales
    set rpt_file "rpt_${id}.rpt"
    puts "INFO: Generando reporte detallado en $rpt_file..."
    report_power > $rpt_file
    catch {report_power -by_hierarchy >> $rpt_file}

    # Parsear y presentar resumen de este diseno por terminal
    set p_vals [parse_joules_report $rpt_file]
    puts "\n--------------------------------------------------------------------------------"
    puts "  RESUMEN DE POTENCIA: $desc"
    puts "  - Potencia Interna   : [lindex $p_vals 0]"
    puts "  - Potencia Switching : [lindex $p_vals 1]"
    puts "  - Potencia Leakage   : [lindex $p_vals 2]"
    puts "  - Potencia Total     : [lindex $p_vals 3]"
    puts "--------------------------------------------------------------------------------\n"
}

# Si la ejecucion fue "all" dentro de esta misma sesion, generar las tablas consolidadas
if {$TARGET_DESIGN eq "all"} {
    generate_consolidated_tables $design_configs
}
