#!/bin/bash
# Script para correr la estimacion de potencia automatizada en Cadence Joules
# Ejecuta el script maestro run_joules.tcl y genera la tabla comparativa

echo "=================================================================="
echo ">>> Ejecutando Cadence Joules en modo desatendido (batch)..."
echo "=================================================================="

joules -batch -files run_joules.tcl

echo ""
echo "=================================================================="
echo ">>> Proceso finalizado."
echo "    Revisa los resultados consolidados en:"
echo "    - reporte_potencia_general.rpt  (tabla en texto)"
echo "    - tabla_potencia.csv            (tabla para Excel / Python)"
echo "    - tabla_latex_snippet.tex       (filas listas para main.tex)"
echo "=================================================================="
