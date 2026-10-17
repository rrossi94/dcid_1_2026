//`timescale 1ns/1ps

module random_delay_bits #(
    parameter NB_IN     = 8,     // ancho del bus
    parameter MIN_DELAY = 5,     // retardo mínimo (timescale units)
    parameter MAX_DELAY = 20     // retardo máximo
)(
    input  wire [NB_IN-1:0] i_data,
    output reg  [NB_IN-1:0] o_data
);

    genvar b;
    generate
        for (b = 0; b < NB_IN; b = b + 1) begin : bit_delay
            always @(i_data[b]) begin
                integer rand_delay;
                rand_delay = $urandom_range(MIN_DELAY, MAX_DELAY);
                #(rand_delay) o_data[b] = i_data[b];  // aplica retardo independiente por bit
            end
        end
    endgenerate

endmodule