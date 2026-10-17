`timescale 1ns/1ps

module tb;

    localparam NB_IN       = 8;
    localparam NB_COEFFS   = 8;
    localparam N_COEFFS    = 8;
    localparam PARALLELISM = 4;
    localparam NB_OUT      = NB_IN + NB_COEFFS + $clog2(N_COEFFS);
    localparam CLK_PERIOD  = 8; // Reloj del nucleo paralelo L=4 (125 MHz = 8 ns)

    // Senales
    reg clk;
    reg signed [NB_IN-1:0] din [PARALLELISM-1:0];
    reg signed [NB_COEFFS-1:0] coeffs [N_COEFFS-1:0];
    wire signed [NB_OUT-1:0] dout [PARALLELISM-1:0];

    // DUT: fir_parallel directo con L=4
    fir_parallel #(
        .NB_IN(NB_IN),
        .NB_COEFFS(NB_COEFFS),
        .N_COEFFS(N_COEFFS),
        .PARALLELISM(PARALLELISM)
    ) dut (
        .i_data(din),
        .i_coeffs(coeffs),
        .i_clock(clk),
        .o_data(dout)
    );

    // Reloj a 8.0 ns
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2.0) clk = ~clk;
    end

    // Volcado de trazas de actividad VCD para Joules
    initial begin
        $dumpfile("fir_tb.vcd");
        $dumpvars(0, tb);
    end

    integer in_file, i, sample;
    integer temp_val;

    initial begin
        // Coeficientes constantes
        coeffs[0] = -7;
        coeffs[1] = -14;
        coeffs[2] = 20;
        coeffs[3] = 56;
        coeffs[4] = 56;
        coeffs[5] = 20;
        coeffs[6] = -14;
        coeffs[7] = -7;

        for(i=0; i<PARALLELISM; i=i+1)
            din[i] = 0;

        in_file = $fopen("../tb/input.txt", "r");
        if (in_file == 0) begin
            $display("Nota: input.txt no encontrado, usando estimulos pseudoaleatorios...");
        end

        sample = 0;
    end

    always @(posedge clk) begin
        if (in_file != 0 && !$feof(in_file)) begin
            for(i=0; i<PARALLELISM; i=i+1) begin
                if (!$feof(in_file)) begin
                    void'($fscanf(in_file, "%d\n", temp_val));
                    din[i] <= temp_val[NB_IN-1:0];
                end else begin
                    din[i] <= $random;
                end
            end
        end else begin
            for(i=0; i<PARALLELISM; i=i+1)
                din[i] <= $random;
        end

        sample <= sample + 1;
        if (sample >= 50) begin
            $display("Simulacion paralela L=4 finalizada con exito.");
            $finish;
        end
    end

endmodule
