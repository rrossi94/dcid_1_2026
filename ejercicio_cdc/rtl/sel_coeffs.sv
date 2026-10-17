module sel_coeffs #(
    parameter NB = 8
)
(
    input  [NB-1 : 0] i_coeffs_a,
    input  [NB-1 : 0] i_coeffs_b,
    input             i_sel,
    input             i_clock_a,
    input             i_clock_b,
    input             i_reset,
    output [NB-1 : 0] o_coeffs
);

reg [NB-1 : 0] coeffs_a_reg;
reg [NB-1 : 0] coeffs_b_reg;
reg [NB-1 : 0] coeffs_a_dly;
reg [NB-1 : 0] coeffs_b_dly;
reg [NB-1 : 0] coeffs_out_reg;
reg sel_reg;

genvar i;

generate
  for (i = 0; i<NB; i = i+1)
  begin
    random_delay_bits #(
      .NB_IN(1),
      .MIN_DELAY(1),
      .MAX_DELAY(8)
    ) 
    u_delay_a (
      .i_data(coeffs_a_reg[i]),
      .o_data(coeffs_a_dly[i])
    );

    random_delay_bits #(
      .NB_IN(1),
      .MIN_DELAY(1),
      .MAX_DELAY(8)
    ) 
    u_delay_b (
      .i_data(coeffs_b_reg[i]),
      .o_data(coeffs_b_dly[i])
    );

  end
endgenerate


always @(posedge i_clock_a)
begin
    if(i_reset)
    begin
        coeffs_a_reg <= {NB {1'b0}};
        coeffs_b_reg <= {NB {1'b0}};
        sel_reg <= 1'b0;
    end
    else
    begin
        coeffs_a_reg <= i_coeffs_a;
        coeffs_b_reg <= i_coeffs_b;
        sel_reg <= i_sel;
    end
end

always @(posedge i_clock_b)
begin
    if(sel_reg == 1'b0)
    begin
        coeffs_out_reg <= coeffs_a_dly;
    end
    else
    begin
        coeffs_out_reg <= coeffs_b_dly;
    end
end

assign o_coeffs = coeffs_out_reg;

endmodule