`timescale 1ns/1ps

module tb;

  localparam NB = 8;

  // Señales
  reg  [NB-1:0] i_coeffs_a;
  reg  [NB-1:0] i_coeffs_b;
  reg           i_sel;
  reg           i_clock_a;
  reg           i_clock_b;
  reg           i_reset;
  wire [NB-1:0] o_coeffs;

  // DUT
  sel_coeffs #(.NB(NB)) dut (
    .i_coeffs_a(i_coeffs_a),
    .i_coeffs_b(i_coeffs_b),
    .i_sel(i_sel),
    .i_clock_a(i_clock_a),
    .i_clock_b(i_clock_b),
    .i_reset(i_reset),
    .o_coeffs(o_coeffs)
  );

  // Clock A (20 ns)
  initial begin
    i_clock_a = 0;
    forever #10 i_clock_a = ~i_clock_a;
  end

  // Clock B (14 ns)
  initial begin
    i_clock_b = 0;
    forever #7 i_clock_b = ~i_clock_b;
  end

  // Reset
  initial begin
    i_reset = 1;
    i_sel   = 0;
    i_coeffs_a = 8'hAA;
    i_coeffs_b = 8'h55;

    #20;
    i_reset = 0;
  end

  // Cambiar selector y el dato correspondiente cada 10 ciclos de clock B
  initial begin
    @(negedge i_reset); // esperar a que termine reset
    repeat (200) begin
      repeat (11) @(posedge i_clock_b);
      i_sel = ~i_sel;  // cambiar selector

      if (i_sel)
        i_coeffs_b = $urandom; // solo cambia el seleccionado
      else
        i_coeffs_a = $urandom;
    end

    #50;
    $finish;
  end

  // Checker: solo cuando cambia la salida
  reg [NB-1:0] prev_o;
  initial prev_o = '0;

  always @(posedge i_clock_b) begin
    if (!i_reset) begin
      if (o_coeffs !== prev_o) begin
        if (i_sel && (o_coeffs !== i_coeffs_b)) begin
          $display("ERROR @%0t: sel=1 -> o_coeffs=%h, esperado=%h",
                   $time, o_coeffs, i_coeffs_b);
        end
        if (!i_sel && (o_coeffs !== i_coeffs_a)) begin
          $display("ERROR @%0t: sel=0 -> o_coeffs=%h, esperado=%h",
                   $time, o_coeffs, i_coeffs_a);
        end
      end
    end
    prev_o <= o_coeffs; // actualizar referencia
  end

  // Monitor
  initial begin
    $monitor("t=%0t | sel=%b A=%h B=%h -> out=%h",
             $time, i_sel, i_coeffs_a, i_coeffs_b, o_coeffs);
  end

  // Detectar un cambio en la salida
    property p_check_output_change;
    @(posedge i_clock_b) disable iff (i_reset)
        (o_coeffs != $past(o_coeffs)) |-> 
        ( (i_sel && (o_coeffs == i_coeffs_b)) ||
            (!i_sel && (o_coeffs == i_coeffs_a)) );
    endproperty

    // Assertion
    assert property (p_check_output_change)
    else $error("ASSERTION FAILED @%0t: o_coeffs=%h sel=%b A=%h B=%h",
                $time, o_coeffs, i_sel, i_coeffs_a, i_coeffs_b);

endmodule