module harris_corner #(
    parameter DATA_WIDTH = 8,
    parameter IMAGE_WIDTH = 320,
    parameter IMAGE_HEIGHT = 464,
    parameter WINDOW_SIZE = 3,
    parameter K_PARAM = 16'h0040,
    parameter THRESHOLD = 32'h00010000
)(
    input wire clk,
    input wire rst_n,
    input wire data_valid,
    input wire [DATA_WIDTH-1:0] pixel_in,
    
    output reg data_out_valid,
    output reg [DATA_WIDTH-1:0] pixel_out,
    output reg corner_detected
);

reg [DATA_WIDTH-1:0] window_buffer [0:WINDOW_SIZE*WINDOW_SIZE-1];
reg [DATA_WIDTH-1:0] line_buffer [0:IMAGE_WIDTH*(WINDOW_SIZE-1)-1];
reg [9:0] pixel_x, pixel_y;
reg window_valid;

reg signed [10:0] gx, gy;
reg signed [21:0] gx2, gy2, gxy;

reg signed [31:0] sum_gx2, sum_gy2, sum_gxy;
reg signed [31:0] det, trace;
reg signed [31:0] harris_response;

reg [2:0] pipeline_stage;

localparam K = K_PARAM;
localparam THRESH = THRESHOLD;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_x <= 0;
        pixel_y <= 0;
        window_valid <= 1'b0;
        pipeline_stage <= 0;
    end else if (data_valid) begin
        if (pixel_x == IMAGE_WIDTH - 1) begin
            pixel_x <= 0;
            pixel_y <= pixel_y + 1;
        end else begin
            pixel_x <= pixel_x + 1;
        end
        
        for (integer i = 0; i < IMAGE_WIDTH*(WINDOW_SIZE-1)-1; i = i+1) begin
            line_buffer[i] <= line_buffer[i+1];
        end
        line_buffer[IMAGE_WIDTH*(WINDOW_SIZE-1)-1] <= pixel_in;
        
        for (integer i = 0; i < WINDOW_SIZE*WINDOW_SIZE-1; i = i+1) begin
            window_buffer[i] <= window_buffer[i+1];
        end
        window_buffer[WINDOW_SIZE*WINDOW_SIZE-1] <= pixel_in;
        
        if (pixel_x >= WINDOW_SIZE-1 && pixel_y >= WINDOW_SIZE-1 && 
            pixel_x < IMAGE_WIDTH - (WINDOW_SIZE-1) && 
            pixel_y < IMAGE_HEIGHT - (WINDOW_SIZE-1)) begin
            window_valid <= 1'b1;
        end else begin
            window_valid <= 1'b0;
        end
        
        pipeline_stage <= pipeline_stage + 1;
    end
end

always @(posedge clk) begin
    if (window_valid) begin
        gx = ({3'b000, window_buffer[2]} + {3'b000, window_buffer[5]}*2 + {3'b000, window_buffer[8]}) -
             ({3'b000, window_buffer[0]} + {3'b000, window_buffer[3]}*2 + {3'b000, window_buffer[6]});
        
        gy = ({3'b000, window_buffer[6]} + {3'b000, window_buffer[7]}*2 + {3'b000, window_buffer[8]}) -
             ({3'b000, window_buffer[0]} + {3'b000, window_buffer[1]}*2 + {3'b000, window_buffer[2]});
        
        gx2 = gx * gx;
        gy2 = gy * gy;
        gxy = gx * gy;
    end
end

always @(posedge clk) begin
    if (pipeline_stage == 1) begin
        sum_gx2 <= gx2;
        sum_gy2 <= gy2;
        sum_gxy <= gxy;
    end else if (pipeline_stage > 1 && pipeline_stage < 5) begin
        sum_gx2 <= sum_gx2 + gx2;
        sum_gy2 <= sum_gy2 + gy2;
        sum_gxy <= sum_gxy + gxy;
    end
end

always @(posedge clk) begin
    if (pipeline_stage == 5) begin
        det = sum_gx2 * sum_gy2 - sum_gxy * sum_gxy;
        
        trace = sum_gx2 + sum_gy2;
        
        harris_response = det - ((K * trace * trace) >> 16);
    end
end

always @(posedge clk) begin
    if (pipeline_stage == 6) begin
        data_out_valid <= window_valid;
        pixel_out <= window_buffer[4];
        
        if (harris_response > $signed(THRESHOLD) && window_valid && harris_response > 0) begin
            corner_detected <= 1'b1;
            pixel_out <= 8'hFF;
        end else begin
            corner_detected <= 1'b0;
            pixel_out <= window_buffer[4];
        end
    end else begin
        data_out_valid <= 1'b0;
        corner_detected <= 1'b0;
    end
end

endmodule