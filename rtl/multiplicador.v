// Code your design here

module multiplicador #(
  parameter NB_INPUT    = 9,
  parameter NBF_INPUT   = 7,
  parameter NB_OUTPUT   = 19,
  parameter NBF_OUTPUT  = 14
)
(
  input  signed [NB_INPUT  -1 : 0] i_real,
  input  signed [NB_INPUT  -1 : 0] i_imag,
  output signed [NB_OUTPUT -1 : 0] o_real,
  output signed [NB_OUTPUT -1 : 0] o_imag
);
  

  
  scm_mult #(
    .NB_INPUT   (NB_INPUT   ),
    .NBF_INPUT  (NBF_INPUT  ),
    .NB_OUTPUT  (NB_OUTPUT  ),
    .NBF_OUTPUT (NBF_OUTPUT ),
    .NB_TWIDDLE (9 ),
    .NBF_TWIDDLE(7 )
  )
  u_mult(
    .i_real(i_real),
    .i_imag(i_imag),
    .o_real(o_real),
    .o_imag(o_imag)
  );


endmodule

// module mcm_mult #(
//   parameter NB_INPUT    = 9,
//   parameter NBF_INPUT   = 8,
//   parameter NB_OUTPUT   = 19,
//   parameter NBF_OUTPUT  = 15,
//   parameter NB_TWIDDLE  = 9,
//   parameter NBF_TWIDDLE = 7
// )
// (
//   input  signed [NB_INPUT  -1 : 0] i_real,
//   input  signed [NB_INPUT  -1 : 0] i_imag,
//   output signed [NB_OUTPUT -1 : 0] o_real,
//   output signed [NB_OUTPUT -1 : 0] o_imag
// );

//   localparam NB_MULT  = NB_TWIDDLE + NB_INPUT + 1;
//   localparam NBF_MULT = NBF_TWIDDLE + NBF_INPUT;
  
//   localparam signed [8 : 0] twiddle_real = 9'b111010000;
//   localparam signed [8 : 0] twiddle_imag = 9'b110001010;

//   wire signed [NB_MULT -1 : 0] real_mult;
//   wire signed [NB_MULT -1 : 0] imag_mult;
  
//   assign o_real = i_real * twiddle_real - i_imag * twiddle_imag;
//   assign o_imag = i_real * twiddle_imag + i_imag * twiddle_real;

// endmodule

module scm_mult #(
  parameter NB_INPUT    = 9,
  parameter NBF_INPUT   = 8,
  parameter NB_OUTPUT   = 19,
  parameter NBF_OUTPUT  = 15,
  parameter NB_TWIDDLE  = 9,
  parameter NBF_TWIDDLE = 7
)
(
  input  signed [NB_INPUT  -1 : 0] i_real,
  input  signed [NB_INPUT  -1 : 0] i_imag,
  output signed [NB_OUTPUT -1 : 0] o_real,
  output signed [NB_OUTPUT -1 : 0] o_imag
);

  localparam NB_MULT  = NB_TWIDDLE + NB_INPUT + 1;
  localparam NBF_MULT = NBF_TWIDDLE + NBF_INPUT;
  
  localparam signed [8 : 0] twiddle_real = 9'b111010000;
  localparam signed [8 : 0] twiddle_imag = 9'b110001010;
  
  wire signed       [NB_INPUT   : 0] sum_inputs;
  localparam signed [9          : 0] sum_twiddles = twiddle_real + twiddle_imag;
  localparam signed [9          : 0] sub_twiddles = twiddle_real - twiddle_imag;
  wire signed       [NB_MULT -1 : 0] mul_input_real;
  wire signed       [NB_MULT -1 : 0] mul_input_imag;
  wire signed       [NB_MULT -1 : 0] mul_twiddle;
  
  assign sum_inputs   = i_real + i_imag;


  assign mul_input_real = i_real * sum_twiddles;
  assign mul_input_imag = i_imag * sub_twiddles;
  assign mul_twiddle    = twiddle_imag * sum_inputs;


  assign o_real = mul_input_real - mul_twiddle;
  assign o_imag = mul_input_imag + mul_twiddle;

endmodule
