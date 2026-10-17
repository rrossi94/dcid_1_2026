create_clock -name clock -period 0.9 [get_ports i_clock]
set_input_delay   0.5 -clock clock [all_inputs]
set_output_delay  0.5 -clock clock [all_outputs]

create_generated_clock \
    -name clk_div4 \
    -source [get_ports i_clock] \
    -divide_by 4 \
    [get_pins pin:fir_serial_parallel_l4/gen_clock_reg/Q]
