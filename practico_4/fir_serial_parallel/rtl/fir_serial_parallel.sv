module fir_serial_parallel #(
  NB_IN = 8,
  NB_COEFFS = 8,
  N_COEFFS = 8,
  PARALLELISM = 2,
  NB_OUT = NB_IN + NB_COEFFS + $clog2(N_COEFFS)
)
( 
  input signed [NB_IN -1 : 0] i_data,
  //input signed [NB_COEFFS -1 : 0] i_coeffs [N_COEFFS-1 : 0],
  input i_reset,
  input i_clock,
  output signed [NB_OUT-1 : 0] o_data
);

  wire signed [NB_COEFFS -1 : 0] coeffs [N_COEFFS -1 : 0];

  // Coeficientes fijos 
  assign coeffs[0] = 8'b1111_1001;
  assign coeffs[1] = 8'b1111_0010;
  assign coeffs[2] = 8'b0001_0100;
  assign coeffs[3] = 8'b0011_1000;
  assign coeffs[4] = 8'b0011_1000;
  assign coeffs[5] = 8'b0001_0100;
  assign coeffs[6] = 8'b1111_0010;
  assign coeffs[7] = 8'b1111_1001;

  //Clock divider
  reg gen_clock;
  always @(posedge i_clock) 
  begin
    if (i_reset)
        gen_clock = 0;
    else
        gen_clock = ~gen_clock;  // invierte el estado cada flanco de subida
  end

  reg signed [NB_IN  -1 : 0] buffer_in  [PARALLELISM -1 : 0];
  wire signed [NB_OUT -1 : 0] buffer_out [PARALLELISM -1 : 0];
  reg counter;
  reg counter_d;
  
  always @(posedge i_clock) 
  begin
	if (i_reset)
    begin
      counter <= 1'b0;
    end
    else
    begin 
      buffer_in[PARALLELISM -1 - counter] <= i_data;
      counter <= counter + 1'b1;
      counter_d <= counter;
    end
  end
  
  fir_parallel u_fir_parallel(
    .i_data(buffer_in),
    .i_coeffs(coeffs),
    .i_clock(gen_clock),
    .o_data(buffer_out)
  );
  
  assign o_data = buffer_out[counter_d];
      
  
  
endmodule