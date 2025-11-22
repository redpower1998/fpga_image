module image_arithmetic #(
    parameter DATA_WIDTH = 8,
    parameter OPERATION_WIDTH = 2,
    parameter SCALE_FACTOR = 8'd10
)(
    input wire clk,
    input wire rst_n,
    
    input wire pixel_valid,
    input wire [DATA_WIDTH-1:0] pixel_a,
    input wire [DATA_WIDTH-1:0] pixel_b,
    input wire [OPERATION_WIDTH-1:0] operation,
    
    output reg pixel_out_valid,
    output reg [DATA_WIDTH-1:0] pixel_out
);

    localparam OP_ADD = 2'b00;
    localparam OP_SUB = 2'b01;
    localparam OP_MUL = 2'b10;
    localparam OP_DIV = 2'b11;
    
    reg [DATA_WIDTH*2-1:0] temp_result;
    reg [DATA_WIDTH-1:0] scaled_a;
    reg [DATA_WIDTH-1:0] scaled_b;
    
    reg pixel_valid_d1;
    reg [DATA_WIDTH-1:0] pixel_a_d1, pixel_b_d1;
    reg [OPERATION_WIDTH-1:0] operation_d1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_valid_d1 <= 1'b0;
            pixel_a_d1 <= {DATA_WIDTH{1'b0}};
            pixel_b_d1 <= {DATA_WIDTH{1'b0}};
            operation_d1 <= {OPERATION_WIDTH{1'b0}};
        end else begin
            pixel_valid_d1 <= pixel_valid;
            pixel_a_d1 <= pixel_a;
            pixel_b_d1 <= pixel_b;
            operation_d1 <= operation;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out_valid <= 1'b0;
            pixel_out <= {DATA_WIDTH{1'b0}};
            temp_result <= {(DATA_WIDTH*2){1'b0}};
            scaled_a <= {DATA_WIDTH{1'b0}};
            scaled_b <= {DATA_WIDTH{1'b0}};
        end else begin
            pixel_out_valid <= pixel_valid_d1;
            
            if (pixel_valid_d1) begin
                case (operation_d1)
                    OP_ADD: begin
                        temp_result = pixel_a_d1 + pixel_b_d1;
                        if (temp_result > {DATA_WIDTH{1'b1}}) begin
                            pixel_out <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out <= temp_result[DATA_WIDTH-1:0];
                        end
                    end
                    
                    OP_SUB: begin
                        if (pixel_a_d1 >= pixel_b_d1) begin
                            pixel_out <= pixel_a_d1 - pixel_b_d1;
                        end else begin
                            pixel_out <= {DATA_WIDTH{1'b0}};
                        end
                    end
                    
                    OP_MUL: begin
                        temp_result = pixel_a_d1 * pixel_b_d1;
                        if (SCALE_FACTOR > 0) begin
                            pixel_out <= temp_result / SCALE_FACTOR;
                        end else begin
                            pixel_out <= temp_result[DATA_WIDTH-1:0];
                        end
                    end
                    
                    OP_DIV: begin
                        if (pixel_b_d1 > 0) begin
                            scaled_a = pixel_a_d1 * SCALE_FACTOR;
                            if (scaled_a > {DATA_WIDTH{1'b1}}) begin
                                scaled_a = {DATA_WIDTH{1'b1}};
                            end
                            pixel_out <= scaled_a / pixel_b_d1;
                        end else begin
                            pixel_out <= {DATA_WIDTH{1'b1}};
                        end
                    end
                    
                    default: begin
                        pixel_out <= pixel_a_d1;
                    end
                endcase
            end else begin
                pixel_out <= {DATA_WIDTH{1'b0}};
            end
        end
    end

endmodule