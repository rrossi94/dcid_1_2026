#!/bin/bash
# ==============================================================================
# Script Maestro de Barrido de Frecuencia para DCID 1 - TP 4 (FIUBA)
# Ubicación: practico_4/
#
# Automatiza las corridas de síntesis de la Parte A y Parte B usando el toolset
# oficial de la cátedra (run.syn.sh, config.tcl, genus.syn.tcl, *.sdc).
#
# Rango unificado de períodos: 2.0 a 0.5 ns en pasos de 0.25 ns:
#   2.00 ns (500 MHz)
#   1.75 ns (571 MHz)
#   1.50 ns (667 MHz)
#   1.25 ns (800 MHz)
#   1.00 ns (1000 MHz)
#   0.75 ns (1333 MHz)
#   0.50 ns (2000 MHz)
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LATEX_ALL="${ROOT_DIR}/tablas_para_latex.txt"
RESUMEN_FMAX="${ROOT_DIR}/resumen_frecuencia_maxima.txt"
> "$LATEX_ALL"
> "$RESUMEN_FMAX"

# Lista unificada de períodos solicitada: 2.0 a 0.5 en pasos de 0.25 ns
PERIODOS_UNIFICADOS=(2.00 1.75 1.50 1.25 1.00 0.75 0.50)

