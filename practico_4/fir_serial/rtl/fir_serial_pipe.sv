module fir_serial #(
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

  localparam NB_PROD  = NB_IN + NB_COEFFS;
  
  reg signed [NB_IN -1 : 0] shift_reg [N_COEFFS-1 -1 : 0];
  
  reg signed [NB_OUT -1 : 0] data_sum;
  
  reg signed [NB_PROD -1 : 0] prod [N_COEFFS-1 : 0];

  wire signed [NB_COEFFS -1 : 0] coeffs [N_COEFFS -1 : 0];

  reg signed [NB_IN -1 : 0] data_in_reg;
  reg signed [NB_OUT -1 : 0] data_out_reg;
  
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

    data_in_reg <= i_data;
    
    shift_reg[0] <= data_in_reg;
        
    for(i=1; i<N_COEFFS-1; i=i+1)
    begin: shift_reg_for
      shift_reg[i] <= shift_reg[i-1];
    end
    // Cutset horizontal : registros de pipeline ( D_pipe )
    prod [0] <= data_in_reg * coeffs [0];
    for ( i =1; i < N_COEFFS ; i = i +1) begin : mult_pipe_for
      prod [ i ] <= shift_reg [i -1] * coeffs [ i ];
    end
    data_out_reg <= data_sum;
    
  end
  
  integer j;
  
  always@(*)
  begin
    data_sum = prod[0];

    for(j=1; j<N_COEFFS; j=j+1)
    begin: data_accum
      data_sum = data_sum + prod[j];
    end
  end
  
  assign o_data = data_out_reg;
  
endmodule
