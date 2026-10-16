module fir_pipe_reg #(
  NB_IN = 8,
  NB_COEFFS = 8,
  N_COEFFS = 8,
  NB_OUT = NB_IN + NB_COEFFS + $clog2(N_COEFFS)
)
( 
  input signed [NB_IN -1 : 0] i_data,
  input i_clock,
  output signed [NB_OUT-1 : 0] o_data
);
  localparam NB_PROD = NB_IN + NB_COEFFS;
  
  reg signed [NB_IN -1 : 0] shift_reg [N_COEFFS-1 -1 : 0];
  
  reg signed [NB_IN -1 : 0] shift_reg_pipe;
  
  reg signed [NB_OUT -1 : 0] data_sum;
  
  reg signed [NB_OUT -1 : 0] data_sum_pipe;
  
  reg signed [NB_PROD -1 : 0] prod;

  wire signed [NB_COEFFS -1 : 0] coeffs [N_COEFFS -1 : 0];

  reg signed [NB_IN       -1 : 0] data_reg;
  reg signed [NB_OUT      -1 : 0] data_out_reg;
  
  integer i;

  // Coeficientes fijos 
  assign coeffs[0] = 8'b1111_1001;
  assign coeffs[1] = 8'b1111_0010;
  assign coeffs[2] = 8'b0001_0100;
  assign coeffs[3] = 8'b0011_1000;
  assign coeffs[4] = 8'b0011_1000;
  assign coeffs[5] = 8'b0001_0100;
  assign coeffs[6] = 8'b1111_0010;
  assign coeffs[7] = 8'b1111_1001;
  
  always @(posedge i_clock)
  begin

    data_reg     <= i_data;
    data_out_reg <= data_sum;
    
    shift_reg[0] <= data_reg;
    shift_reg[1] <= shift_reg[0];
    shift_reg[2] <= shift_reg[1];
    shift_reg_pipe <= shift_reg[2];
    shift_reg[3] <= shift_reg_pipe;
    shift_reg[4] <= shift_reg[3];
    shift_reg[5] <= shift_reg[4];
    shift_reg[6] <= shift_reg[5];
    
    data_sum_pipe <= data_reg*coeffs[0] + shift_reg[0]*coeffs[1] + shift_reg[1]*coeffs[2] + shift_reg[2]*coeffs[3];
    
    
  end
  
  integer j;
  
  always@(*)
  begin
                                                                                                                                               
    data_sum = data_sum_pipe + shift_reg[3]*coeffs[4] + shift_reg[4]*coeffs[5] + shift_reg[5]*coeffs[6] + shift_reg[6]*coeffs[7];
    
  end
  
  assign o_data = data_out_reg;
  
endmodule