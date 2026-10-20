// Testbench para el multiplicador complejo
`timescale 1ns/1ps

module tb_multiplicador;

  // Parámetros
  parameter NB_INPUT    = 9;
  parameter NBF_INPUT   = 7;
  parameter NB_OUTPUT   = 19;
  parameter NBF_OUTPUT  = 14;
  parameter NB_TWIDDLE  = 9;
  parameter NBF_TWIDDLE = 7;
  parameter CLK_PERIOD  = 5; // Periodo de 5 ns

  // Señales
  reg                      clk;
  reg  signed [NB_INPUT-1:0] i_real;
  reg  signed [NB_INPUT-1:0] i_imag;

  // Salidas SCM (Karatsuba / Gauss)
  wire signed [NB_OUTPUT-1:0] o_real_scm;
  wire signed [NB_OUTPUT-1:0] o_imag_scm;

  // Salidas MCM (Canónico 4 multiplicadores)
  wire signed [NB_OUTPUT-1:0] o_real_mcm;
  wire signed [NB_OUTPUT-1:0] o_imag_mcm;

  // Alias retrocompatible
  wire signed [NB_OUTPUT-1:0] o_real = o_real_scm;
  wire signed [NB_OUTPUT-1:0] o_imag = o_imag_scm;

  // Variables para el modelo de referencia
  real ref_o_real, ref_o_imag;
  real twiddle_real = -0.375; // 9'b111010000 en formato Q2.7 (complemento a 2)
  real twiddle_imag = -0.921875; // 9'b110001010 en formato Q2.7 (complemento a 2)
  real i_real_float, i_imag_float;
  real sum_inputs, sum_twiddles, sub_twiddles;
  real mul_input_real, mul_input_imag, mul_twiddle;

  // Instancia DUT SCM (Karatsuba-Gauss, ARCH = 0)
  multiplicador #(
    .NB_INPUT   (NB_INPUT   ),
    .NBF_INPUT  (NBF_INPUT  ),
    .NB_OUTPUT  (NB_OUTPUT  ),
    .NBF_OUTPUT (NBF_OUTPUT ),
    .ARCH       (0          )
  ) dut_scm (
    .i_real     (i_real     ),
    .i_imag     (i_imag     ),
    .o_real     (o_real_scm ),
    .o_imag     (o_imag_scm )
  );

  // Instancia DUT MCM (Canónico 4 multiplicadores, ARCH = 1)
  multiplicador #(
    .NB_INPUT   (NB_INPUT   ),
    .NBF_INPUT  (NBF_INPUT  ),
    .NB_OUTPUT  (NB_OUTPUT  ),
    .NBF_OUTPUT (NBF_OUTPUT ),
    .ARCH       (1          )
  ) dut_mcm (
    .i_real     (i_real     ),
    .i_imag     (i_imag     ),
    .o_real     (o_real_mcm ),
    .o_imag     (o_imag_mcm )
  );

  // Alias dut adicional para scripts de Cadence Joules que busquen tb_multiplicador/dut
  multiplicador #(
    .NB_INPUT   (NB_INPUT   ),
    .NBF_INPUT  (NBF_INPUT  ),
    .NB_OUTPUT  (NB_OUTPUT  ),
    .NBF_OUTPUT (NBF_OUTPUT ),
    .ARCH       (0          )
  ) dut (
    .i_real     (i_real     ),
    .i_imag     (i_imag     ),
    .o_real     (),
    .o_imag     ()
  );

  // Generación del reloj
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Proceso de estímulo y verificación
  initial begin
    // Inicialización
    i_real = 0;
    i_imag = 0;

    // Esperar un ciclo inicial
    #CLK_PERIOD;

    // Generar 200 vectores aleatorios
    repeat (200) begin
      // Generar valores aleatorios en formato Q2.7 (NB_INPUT=9, NBF_INPUT=7)
      i_real = $random % (2**(NB_INPUT-1)); // Rango: -256 a 255
      i_imag = $random % (2**(NB_INPUT-1));

      // Convertir entradas a formato flotante para el modelo de referencia
      i_real_float = i_real / (2.0**NBF_INPUT);
      i_imag_float = i_imag / (2.0**NBF_INPUT);

      // Modelo de referencia (basado en las operaciones de scm_mult)
      sum_inputs = i_real_float + i_imag_float;
      sum_twiddles = twiddle_real + twiddle_imag;
      sub_twiddles = twiddle_real - twiddle_imag;
      mul_input_real = i_real_float * sum_twiddles;
      mul_input_imag = i_imag_float * sub_twiddles;
      mul_twiddle = twiddle_imag * sum_inputs;
      ref_o_real = mul_input_real - mul_twiddle;
      ref_o_imag = mul_input_imag + mul_twiddle;

      // Esperar medio ciclo para capturar salidas estables
      #(CLK_PERIOD/2);

      // Mostrar entradas, salidas de ambos DUTs y del modelo de referencia
      $display("Time: %0t ns | In: (%0d, %0d) | SCM: (%0d, %0d) | MCM: (%0d, %0d) | Ref: (%.4f, %.4f)",
               $time, i_real, i_imag,
               o_real_scm, o_imag_scm,
               o_real_mcm, o_imag_mcm,
               ref_o_real, ref_o_imag);

      // Verificación de equivalencia entre SCM y MCM
      if (o_real_scm !== o_real_mcm || o_imag_scm !== o_imag_mcm) begin
        $display("ERROR: Discrepancia funcional entre SCM y MCM en Time: %0t ns! SCM=(%0d,%0d), MCM=(%0d,%0d)",
                 $time, o_real_scm, o_imag_scm, o_real_mcm, o_imag_mcm);
      end

      // Verificación básica frente a referencia
      if ((o_real_scm/(2.0**NBF_OUTPUT) - ref_o_real) > 0.01 || (o_imag_scm/(2.0**NBF_OUTPUT) - ref_o_imag) > 0.01) begin
        $display("ERROR: Discrepancia con modelo analítico en Time: %0t ns", $time);
      end

      // Completar el ciclo
      #(CLK_PERIOD/2);
    end

    // Finalizar simulación
    #10;
    $display("Simulación finalizada. 20 pruebas completadas.");
    $finish;
  end

  // Dump de señales para depuración
  initial begin
    $dumpfile("multiplicador_tb.vcd");
    $dumpvars(0, tb_multiplicador);
  end

endmodule