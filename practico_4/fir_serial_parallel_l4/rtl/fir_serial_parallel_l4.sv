module fir_serial_parallel_l4 #(
  NB_IN = 8,
  NB_COEFFS = 8,
  N_COEFFS = 8,
  PARALLELISM = 4,
  NB_OUT = NB_IN + NB_COEFFS + $clog2(N_COEFFS),
  NB_CNT = $clog2(PARALLELISM)
)
( 
  input signed [NB_IN -1 : 0] i_data,
  input i_reset,
  input i_clock,
  output signed [NB_OUT-1 : 0] o_data
);

  wire signed [NB_COEFFS -1 : 0] coeffs [N_COEFFS -1 : 0];

  // Coeficientes fijos (sin cambios respecto de la catedra)
  assign coeffs[0] = 8'b1111_1001;
  assign coeffs[1] = 8'b1111_0010;
  assign coeffs[2] = 8'b0001_0100;
  assign coeffs[3] = 8'b0011_1000;
  assign coeffs[4] = 8'b0011_1000;
  assign coeffs[5] = 8'b0001_0100;
  assign coeffs[6] = 8'b1111_0010;
  assign coeffs[7] = 8'b1111_1001;

  reg signed [NB_IN  -1 : 0] buffer_in  [PARALLELISM -1 : 0];
  wire signed [NB_OUT -1 : 0] buffer_out [PARALLELISM -1 : 0];
  reg [NB_CNT-1 : 0] counter;
  reg [NB_CNT-1 : 0] counter_d;
  reg gen_clock;

  // Deserializador de entrada / contador de indexacion (dominio i_clock)
  always @(posedge i_clock) 
  begin
    if (i_reset)
    begin
      counter   <= {NB_CNT{1'b0}};
      counter_d <= {NB_CNT{1'b0}};
    end
    else
    begin 
      buffer_in[PARALLELISM -1 - counter] <= i_data;
      counter   <= counter + 1'b1;
      counter_d <= counter;
    end
  end

  // Divisor de reloj /PARALLELISM (50% duty). Sube en el flanco donde counter==0
  // (bloque completo en buffer_in) y baja con counter==PARALLELISM/2.
  // Asignacion BLOQUEANTE (igual que la catedra).
  always @(posedge i_clock) 
  begin
    if (i_reset)
      gen_clock = 1'b0;
    else
      gen_clock = ~counter[NB_CNT-1];
  end
  
  // Nucleo paralelo: se propagan los parametros (la catedra no lo hacia)
  fir_parallel #(
    .NB_IN(NB_IN),
    .NB_COEFFS(NB_COEFFS),
    .N_COEFFS(N_COEFFS),
    .PARALLELISM(PARALLELISM),
    .NB_OUT(NB_OUT)
  ) u_fir_parallel (
    .i_data(buffer_in),
    .i_coeffs(coeffs),
    .i_clock(gen_clock),
    .o_data(buffer_out)
  );
  
  // Serializador de salida (dominio i_clock)
  assign o_data = buffer_out[counter_d];

endmodule
