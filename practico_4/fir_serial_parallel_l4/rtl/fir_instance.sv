module fir_instance #(
  NB_IN = 8,
  NB_COEFFS = 8,
  N_COEFFS = 8,
  NB_OUT = NB_IN + NB_COEFFS + $clog2(N_COEFFS)
)
( 
  input [NB_IN*N_COEFFS -1 : 0] i_data,
  input signed [NB_COEFFS -1 : 0] i_coeffs [N_COEFFS],
  output signed [NB_OUT-1 : 0] o_data
);
  
  localparam NB_PROD = NB_IN + NB_COEFFS;

  reg signed [NB_OUT  -1 : 0] data_sum; 
  reg signed [NB_PROD -1 : 0] prod;
  
  reg signed [NB_IN -1 : 0] i_data_array [N_COEFFS -1 : 0];

  
  integer j;

  always@(*)
  begin
    data_sum = {NB_OUT {1'b0}};
    for(j=0; j<N_COEFFS; j=j+1)
    begin: data_accum
      i_data_array[j] = $signed(i_data[(j+1)*NB_IN-1 -: NB_IN]);
      prod = i_data_array[j]*i_coeffs[j];
      data_sum = data_sum + prod;
    end
  end
  
  assign o_data = data_sum;
  
endmodule
