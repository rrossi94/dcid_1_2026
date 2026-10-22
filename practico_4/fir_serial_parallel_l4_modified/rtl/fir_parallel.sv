module fir_parallel #(
  NB_IN = 8,
  NB_COEFFS = 8,
  N_COEFFS = 8,
  PARALLELISM = 2,
  NB_OUT = NB_IN + NB_COEFFS + $clog2(N_COEFFS)
)
( 
  input signed [NB_IN -1 : 0] i_data [PARALLELISM -1 : 0],
  input signed [NB_COEFFS -1 : 0] i_coeffs [N_COEFFS-1 : 0],
  input i_clock,
  output signed [NB_OUT-1 : 0] o_data [PARALLELISM -1 : 0]
);
  
  reg signed [NB_IN -1 : 0] shift_reg [N_COEFFS-1 -1 : 0];
  //wire signed [NB_IN -1 : 0] fir_input [N_COEFFS -1 : 0];
  reg signed [NB_IN -1 : 0] fir_input_full [N_COEFFS-1+PARALLELISM -1 : 0];

  reg signed [NB_IN -1 : 0] data_in_reg [PARALLELISM -1 : 0];

  wire signed [NB_OUT-1 : 0] data_out [PARALLELISM -1 : 0];
  reg signed [NB_OUT-1 : 0] data_out_reg [PARALLELISM -1 : 0];
  
  integer ii, kk;
  
  always @(*)
  begin: fir_input_gen
    for(kk = 0; kk < PARALLELISM; kk = kk+1)
    begin: fir_input_loop_p    
      fir_input_full[kk] = data_in_reg[kk];
    end
    
    for(ii = PARALLELISM; ii < N_COEFFS+PARALLELISM-1; ii = ii+1)
    begin: fir_input_loop
      fir_input_full[ii] = shift_reg[ii-PARALLELISM];
    end
    
  end
     
  integer i, ll, mm;
  
  always @(posedge i_clock)
  begin

    data_in_reg <= i_data;
    
    for(ll = 0; ll < PARALLELISM; ll = ll+1)
    begin: Shift_reg_input
      shift_reg[ll] <= data_in_reg[ll];
    end
    
    for(i=PARALLELISM; i<N_COEFFS-1; i=i+PARALLELISM)
    begin: shift_reg_for
      for(mm = 0; mm < PARALLELISM; mm = mm+1)
      begin: Shift_reg_input
        if(i+mm < N_COEFFS-1)
        begin
          shift_reg[i+mm] <= shift_reg[i-PARALLELISM+mm];
        end
      end
    end

    data_out_reg <= data_out;
    
  end
  
  genvar l,s;
  
  generate
  //begin: fir_insatance
    wire [NB_IN*N_COEFFS -1 : 0] fir_input[PARALLELISM -1 : 0];
    for(l = 0; l < PARALLELISM; l = l+1)
    begin
      
      for(s = 0; s < N_COEFFS; s = s+1)
      begin
        assign fir_input[l][(s+1)*NB_IN -1 -: NB_IN] = fir_input_full[N_COEFFS+PARALLELISM-1 -s-l -1];
      end
      fir_instance u_fir(
        .i_data(fir_input[l]),
        .i_coeffs(i_coeffs),
        .o_data(data_out[l])
      );
      
      assign o_data[l] = data_out_reg[l]; 
    end
  endgenerate
   
   
endmodule