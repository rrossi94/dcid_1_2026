create_clock -name vclock -period 5
set_input_delay   0.5 -clock vclock [all_inputs]
set_output_delay  0.5 -clock vclock [all_outputs]
