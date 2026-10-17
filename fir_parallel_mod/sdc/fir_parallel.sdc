# SDC dedicado para fir_parallel con L=4 (TP7 Low Power)
# Reloj de muestreo base: 2.0 ns (500 MHz)
# Reloj del nucleo paralelo (L=4): 8.0 ns (125 MHz)

create_clock -name clk_parallel -period 8.0 [get_ports i_clock]

# Desactivar caminos temporales de coeficientes estaticos
set_false_path -from [get_ports i_coeffs*]

# Delays de entrada y salida referidos al reloj del nucleo
set_input_delay  0.5 -clock clk_parallel [all_inputs -no_clocks]
set_output_delay 0.5 -clock clk_parallel [all_outputs]
