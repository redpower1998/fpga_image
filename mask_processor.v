module mask_processor #(
    parameter DATA_WIDTH = 8,
    parameter OPERATION_WIDTH = 3,
    parameter MASK_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    
    input wire pixel_valid,
    input wire [DATA_WIDTH-1:0] pixel_data,
    input wire [MASK_WIDTH-1:0] mask_value,
    input wire [OPERATION_WIDTH-1:0] operation,
    
    output reg pixel_out_valid,
    output reg [DATA_WIDTH-1:0] pixel_out
);

    localparam OP_AND     = 3'b000;
    localparam OP_OR      = 3'b001;
    localparam OP_XOR     = 3'b010;
    localparam OP_NOT     = 3'b011;
    localparam OP_MASK_APPLY = 3'b100;
    localparam OP_MASK_EXTRACT = 3'b101;
    localparam OP_THRESHOLD = 3'b110;
    localparam OP_BLEND    = 3'b111;
    
    reg pixel_valid_d1;
    reg [DATA_WIDTH-1:0] pixel_data_d1, mask_value_d1;
    reg [OPERATION_WIDTH-1:0] operation_d1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_valid_d1 <= 1'b0;
            pixel_data_d1 <= {DATA_WIDTH{1'b0}};
            mask_value_d1 <= {MASK_WIDTH{1'b0}};
            operation_d1 <= {OPERATION_WIDTH{1'b0}};
        end else begin
            pixel_valid_d1 <= pixel_valid;
            pixel_data_d1 <= pixel_data;
            mask_value_d1 <= mask_value;
            operation_d1 <= operation;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out_valid <= 1'b0;
            pixel_out <= {DATA_WIDTH{1'b0}};
        end else begin
            pixel_out_valid <= pixel_valid_d1;
            
            if (pixel_valid_d1) begin
                case (operation_d1)
                    OP_AND: begin
                        pixel_out <= pixel_data_d1 & mask_value_d1;
                    end
                    OP_OR: begin
                        pixel_out <= pixel_data_d1 | mask_value_d1;
                    end
                    OP_XOR: begin
                        pixel_out <= pixel_data_d1 ^ mask_value_d1;
                    end
                    OP_NOT: begin
                        pixel_out <= ~pixel_data_d1;
                    end
                    OP_MASK_APPLY: begin
                        if (mask_value_d1 != {MASK_WIDTH{1'b0}}) begin
                            pixel_out <= pixel_data_d1;
                        end else begin
                            pixel_out <= {DATA_WIDTH{1'b0}};
                        end
                    end
                    OP_MASK_EXTRACT: begin
                        if (mask_value_d1 != {MASK_WIDTH{1'b0}}) begin
                            pixel_out <= pixel_data_d1;
                        end else begin
                            pixel_out <= 8'd128;
                        end
                    end
                    OP_THRESHOLD: begin
                        if (pixel_data_d1 > mask_value_d1) begin
                            pixel_out <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out <= {DATA_WIDTH{1'b0}};
                        end
                    end
                    OP_BLEND: begin
                        pixel_out <= (pixel_data_d1 + mask_value_d1) >> 1;
                    end
                    default: begin
                        pixel_out <= pixel_data_d1;
                    end
                endcase
            end else begin
                pixel_out <= {DATA_WIDTH{1'b0}};
            end
        end
    end

endmodule