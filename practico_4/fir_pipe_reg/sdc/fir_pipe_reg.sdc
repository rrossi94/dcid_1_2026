create_clock -name clock -period 1.6 [get_ports i_clock]
set_input_delay   0.5 -clock clock [all_inputs]
set_output_delay  0.5 -clock clock [all_outputs]
