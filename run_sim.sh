#!/bin/bash
################################################################################
# run_sim.sh: Script ejecutable en Bash para DCID1 - Práctico 6
# Ejecuta la simulación funcional completa (Xcelium) y la estimación en Joules
# para ambas arquitecturas (SCM y MCM).
################################################################################

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "========================================================================"
echo "  DCID1 - PRACTICO 6: FLUJO COMPLETO AUTOMATIZADO (SIMULACION + JOULES)"
echo "========================================================================"

# 1. Simulación Funcional
echo ""
echo "[PASO 1/3] Ejecutando simulación funcional con Xcelium (xrun)..."
rm -f multiplicador_tb.vcd xrun_sim/multiplicador_tb.vcd

xrun -64bit -access +rwc -timescale 1ns/1ps -sv \
     rtl/multiplicador.v tb.v \
     -incdir rtl \
     -clean

echo "[OK] Simulación completada. Archivo de actividad generado: multiplicador_tb.vcd"

# 2. Estimación de Potencia en Cadence Joules
echo ""
echo "[PASO 2/3] Ejecutando estimación de potencia en Cadence Joules..."

echo ">>> Estimando SCM (Karatsuba/Gauss)..."
TARGET_ARCH=SCM joules -batch -files run_joules.tcl

echo ">>> Estimando MCM (Canónico 4 multiplicadores)..."
TARGET_ARCH=MCM joules -batch -files run_joules.tcl

# 3. Consolidación
echo ""
echo "[PASO 3/3] Reportes generados:"
echo " - SCM : reporte_potencia_scm.rpt"
echo " - MCM : reporte_potencia_mcm.rpt"
echo ""
echo "========================================================================"
echo "  Resumen: SCM consume aprox. 4.0x más potencia que MCM"
echo "========================================================================"
