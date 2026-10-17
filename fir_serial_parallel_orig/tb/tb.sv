`timescale 1ns/1ps

module tb;

    // Parámetros
    localparam NB_IN     = 8;
    localparam NB_COEFFS = 8;
    localparam N_COEFFS  = 8;
    localparam CLK_PERIOD = 10;
    localparam N_SAMPLES = 50;   // cantidad de datos de prueba

    // Señales
    reg clk;
    reg rst;
    reg signed [NB_IN-1:0] din;
    reg signed [NB_IN-1:0] din_reg;
    reg signed [NB_COEFFS-1:0] coeffs [N_COEFFS-1:0];
    wire signed [NB_IN+NB_COEFFS+$clog2(N_COEFFS)-1:0] dout;


    // DUT
    fir_serial_parallel #(
        .NB_IN(NB_IN),
        .NB_COEFFS(NB_COEFFS),
        .N_COEFFS(N_COEFFS)
    ) dut (
        .i_clock(clk),
        .i_reset(rst),
        .i_data(din_reg),
        //.i_coeffs(coeffs),
        .o_data(dout)
    );
    


    // Clock
    initial begin
        clk = 0;

        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // memoria de datos leídos
    integer in_file, out_file;
    integer code;
    integer expected;
    integer sample;

    integer i;

    initial begin
        // abrir archivos
        in_file  = $fopen("../tb/input.txt", "r");
        out_file = $fopen("../tb/output.txt", "r");
        if (in_file == 0 || out_file == 0) begin
            $fatal("Error al abrir archivos de entrada/salida");
        end

        // Inicialización

        rst = 1;
        #20
        rst = 0;

        din = 0;

        // Coeficientes fijos 
        coeffs[0] = -7;
        coeffs[1] = -14;
        coeffs[2] = 20;
        coeffs[3] = 56;
        coeffs[4] = 56;
        coeffs[5] = 20;
        coeffs[6] = -14;
        coeffs[7] = -7;

        sample = 0;

        
    end

    always @(posedge clk) 
    begin
        // leer datos hasta fin de archivo
        
        if (!$feof(in_file) && !$feof(out_file)) 
        begin
            // leer un entero de cada archivo
            code = $fscanf(in_file,  "%d\n", din);
            din_reg <= din;

            
            if (sample >= N_COEFFS)
            begin
                assert(dout === expected)
                    else $error("Mismatch en muestra %0d: salida=%0d, esperado=%0d",
                                sample, dout, expected);
            end
            code = $fscanf(out_file, "%d\n", expected);

            sample = sample + 1;
        end

        if (sample >= N_SAMPLES)
        begin
            $display("Test completado, %0d muestras verificadas.", sample);
            $finish;
        end
    end

endmodule