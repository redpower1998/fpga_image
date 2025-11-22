module homography #(
    parameter DATA_WIDTH = 8,
    parameter COORD_WIDTH = 16,
    parameter FRAC_WIDTH = 16,
    parameter PIPELINE_STAGES = 5
) (
    input wire clk,
    input wire rst_n,
    
    input wire coord_valid,
    input wire [COORD_WIDTH-1:0] dst_x,
    input wire [COORD_WIDTH-1:0] dst_y,
    
    input wire [FRAC_WIDTH-1:0] h11, h12, h13,
    input wire [FRAC_WIDTH-1:0] h21, h22, h23,
    input wire [FRAC_WIDTH-1:0] h31, h32, h33,
    
    input wire [COORD_WIDTH-1:0] src_width,
    input wire [COORD_WIDTH-1:0] src_height,
    
    output reg coord_out_valid,
    output reg [COORD_WIDTH-1:0] src_x,
    output reg [COORD_WIDTH-1:0] src_y
);

    reg [COORD_WIDTH-1:0] dst_x_pipe [0:PIPELINE_STAGES-1];
    reg [COORD_WIDTH-1:0] dst_y_pipe [0:PIPELINE_STAGES-1];
    reg valid_pipe [0:PIPELINE_STAGES-1];
    
    reg signed [31:0] x_prime, y_prime, w_prime;
    reg signed [31:0] x_prime_pipe, y_prime_pipe, w_prime_pipe;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_prime <= 32'd0;
            y_prime <= 32'd0;
            w_prime <= 32'd0;
            dst_x_pipe[0] <= {COORD_WIDTH{1'b0}};
            dst_y_pipe[0] <= {COORD_WIDTH{1'b0}};
            valid_pipe[0] <= 1'b0;
        end else if (coord_valid) begin
            x_prime <= (h11 * dst_x) + (h12 * dst_y) + h13;
            y_prime <= (h21 * dst_x) + (h22 * dst_y) + h23;
            w_prime <= (h31 * dst_x) + (h32 * dst_y) + h33;
            
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
            dst_x_pipe[2] <= {COORD_WIDTH{1'b0}};
            dst_y_pipe[2] <= {COORD_WIDTH{1'b0}};
            valid_pipe[2] <= 1'b0;
        end else if (valid_pipe[1]) begin
            dst_x_pipe[2] <= dst_x_pipe[1];
            dst_y_pipe[2] <= dst_y_pipe[1];
            valid_pipe[2] <= 1'b1;
        end else begin
            valid_pipe[2] <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dst_x_pipe[3] <= {COORD_WIDTH{1'b0}};
            dst_y_pipe[3] <= {COORD_WIDTH{1'b0}};
            valid_pipe[3] <= 1'b0;
        end else if (valid_pipe[2]) begin
            dst_x_pipe[3] <= dst_x_pipe[2];
            dst_y_pipe[3] <= dst_y_pipe[2];
            valid_pipe[3] <= 1'b1;
        end else begin
            valid_pipe[3] <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coord_out_valid <= 1'b0;
            src_x <= {COORD_WIDTH{1'b0}};
            src_y <= {COORD_WIDTH{1'b0}};
        end else if (valid_pipe[3]) begin
            if (w_prime_pipe != 32'd0) begin
                src_x <= x_prime_pipe / w_prime_pipe;
                src_y <= y_prime_pipe / w_prime_pipe;
            end else begin
                src_x <= {COORD_WIDTH{1'b0}};
                src_y <= {COORD_WIDTH{1'b0}};
            end
            
            if (src_x < src_width && src_y < src_height && 
                src_x >= 0 && src_y >= 0) begin
                coord_out_valid <= 1'b1;
            end else begin
                coord_out_valid <= 1'b0;
            end
        end else begin
            coord_out_valid <= 1'b0;
        end
    end

endmodule