################################################################################
# Script de automatización para estimación de potencia en Cadence Joules
# Soporta estimación individual o simultánea de:
#   - SCM (Karatsuba / Gauss, 3 multiplicadores)
#   - MCM (Canónico directo, 4 multiplicadores)
# Utiliza las librerías GPDK045 instaladas en /home/amslib/PDKs/gpdk045v6
################################################################################

set libpath "/home/amslib/PDKs/gpdk045v6"

# Determinar arquitectura objetivo desde variable de entorno TARGET_ARCH o ARCH
# Valores admitidos: "SCM", "MCM", "BOTH" (por defecto: BOTH)
set target_arch "BOTH"
if {[info exists ::env(TARGET_ARCH)]} {
    set target_arch [string toupper $::env(TARGET_ARCH)]
} elseif {[info exists ::env(ARCH)]} {
    set target_arch [string toupper $::env(ARCH)]
}

# Localizar archivo VCD de conmutación
set vcd_candidates [list \
    "xrun_sim/multiplicador_tb.vcd" \
    "multiplicador_tb.vcd" \
    "../xrun_sim/multiplicador_tb.vcd" \
]
set vcd_file ""
foreach f $vcd_candidates {
    if {[file exists $f]} {
        set vcd_file $f
        break
    }
}

# Procedimiento de estimación de potencia modular
proc run_estimation {arch_name top_module dut_instance rpt_file} {
    global libpath vcd_file

    puts "\n========================================================================"
    puts ">>> INICIANDO ESTIMACION DE POTENCIA EN CADENCE JOULES"
    puts ">>> Arquitectura : $arch_name"
    puts ">>> Modulo Top   : $top_module"
    puts ">>> Instancia TB : $dut_instance"
    puts ">>> Reporte      : $rpt_file"
    puts "========================================================================\n"

    # 1. Cargar configuración MMMC (definida en mmmc.tcl)
    catch {read_mmmc mmmc.tcl}

    # 2. Cargar vista física LEF
    if {[file exists "${libpath}/gsclib045_tech/lef/gsclib045_tech.lef"]} {
        catch {
            read_physical -lef [list \
                "${libpath}/gsclib045_tech/lef/gsclib045_tech.lef" \
                "${libpath}/gsclib045/lef/gsclib045_macro.lef" \
            ]
        }
    } elseif {[file exists "3.5.lef"]} {
        catch {read_physical -lef "3.5.lef"}
    }

    # 3. Cargar el diseño RTL y elaborarlo
    read_hdl -sv rtl/multiplicador.v
    elaborate $top_module

    # 4. Inicializar diseño (aplica constraints y corners)
    init_design

    # 5. Mapeo de potencia con esfuerzo medio
    power_map -effort medium

    # 6. Cargar estímulos de conmutación desde el VCD de la simulación
    if {$vcd_file ne ""} {
        puts "INFO: Cargando archivo de estímulos $vcd_file para instancia $dut_instance..."
        read_stimulus -file $vcd_file -dut_instance $dut_instance -frame_count 10
        compute_power -mode time_based
    } else {
        puts "ADVERTENCIA: No se encontró multiplicador_tb.vcd. Calculando en modo vectorless..."
        compute_power -mode vectorless
    }

    # 7. Reportes de potencia
    puts "\n================== REPORTE DE POTENCIA GLOBAL ($arch_name) ==================\n"
    report_power
    report_power > $rpt_file

    puts "\n================== REPORTE JERARQUICO ($arch_name) ==================\n"
    catch {report_power -by_hierarchy}
    catch {report_power -by_hierarchy >> $rpt_file}

    puts "\n[INFO] Estimacion de $arch_name guardada exitosamente en $rpt_file\n"
}

# Ejecución según la arquitectura seleccionada
if {$target_arch eq "SCM"} {
    run_estimation "SCM (Karatsuba/Gauss)" "multiplicador_scm" "tb_multiplicador/dut_scm" "reporte_potencia_scm.rpt"
} elseif {$target_arch eq "MCM"} {
    run_estimation "MCM (Canónico 4 mults)" "multiplicador_mcm" "tb_multiplicador/dut_mcm" "reporte_potencia_mcm.rpt"
} else {
    # Por defecto estimar ambas arquitecturas
    puts "\n========================================================================"
    puts ">>> ESTIMACION DUAL: SCM y MCM"
    puts "========================================================================\n"
    
    # 1. Estimación SCM
    run_estimation "SCM (Karatsuba/Gauss)" "multiplicador_scm" "tb_multiplicador/dut_scm" "reporte_potencia_scm.rpt"
    
    # Intentar reset de diseño para estimar MCM en la misma sesión
    set reset_ok [catch {reset_design}]
    if {$reset_ok != 0} {
        set reset_ok [catch {delete_design -all}]
    }
    
    if {$reset_ok == 0} {
        run_estimation "MCM (Canónico 4 mults)" "multiplicador_mcm" "tb_multiplicador/dut_mcm" "reporte_potencia_mcm.rpt"
    } else {
        puts "\n[NOTA] Para estimar MCM en sesión independiente, ejecute:"
        puts "TARGET_ARCH=MCM joules -batch -files run_joules.tcl"
    }
}

puts "\n================== FLUJO DE JOULES COMPLETADO ==================\n"