# Función para ejecutar un experimento de barrido
# Argumentos:
#   $1: Nombre identificador (ej: A_base)
#   $2: Directorio relativo (ej: fir_serial)
#   $3: Archivo Verilog para vlist (ej: fir_serial.sv)
#   $4: Nombre del SDC (ej: fir_serial.sdc)
#   $5: Archivo CSV de salida
#   $6...: Lista opcional de períodos (si no se pasa, usa PERIODOS_UNIFICADOS)
run_experiment() {
    local ID="$1"
    local SUBDIR="$2"
    local VLIST="$3"
    local SDC_NAME="$4"
    local CSV_OUT="${ROOT_DIR}/$5"
    shift 5
    local PERIODS=("$@")
    if [ ${#PERIODS[@]} -eq 0 ]; then
        PERIODS=("${PERIODOS_UNIFICADOS[@]}")
    fi

    local SYNTH_DIR="${ROOT_DIR}/${SUBDIR}/synth"
    local SDC_FILE="${ROOT_DIR}/${SUBDIR}/sdc/${SDC_NAME}"
    local CONFIG_FILE="${SYNTH_DIR}/scripts/config.tcl"

    echo ""
    echo "======================================================================"
    echo " EJECUTANDO EXPERIMENTO: $ID ($SUBDIR)"
    echo " RTL vlist   : $VLIST"
    echo " SDC         : $SDC_NAME"
    echo " Períodos    : ${PERIODS[*]} ns"
    echo " Salida CSV  : $5"
    echo "======================================================================"

    # Verificaciones previas
    if [ ! -d "$SYNTH_DIR" ]; then
        echo "ERROR: No existe el directorio $SYNTH_DIR"
        return 1
    fi
    if [ ! -f "$SDC_FILE" ]; then
        echo "ERROR: No existe el archivo SDC $SDC_FILE"
        return 1
    fi

    # Asegurar rutas relativas en config.tcl
    sed -i 's|set codepath .*|set codepath "../rtl"|' "$CONFIG_FILE"
    sed -i 's|set sdcpath .*|set sdcpath "../sdc"|' "$CONFIG_FILE"

    # Asegurar que run.syn.sh use los flags -overwrite y -batch para modo desatendido y limpio
    sed -i 's/genus .*-f/genus -overwrite -batch -f/' "${SYNTH_DIR}/run.syn.sh" 2>/dev/null

    # Asegurar que genus.syn.tcl termine con exit (comando nativo de Tcl para salir limpiamente)
    sed -i 's/^##quit/exit/' "${SYNTH_DIR}/scripts/genus.syn.tcl"
    sed -i 's/^quit/exit/' "${SYNTH_DIR}/scripts/genus.syn.tcl"
    grep -q "^exit" "${SYNTH_DIR}/scripts/genus.syn.tcl" || echo "exit" >> "${SYNTH_DIR}/scripts/genus.syn.tcl"

    # Configurar vlist si se especifica
    if [ -n "$VLIST" ]; then
        sed -i "s/set vlist.*/set vlist \"$VLIST\"/" "$CONFIG_FILE"
    fi

    # Inicializar CSV
    echo "T_in_ns,f_in_MHz,WNS_ps,Estado,Secuenciales,Combinacionales,Buf_Inv,Area_Cell_um2,Area_Total_um2" > "$CSV_OUT"

    printf "\n%-9s %-9s %-10s %-12s %-6s %-6s %-8s %-13s\n" "Tin [ns]" "fin [MHz]" "WNS [ps]" "Estado" "Seq" "Comb" "Buf+Inv" "Área [um^2]"
    echo "--------------------------------------------------------------------------------------"

    echo "" >> "$LATEX_ALL"
    echo "% --- Tabla $ID ---" >> "$LATEX_ALL"

    local BEST_T=""
    local BEST_FREQ=""
    local BEST_SLACK=""

    for T_IN in "${PERIODS[@]}"; do
        # Calcular frecuencia en MHz: 1000 / T_IN
        local FREQ=$(awk -v t="$T_IN" 'BEGIN { printf "%.0f", 1000.0 / t }')

        # 1. Modificar el período en el archivo SDC (solo create_clock del reloj rápido)
        sed -i -E "/create_clock/s/(-period[[:space:]]+)[0-9.]+/\1$T_IN/" "$SDC_FILE"

        # 2. Entrar a synth y registrar carpeta previa para verificar si se generó una nueva
        cd "$SYNTH_DIR" || exit 1
        local PREV_REP=$(ls -td reports_* 2>/dev/null | head -n 1)

        local LOG_RUN="run_${ID}_${T_IN}ns.log"
        echo -n "  -> Corriendo Tin = ${T_IN} ns (${FREQ} MHz)... "
        timeout 360s ./run.syn.sh > "$LOG_RUN" 2>&1
        local RET=$?

        local LATEST_REP=$(ls -td reports_* 2>/dev/null | head -n 1)

        # 3. Detectar si la síntesis falló completamente
        local SYNTH_OK=1
        if [ -z "$LATEST_REP" ] || [ "$LATEST_REP" == "$PREV_REP" ] || [ ! -f "${LATEST_REP}/final_qor.rpt" ]; then
            SYNTH_OK=0
        fi

        local SLACK="N/A"
        local ESTADO="FALLO"
        local SEQ="0"
        local INV="0"
        local COMB="0"
        local CELL_AREA="0.0"
        local TOTAL_AREA="0.0"

        if [ $SYNTH_OK -eq 1 ]; then
            echo "Listo."

            # Extraer Slack / WNS
            if [ -f "${LATEST_REP}/final_time.rpt" ]; then
                SLACK=$(grep -i "slack" "${LATEST_REP}/final_time.rpt" | head -n 1 | grep -oE "[-+]?[0-9]+(\.[0-9]+)?")
            fi
            if [ -z "$SLACK" ] || [ "$SLACK" == "N/A" ]; then
                if [ -f "${LATEST_REP}/final_qor.rpt" ]; then
                    SLACK=$(awk '$1 == "clock" {print $2}' "${LATEST_REP}/final_qor.rpt" 2>/dev/null)
                fi
            fi
            [ -z "$SLACK" ] && SLACK="N/A"

            # Evaluar si cumple timing o viola
            if [ "$SLACK" != "N/A" ]; then
                local MET=$(awk -v s="$SLACK" 'BEGIN { if (s >= 0) print 1; else print 0 }')
                if [ "$MET" -eq 1 ]; then
                    ESTADO="CUMPLE"
                    BEST_T="$T_IN"
                    BEST_FREQ="$FREQ"
                    BEST_SLACK="$SLACK"
                else
                    ESTADO="VIOLA"
                fi
            else
                ESTADO="FALLO"
            fi

            # Conteo de Celdas (de final_gates.rpt)
            if [ -f "${LATEST_REP}/final_gates.rpt" ]; then
                SEQ=$(awk '$1 == "sequential" {print $2}' "${LATEST_REP}/final_gates.rpt")
                INV=$(awk '$1 == "inverter" {print $2}' "${LATEST_REP}/final_gates.rpt")
                COMB=$(awk '$1 == "logic" {print $2}' "${LATEST_REP}/final_gates.rpt")
            fi
            [ -z "$SEQ" ] && SEQ="0"
            [ -z "$INV" ] && INV="0"
            [ -z "$COMB" ] && COMB="0"

            # Área (de final_qor.rpt)
            if [ -f "${LATEST_REP}/final_qor.rpt" ]; then
                CELL_AREA=$(grep -m 1 "Cell Area" "${LATEST_REP}/final_qor.rpt" | awk '{print $NF}')
                TOTAL_AREA=$(grep -m 1 "Total Area (Cell+Physical+Net)" "${LATEST_REP}/final_qor.rpt" | awk '{print $NF}')
            fi
            [ -z "$CELL_AREA" ] && CELL_AREA="0.0"
            [ -z "$TOTAL_AREA" ] && TOTAL_AREA="0.0"
        else
            echo "FALLÓ (ver $LOG_RUN)."
            SLACK="FALLO"
            ESTADO="NO_CONVERGE"
            SEQ="-"
            COMB="-"
            INV="-"
            CELL_AREA="-"
            TOTAL_AREA="-"
        fi

        # Volver al raíz
        cd "$ROOT_DIR" || exit 1

        # Imprimir fila en terminal
        printf "%-9s %-9s %-10s %-12s %-6s %-6s %-8s %-13s\n" "$T_IN" "$FREQ" "$SLACK" "$ESTADO" "$SEQ" "$COMB" "$INV" "$CELL_AREA"

        # Guardar en CSV
        echo "${T_IN},${FREQ},${SLACK},${ESTADO},${SEQ},${COMB},${INV},${CELL_AREA},${TOTAL_AREA}" >> "$CSV_OUT"

        # Formato para LaTeX (comas decimales)
        local T_IN_LATEX=$(echo "$T_IN" | tr '.' ',')
        local SLACK_LATEX=$(echo "$SLACK" | tr '.' ',')
        local CELL_AREA_LATEX=$(echo "$CELL_AREA" | tr '.' ',')
        echo "${T_IN_LATEX} & ${FREQ} & ${SLACK_LATEX} & ${SEQ} & ${COMB} & ${INV} & ${CELL_AREA_LATEX} \\\\" >> "$LATEX_ALL"

        # Corte temprano (Early Exit): si falló o violó timing, no tiene sentido probar frecuencias más altas
        if [ "$ESTADO" == "VIOLA" ] || [ "$ESTADO" == "NO_CONVERGE" ] || [ "$ESTADO" == "FALLO" ]; then
            echo ""
            echo "  ⚠️  [LÍMITE ALCANZADO] El diseño no cerró a Tin = ${T_IN} ns ($ESTADO)."
            echo "      Se corta el barrido de $ID ya que frecuencias superiores también fallarán."
            echo ""
            break
        fi
    done

    echo "--------------------------------------------------------------------------------------"
    if [ -n "$BEST_FREQ" ]; then
        echo "🏆 FRECUENCIA MÁXIMA ESTIMADA PARA $ID: $BEST_FREQ MHz (Tin = $BEST_T ns, Slack = +$BEST_SLACK ps)"
        echo "$ID: fmax = $BEST_FREQ MHz (Tin = $BEST_T ns, Slack = +$BEST_SLACK ps)" >> "$RESUMEN_FMAX"
    else
        echo "⚠️  ADVERTENCIA: Ningún punto cumplió timing (o todos fallaron)."
        echo "$ID: No se encontró punto con Slack >= 0" >> "$RESUMEN_FMAX"
    fi
    echo "Resultados guardados en: $5"
}

# Selección por argumentos
TARGET="${1:-all}"

case "$TARGET" in
    A_base)
        run_experiment "A_base" "fir_serial" "fir_serial.sv" "fir_serial.sdc" "reporte_A_base.csv"
        ;;
    A_pipe)
        run_experiment "A_pipe" "fir_serial" "fir_serial_pipe.sv" "fir_serial.sdc" "reporte_A_pipe.csv"
        ;;
    A)
        run_experiment "A_base" "fir_serial" "fir_serial.sv" "fir_serial.sdc" "reporte_A_base.csv"
        run_experiment "A_pipe" "fir_serial" "fir_serial_pipe.sv" "fir_serial.sdc" "reporte_A_pipe.csv"
        ;;
    B_L2)
        run_experiment "B_L2" "fir_serial_parallel" "fir_serial_parallel.sv fir_parallel.sv fir_instance.sv" "fir_serial_parallel.sdc" "reporte_B_L2.csv"
        ;;
    B_L4)
        run_experiment "B_L4" "fir_serial_parallel_l4" "fir_serial_parallel_l4.sv fir_parallel.sv fir_instance.sv" "fir_serial_parallel_l4.sdc" "reporte_B_L4.csv"
        ;;
    B_L4_mod|B_L4_modified)
        run_experiment "B_L4_mod" "fir_serial_parallel_l4_modified" "fir_serial_parallel_l4.sv fir_parallel.sv fir_instance.sv" "fir_serial_parallel_l4_modified.sdc" "reporte_B_L4_modified.csv"
        ;;
    B)
        run_experiment "B_L2" "fir_serial_parallel" "fir_serial_parallel.sv fir_parallel.sv fir_instance.sv" "fir_serial_parallel.sdc" "reporte_B_L2.csv"
        run_experiment "B_L4" "fir_serial_parallel_l4" "fir_serial_parallel_l4.sv fir_parallel.sv fir_instance.sv" "fir_serial_parallel_l4.sdc" "reporte_B_L4.csv"
        run_experiment "B_L4_mod" "fir_serial_parallel_l4_modified" "fir_serial_parallel_l4.sv fir_parallel.sv fir_instance.sv" "fir_serial_parallel_l4_modified.sdc" "reporte_B_L4_modified.csv"
        ;;
    all)
        echo "======================================================================"
        echo " INICIANDO BARRIDO COMPLETO UNIFICADO (2.0 a 0.5 ns, paso 0.25 ns)"
        echo "======================================================================"
        run_experiment "A_base" "fir_serial" "fir_serial.sv" "fir_serial.sdc" "reporte_A_base.csv"
        run_experiment "A_pipe" "fir_serial" "fir_serial_pipe.sv" "fir_serial.sdc" "reporte_A_pipe.csv"
        run_experiment "B_L2" "fir_serial_parallel" "fir_serial_parallel.sv fir_parallel.sv fir_instance.sv" "fir_serial_parallel.sdc" "reporte_B_L2.csv"
        run_experiment "B_L4" "fir_serial_parallel_l4" "fir_serial_parallel_l4.sv fir_parallel.sv fir_instance.sv" "fir_serial_parallel_l4.sdc" "reporte_B_L4.csv"
        run_experiment "B_L4_mod" "fir_serial_parallel_l4_modified" "fir_serial_parallel_l4.sv fir_parallel.sv fir_instance.sv" "fir_serial_parallel_l4_modified.sdc" "reporte_B_L4_modified.csv"
        ;;
    *)
        echo "Opción no reconocida: $TARGET"
        echo "Uso: ./barrido.sh [all | A | B | A_base | A_pipe | B_L2 | B_L4 | B_L4_mod]"
        exit 1
        ;;
esac

echo ""
echo "======================================================================"
echo " TODAS LAS CORRIDAS FINALIZADAS"
echo "======================================================================"
echo "--- RESUMEN DE FRECUENCIAS MÁXIMAS OBTENIDAS ---"
cat "$RESUMEN_FMAX"
echo "------------------------------------------------"
echo " Reportes CSV generados en : $ROOT_DIR"
echo " Filas para main.tex en    : $LATEX_ALL"
echo "======================================================================"
