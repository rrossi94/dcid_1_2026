#!/bin/bash
# ==============================================================================
# Script Maestro para Caracterizar Potencia en Cadence Joules
# Materia: DCID1 - Practico 7: Tecnicas de Reduccion de Potencia en Filtros FIR
# Autor: Ramiro Javier Rossi
# ==============================================================================

set -e

# Asegurar permisos de ejecucion
chmod +x "$0" 2>/dev/null || true

echo "================================================================================"
echo "  INICIANDO ESTIMACION DE POTENCIA EN CADENCE JOULES (4 ARQUITECTURAS FIR)"
echo "  PDK: GPDK045 (45 nm) - VDD: 1.08 V"
echo "================================================================================"

DESIGNS=("fir_serial" "fir_pipe_reg" "fir_parallel_orig" "fir_parallel_mod")

for d in "${DESIGNS[@]}"; do
    echo ""
    echo "================================================================================"
    echo ">>> EJECUTANDO JOULES PARA: $d"
    echo "================================================================================"
    TARGET_DESIGN=$d joules -batch -execute "set TARGET_DESIGN $d" -files run_joules.tcl
done

echo ""
echo "================================================================================"
echo ">>> CONSOLIDANDO RESULTADOS Y GENERANDO TABLAS..."
echo "================================================================================"
TARGET_DESIGN=summary joules -batch -execute "set TARGET_DESIGN summary" -files run_joules.tcl

echo ""
echo "================================================================================"
echo ">>> PROCESO FINALIZADO CON EXITO."
echo "    Revisa los resultados consolidados en:"
echo "    - reporte_potencia_general.rpt  (tabla en texto plano)"
echo "    - tabla_potencia.csv            (tabla para Excel / Python)"
echo "    - tabla_latex_snippet.tex       (filas listas para main.tex)"
echo "================================================================================"
