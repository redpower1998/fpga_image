module brightness_contrast #(
    parameter DATA_WIDTH = 8,
    parameter COEFF_WIDTH = 16
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     data_valid,
    input  wire [DATA_WIDTH-1:0]    pixel_in,
    input  wire [COEFF_WIDTH-1:0]   alpha,
    input  wire [COEFF_WIDTH-1:0]   beta,
    output reg                      data_out_valid,
    output reg  [DATA_WIDTH-1:0]    pixel_out
);

reg [DATA_WIDTH-1:0] pixel_in_reg;
reg data_valid_reg_1;
reg data_valid_reg_2;

reg [COEFF_WIDTH+DATA_WIDTH-1:0] mult_result;
reg [COEFF_WIDTH+DATA_WIDTH-1:0] add_result;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_in_reg <= {DATA_WIDTH{1'b0}};
        data_valid_reg_1 <= 1'b0;
        data_valid_reg_2 <= 1'b0;
        data_out_valid <= 1'b0;
        pixel_out <= {DATA_WIDTH{1'b0}};
        mult_result <= {(COEFF_WIDTH+DATA_WIDTH){1'b0}};
        add_result <= {(COEFF_WIDTH+DATA_WIDTH){1'b0}};
    end else begin
        pixel_in_reg <= pixel_in;
        data_valid_reg_1 <= data_valid;
        
        data_valid_reg_2 <= data_valid_reg_1;
        if (data_valid_reg_1) begin
            mult_result <= alpha * {8'b0, pixel_in_reg};
        end
        
        if (data_valid_reg_2) begin
            add_result <= mult_result + (beta << 8);
            
            if (add_result[23:8] > 255) begin
                pixel_out <= 8'd255;
            end else if (add_result[23:8] < 0) begin
                pixel_out <= 8'd0;
            end else begin
                pixel_out <= add_result[15:8];
            end
        end else begin
            pixel_out <= pixel_out;
        end
        
        data_out_valid <= data_valid_reg_2;
    end
end

endmodule