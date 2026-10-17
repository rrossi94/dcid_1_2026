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
  wire signed [NB_OUTPUT-1:0] o_real;
  wire signed [NB_OUTPUT-1:0] o_imag;

  // Variables para el modelo de referencia
  real ref_o_real, ref_o_imag;
  real twiddle_real = -0.375; // 9'b111010000 en formato Q2.7 (complemento a 2)
  real twiddle_imag = -0.921875; // 9'b110001010 en formato Q2.7 (complemento a 2)
  real i_real_float, i_imag_float;
  real sum_inputs, sum_twiddles, sub_twiddles;
  real mul_input_real, mul_input_imag, mul_twiddle;

  // Instancia del DUT (Device Under Test)
  multiplicador #(
    .NB_INPUT(NB_INPUT),
    .NBF_INPUT(NBF_INPUT),
    .NB_OUTPUT(NB_OUTPUT),
    .NBF_OUTPUT(NBF_OUTPUT)
  ) dut (
    .i_real(i_real),
    .i_imag(i_imag),
    .o_real(o_real),
    .o_imag(o_imag)
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

    // Generar 20 valores aleatorios
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

      // Mostrar entradas, salidas del DUT y del modelo de referencia
      $display("Time: %0t ns | i_real: %0d (%.4f) | i_imag: %0d (%.4f) | o_real: %0d (%.4f) | o_imag: %0d (%.4f) | ref_o_real: %.4f | ref_o_imag: %.4f",
               $time, i_real, i_real_float, i_imag, i_imag_float,
               o_real, o_real/(2.0**NBF_OUTPUT), o_imag, o_imag/(2.0**NBF_OUTPUT),
               ref_o_real, ref_o_imag);

      // Verificación básica
      if ((o_real/(2.0**NBF_OUTPUT) - ref_o_real) > 0.01 || (o_imag/(2.0**NBF_OUTPUT) - ref_o_imag) > 0.01) begin
        $display("ERROR: Discrepancia en Time: %0t ns", $time);
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
