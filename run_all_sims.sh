#!/bin/bash
# Script para compilar y simular las 4 variantes de FIR con Xcelium
# Genera los archivos VCD de actividad para Cadence Joules

echo "=================================================================="
echo ">>> (1/4) Simulando fir_serial_mod (reloj 2 ns)..."
echo "=================================================================="
(cd fir_serial_mod/run_sim && ./run)

echo "=================================================================="
echo ">>> (2/4) Simulando fir_pipe_reg_mod (pipelined, reloj 2 ns)..."
echo "=================================================================="
(cd fir_pipe_reg_mod/run_sim && ./run)

echo "=================================================================="
echo ">>> (3/4) Simulando fir_parallel_orig (L=2, reloj 4 ns)..."
echo "=================================================================="
(cd fir_parallel_orig/run_sim && ./run)

echo "=================================================================="
echo ">>> (4/4) Simulando fir_parallel_mod (L=4, reloj 8 ns)..."
echo "=================================================================="
(cd fir_parallel_mod/run_sim && ./run)

echo "=================================================================="
echo ">>> TODAS LAS SIMULACIONES FINALIZADAS CON EXITO"
echo "    Archivos VCD generados para el flujo de Cadence Joules."
echo "=================================================================="
