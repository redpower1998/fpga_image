module homography_enhanced #(
    parameter DATA_WIDTH = 8,
    parameter COORD_WIDTH = 16,
    parameter FRAC_WIDTH = 16,
    parameter PIPELINE_STAGES = 7,
    parameter INTERPOLATION_TYPE = 0
) (
    input wire clk,
    input wire rst_n,
    
    input wire coord_valid,
    input wire [COORD_WIDTH-1:0] dst_x,
    input wire [COORD_WIDTH-1:0] dst_y,
    
    input wire signed [31:0] h11, h12, h13,
    input wire signed [31:0] h21, h22, h23,
    input wire signed [31:0] h31, h32, h33,
    
    input wire [COORD_WIDTH-1:0] src_width,
    input wire [COORD_WIDTH-1:0] src_height,
    
    output reg coord_out_valid,
    output reg [COORD_WIDTH-1:0] src_x,
    output reg [COORD_WIDTH-1:0] src_y,
    output reg [FRAC_WIDTH-1:0] src_x_frac,
    output reg [FRAC_WIDTH-1:0] src_y_frac,
    output reg [1:0] interpolation_weights
);

    reg [COORD_WIDTH-1:0] dst_x_pipe [0:PIPELINE_STAGES-1];
    reg [COORD_WIDTH-1:0] dst_y_pipe [0:PIPELINE_STAGES-1];
    reg valid_pipe [0:PIPELINE_STAGES-1];
    
    reg signed [31:0] x_prime, y_prime, w_prime;
    reg signed [31:0] x_prime_pipe, y_prime_pipe, w_prime_pipe;
    
    reg signed [63:0] div_x_numerator, div_y_numerator;
    reg signed [31:0] div_denominator;
    
    reg [COORD_WIDTH-1:0] src_x_int, src_y_int;
    reg [FRAC_WIDTH-1:0] x_frac, y_frac;
    
    reg signed [63:0] temp_x, temp_y;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_prime <= 32'd0;
            y_prime <= 32'd0;
            w_prime <= 32'd0;
            dst_x_pipe[0] <= {COORD_WIDTH{1'b0}};
            dst_y_pipe[0] <= {COORD_WIDTH{1'b0}};
            valid_pipe[0] <= 1'b0;
        end else if (coord_valid) begin
            x_prime <= ($signed(h11) * $signed(dst_x)) + ($signed(h12) * $signed(dst_y)) + $signed(h13);
            y_prime <= ($signed(h21) * $signed(dst_x)) + ($signed(h22) * $signed(dst_y)) + $signed(h23);
            w_prime <= ($signed(h31) * $signed(dst_x)) + ($signed(h32) * $signed(dst_y)) + $signed(h33);
            
            dst_x_pipe[0] <= dst_x;
            dst_y_pipe[0] <= dst_y;
            valid_pipe[0] <= 1'b1;
        end else begin
            valid_pipe[0] <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_prime_pipe <= 32'd0;
            y_prime_pipe <= 32'd0;
            w_prime_pipe <= 32'd0;
            dst_x_pipe[1] <= {COORD_WIDTH{1'b0}};
            dst_y_pipe[1] <= {COORD_WIDTH{1'b0}};
            valid_pipe[1] <= 1'b0;
        end else if (valid_pipe[0]) begin
            x_prime_pipe <= x_prime;
            y_prime_pipe <= y_prime;
            w_prime_pipe <= w_prime;
            dst_x_pipe[1] <= dst_x_pipe[0];
            dst_y_pipe[1] <= dst_y_pipe[0];
            valid_pipe[1] <= 1'b1;
        end else begin
            valid_pipe[1] <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_x_numerator <= 64'd0;
            div_y_numerator <= 64'd0;
            div_denominator <= 32'd0;
            dst_x_pipe[2] <= {COORD_WIDTH{1'b0}};
            dst_y_pipe[2] <= {COORD_WIDTH{1'b0}};
            valid_pipe[2] <= 1'b0;
        end else if (valid_pipe[1]) begin
            div_x_numerator <= $signed(x_prime_pipe) << FRAC_WIDTH;
            div_y_numerator <= $signed(y_prime_pipe) << FRAC_WIDTH;
            div_denominator <= w_prime_pipe;
            
            dst_x_pipe[2] <= dst_x_pipe[1];
            dst_y_pipe[2] <= dst_y_pipe[1];
            valid_pipe[2] <= 1'b1;
        end else begin
            valid_pipe[2] <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_x_int <= {COORD_WIDTH{1'b0}};
            src_y_int <= {COORD_WIDTH{1'b0}};
            x_frac <= {FRAC_WIDTH{1'b0}};
            y_frac <= {FRAC_WIDTH{1'b0}};
            dst_x_pipe[3] <= {COORD_WIDTH{1'b0}};
            dst_y_pipe[3] <= {COORD_WIDTH{1'b0}};
            valid_pipe[3] <= 1'b0;
        end else if (valid_pipe[2]) begin
            if (div_denominator != 32'd0) begin
                temp_x = div_x_numerator / div_denominator;
                temp_y = div_y_numerator / div_denominator;
                
                src_x_int <= temp_x[31:16];
                src_y_int <= temp_y[31:16];
                
                x_frac <= temp_x[15:0];
                y_frac <= temp_y[15:0];
            end else begin
                src_x_int <= {COORD_WIDTH{1'b0}};
                src_y_int <= {COORD_WIDTH{1'b0}};
                x_frac <= {FRAC_WIDTH{1'b0}};
                y_frac <= {FRAC_WIDTH{1'b0}};
            end
            
            dst_x_pipe[3] <= dst_x_pipe[2];
            dst_y_pipe[3] <= dst_y_pipe[2];
            valid_pipe[3] <= 1'b1;
        end else begin
            valid_pipe[3] <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dst_x_pipe[4] <= {COORD_WIDTH{1'b0}};
            dst_y_pipe[4] <= {COORD_WIDTH{1'b0}};
            valid_pipe[4] <= 1'b0;
        end else if (valid_pipe[3]) begin
            if (src_x_int < src_width && src_y_int < src_height) begin
                dst_x_pipe[4] <= dst_x_pipe[3];
                dst_y_pipe[4] <= dst_y_pipe[3];
                valid_pipe[4] <= 1'b1;
            end else begin
                valid_pipe[4] <= 1'b0;
            end
        end else begin
            valid_pipe[4] <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dst_x_pipe[5] <= {COORD_WIDTH{1'b0}};
            dst_y_pipe[5] <= {COORD_WIDTH{1'b0}};
            valid_pipe[5] <= 1'b0;
            interpolation_weights <= 2'b00;
        end else if (valid_pipe[4]) begin
            if (INTERPOLATION_TYPE == 1) begin
                interpolation_weights <= {x_frac[FRAC_WIDTH-1], y_frac[FRAC_WIDTH-1]};
            end else begin
                interpolation_weights <= 2'b00;
            end
            
            dst_x_pipe[5] <= dst_x_pipe[4];
            dst_y_pipe[5] <= dst_y_pipe[4];
            valid_pipe[5] <= 1'b1;
        end else begin
            valid_pipe[5] <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coord_out_valid <= 1'b0;
            src_x <= {COORD_WIDTH{1'b0}};
            src_y <= {COORD_WIDTH{1'b0}};
            src_x_frac <= {FRAC_WIDTH{1'b0}};
            src_y_frac <= {FRAC_WIDTH{1'b0}};
        end else if (valid_pipe[5]) begin
            coord_out_valid <= 1'b1;
            src_x <= src_x_int;
            src_y <= src_y_int;
            src_x_frac <= x_frac;
            src_y_frac <= y_frac;
        end else begin
            coord_out_valid <= 1'b0;
        end
    end

endmodule