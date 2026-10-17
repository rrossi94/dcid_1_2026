create_clock -name clock -period 0.9 [get_ports i_clock]
set_input_delay   0.5 -clock clock [all_inputs]
set_output_delay  0.5 -clock clock [all_outputs]

#set_false_path -from [get_ports i_coeffs*]

#create_generated_clock -divide_by 2 -source [get_ports i_clock] [get_nets {gen_clock}]  
create_generated_clock \
    -name clk_div2 \
    -source [get_ports i_clock] \
    -divide_by 2 \
    [get_pins pin:fir_serial_parallel/gen_clock_reg/Q]