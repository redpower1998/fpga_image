module white_balance #(
    parameter DATA_WIDTH = 8,
    parameter GAIN_WIDTH = 16,
    parameter METHOD_WIDTH = 2
)(
    input wire clk,
    input wire rst_n,
    
    input wire pixel_valid,
    input wire [DATA_WIDTH-1:0] pixel_r,
    input wire [DATA_WIDTH-1:0] pixel_g,
    input wire [DATA_WIDTH-1:0] pixel_b,
    
    input wire [GAIN_WIDTH-1:0] gain_r,
    input wire [GAIN_WIDTH-1:0] gain_g,
    input wire [GAIN_WIDTH-1:0] gain_b,
    input wire [METHOD_WIDTH-1:0] method,
    
    output reg pixel_out_valid,
    output reg [DATA_WIDTH-1:0] pixel_out_r,
    output reg [DATA_WIDTH-1:0] pixel_out_g,
    output reg [DATA_WIDTH-1:0] pixel_out_b
);

    localparam METHOD_MANUAL     = 2'b00;
    localparam METHOD_GRAY_WORLD = 2'b01;
    localparam METHOD_PERFECT_REFLECTOR = 2'b10;
    localparam METHOD_AUTO       = 2'b11;
    
    reg pixel_valid_d1, pixel_valid_d2;
    reg [DATA_WIDTH-1:0] pixel_r_d1, pixel_g_d1, pixel_b_d1;
    reg [DATA_WIDTH-1:0] pixel_r_d2, pixel_g_d2, pixel_b_d2;
    reg [GAIN_WIDTH-1:0] gain_r_d1, gain_g_d1, gain_b_d1;
    reg [METHOD_WIDTH-1:0] method_d1, method_d2;
    
    reg [GAIN_WIDTH+DATA_WIDTH-1:0] mult_r, mult_g, mult_b;
    reg [DATA_WIDTH-1:0] max_rgb, min_rgb, avg_rgb;
    
    reg [DATA_WIDTH-1:0] auto_r, auto_g, auto_b;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_valid_d1 <= 1'b0;
            pixel_r_d1 <= {DATA_WIDTH{1'b0}};
            pixel_g_d1 <= {DATA_WIDTH{1'b0}};
            pixel_b_d1 <= {DATA_WIDTH{1'b0}};
            gain_r_d1 <= {GAIN_WIDTH{1'b0}};
            gain_g_d1 <= {GAIN_WIDTH{1'b0}};
            gain_b_d1 <= {GAIN_WIDTH{1'b0}};
            method_d1 <= {METHOD_WIDTH{1'b0}};
        end else begin
            pixel_valid_d1 <= pixel_valid;
            pixel_r_d1 <= pixel_r;
            pixel_g_d1 <= pixel_g;
            pixel_b_d1 <= pixel_b;
            gain_r_d1 <= gain_r;
            gain_g_d1 <= gain_g;
            gain_b_d1 <= gain_b;
            method_d1 <= method;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_valid_d2 <= 1'b0;
            pixel_r_d2 <= {DATA_WIDTH{1'b0}};
            pixel_g_d2 <= {DATA_WIDTH{1'b0}};
            pixel_b_d2 <= {DATA_WIDTH{1'b0}};
            method_d2 <= {METHOD_WIDTH{1'b0}};
            
            mult_r <= {(GAIN_WIDTH+DATA_WIDTH){1'b0}};
            mult_g <= {(GAIN_WIDTH+DATA_WIDTH){1'b0}};
            mult_b <= {(GAIN_WIDTH+DATA_WIDTH){1'b0}};
            
            max_rgb <= {DATA_WIDTH{1'b0}};
            min_rgb <= {DATA_WIDTH{1'b0}};
            avg_rgb <= {DATA_WIDTH{1'b0}};
        end else if (pixel_valid_d1) begin
            pixel_valid_d2 <= pixel_valid_d1;
            pixel_r_d2 <= pixel_r_d1;
            pixel_g_d2 <= pixel_g_d1;
            pixel_b_d2 <= pixel_b_d1;
            method_d2 <= method_d1;
            
            mult_r <= pixel_r_d1 * gain_r_d1;
            mult_g <= pixel_g_d1 * gain_g_d1;
            mult_b <= pixel_b_d1 * gain_b_d1;
            
            if (pixel_r_d1 >= pixel_g_d1 && pixel_r_d1 >= pixel_b_d1) begin
                max_rgb <= pixel_r_d1;
            end else if (pixel_g_d1 >= pixel_b_d1) begin
                max_rgb <= pixel_g_d1;
            end else begin
                max_rgb <= pixel_b_d1;
            end
            
            if (pixel_r_d1 <= pixel_g_d1 && pixel_r_d1 <= pixel_b_d1) begin
                min_rgb <= pixel_r_d1;
            end else if (pixel_g_d1 <= pixel_b_d1) begin
                min_rgb <= pixel_g_d1;
            end else begin
                min_rgb <= pixel_b_d1;
            end
            
            avg_rgb <= (pixel_r_d1 + pixel_g_d1 + pixel_b_d1) / 3;
        end else begin
            pixel_valid_d2 <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out_valid <= 1'b0;
            pixel_out_r <= {DATA_WIDTH{1'b0}};
            pixel_out_g <= {DATA_WIDTH{1'b0}};
            pixel_out_b <= {DATA_WIDTH{1'b0}};
            auto_r <= {DATA_WIDTH{1'b0}};
            auto_g <= {DATA_WIDTH{1'b0}};
            auto_b <= {DATA_WIDTH{1'b0}};
        end else begin
            pixel_out_valid <= pixel_valid_d2;
            
            if (pixel_valid_d2) begin
                case (method_d2)
                    METHOD_MANUAL: begin
                        if ((mult_r >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_r <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_r <= mult_r[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                        
                        if ((mult_g >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_g <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_g <= mult_g[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                        
                        if ((mult_b >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_b <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_b <= mult_b[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                    end
                    
                    METHOD_GRAY_WORLD: begin
                        if ((mult_r >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_r <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_r <= mult_r[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                        
                        if ((mult_g >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_g <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_g <= mult_g[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                        
                        if ((mult_b >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_b <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_b <= mult_b[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                    end
                    
                    METHOD_PERFECT_REFLECTOR: begin
                        if ((mult_r >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_r <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_r <= mult_r[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                        
                        if ((mult_g >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_g <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_g <= mult_g[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                        
                        if ((mult_b >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_b <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_b <= mult_b[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                    end
                    
                    METHOD_AUTO: begin
                        if ((mult_r >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_r <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_r <= mult_r[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                        
                        if ((mult_g >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_g <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_g <= mult_g[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                        
                        if ((mult_b >> 8) > {DATA_WIDTH{1'b1}}) begin
                            pixel_out_b <= {DATA_WIDTH{1'b1}};
                        end else begin
                            pixel_out_b <= mult_b[GAIN_WIDTH-1:GAIN_WIDTH-DATA_WIDTH];
                        end
                    end
                    
                    METHOD_AUTO: begin
                        if (avg_rgb != 0) begin
                            auto_r = (pixel_r_d2 * avg_rgb) / (avg_rgb > 0 ? avg_rgb : 1);
                            auto_b = (pixel_b_d2 * avg_rgb) / (avg_rgb > 0 ? avg_rgb : 1);
                        end else begin
                            auto_r = pixel_r_d2;
                            auto_b = pixel_b_d2;
                        end
                        
                        if (max_rgb != 0) begin
                            auto_r = (auto_r + (pixel_r_d2 * {DATA_WIDTH{1'b1}}) / max_rgb) >> 1;
                            auto_b = (auto_b + (pixel_b_d2 * {DATA_WIDTH{1'b1}}) / max_rgb) >> 1;
                        end
                        
                        pixel_out_r <= auto_r;
                        pixel_out_g <= pixel_g_d2;
                        pixel_out_b <= auto_b;
                    end
                    
                    default: begin
                        pixel_out_r <= pixel_r_d2;
                        pixel_out_g <= pixel_g_d2;
                        pixel_out_b <= pixel_b_d2;
                    end
                endcase
            end else begin
                pixel_out_r <= {DATA_WIDTH{1'b0}};
                pixel_out_g <= {DATA_WIDTH{1'b0}};
                pixel_out_b <= {DATA_WIDTH{1'b0}};
            end
        end
    end

endmodule