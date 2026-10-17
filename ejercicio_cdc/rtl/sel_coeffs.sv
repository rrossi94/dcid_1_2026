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

    // =========================================================================
    // Dominio i_clock_a (Origen)
    // =========================================================================
    reg [NB-1 : 0] coeffs_a_reg;
    reg [NB-1 : 0] coeffs_b_reg;
    reg            sel_reg;

    reg [NB-1 : 0] coeffs_sel_reg;
    reg            valid_toggle_a;

    // El multiplexor se resuelve en el dominio origen antes del cruce de reloj
    wire [NB-1 : 0] coeffs_mux;
    assign coeffs_mux = (sel_reg == 1'b0) ? coeffs_a_reg : coeffs_b_reg;

    always @(posedge i_clock_a) begin
        if (i_reset) begin
            coeffs_a_reg   <= {NB{1'b0}};
            coeffs_b_reg   <= {NB{1'b0}};
            sel_reg        <= 1'b0;
            coeffs_sel_reg <= {NB{1'b0}};
            valid_toggle_a <= 1'b0;
        end else begin
            coeffs_a_reg <= i_coeffs_a;
            coeffs_b_reg <= i_coeffs_b;
            sel_reg      <= i_sel;

            // Al conmutar el dato seleccionado, se registra y se invierte el toggle de control
            if (coeffs_mux != coeffs_sel_reg) begin
                coeffs_sel_reg <= coeffs_mux;
                valid_toggle_a <= ~valid_toggle_a;
            end
        end
    end

    // =========================================================================
    // Cruce asincronico con inyeccion de dispersion aleatoria (random_delay_bits)
    // =========================================================================
    wire [NB-1 : 0] coeffs_sel_dly;
    wire            valid_toggle_dly;

    genvar i;
    generate
        for (i = 0; i < NB; i = i + 1) begin : gen_data_delay
            random_delay_bits #(
                .NB_IN(1),
                .MIN_DELAY(1),
                .MAX_DELAY(8)
            ) u_delay_data (
                .i_data(coeffs_sel_reg[i]),
                .o_data(coeffs_sel_dly[i])
            );
        end
    endgenerate

    random_delay_bits #(
        .NB_IN(1),
        .MIN_DELAY(1),
        .MAX_DELAY(8)
    ) u_delay_ctrl (
        .i_data(valid_toggle_a),
        .o_data(valid_toggle_dly)
    );

    // =========================================================================
    // Dominio i_clock_b (Destino)
    // =========================================================================
    // Sincronizador de 2 etapas (2FF) + registro para detector de flanco (toggle)
    reg sync_b1;
    reg sync_b2;
    reg sync_b3;
    reg [NB-1 : 0] coeffs_out_reg;

    wire capture_en_b;
    assign capture_en_b = sync_b2 ^ sync_b3; // Genera un pulso de 1 ciclo en clock_b

    always @(posedge i_clock_b) begin
        if (i_reset) begin
            sync_b1        <= 1'b0;
            sync_b2        <= 1'b0;
            sync_b3        <= 1'b0;
            coeffs_out_reg <= {NB{1'b0}};
        end else begin
            sync_b1 <= valid_toggle_dly;
            sync_b2 <= sync_b1;
            sync_b3 <= sync_b2;

            if (capture_en_b) begin
                coeffs_out_reg <= coeffs_sel_dly; // Captura el bus cuando ya esta 100% estable
            end
        end
    end

    assign o_coeffs = coeffs_out_reg;

endmodule