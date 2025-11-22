module harris_corner_fixed #(
    parameter DATA_WIDTH = 8,
    parameter IMAGE_WIDTH = 320,
    parameter IMAGE_HEIGHT = 464,
    parameter WINDOW_SIZE = 3,
    parameter K_PARAM = 32'h00004000,
    parameter THRESHOLD = 32'h00000002
)(
    input wire clk,
    input wire rst_n,
    input wire data_valid,
    input wire [DATA_WIDTH-1:0] pixel_in,
    
    output reg data_out_valid,
    output reg [DATA_WIDTH-1:0] pixel_out,
    output reg corner_detected
);

reg [DATA_WIDTH-1:0] window_buffer [0:8];
reg [DATA_WIDTH-1:0] line_buffer_0 [0:IMAGE_WIDTH-1];
reg [DATA_WIDTH-1:0] line_buffer_1 [0:IMAGE_WIDTH-1];
reg [9:0] pixel_x, pixel_y;
reg window_valid;

reg signed [10:0] gx, gy;
reg signed [21:0] gx2, gy2, gxy;

reg signed [31:0] sum_gx2, sum_gy2, sum_gxy;
reg signed [63:0] det, trace_squared;
reg signed [31:0] harris_response;

reg [2:0] pipeline_stage;

reg data_out_valid_next;
reg corner_detected_next;
reg [7:0] pixel_out_next;

localparam K = K_PARAM;
localparam THRESH = THRESHOLD;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_x <= 0;
        pixel_y <= 0;
        window_valid <= 1'b0;
        pipeline_stage <= 0;
        for (integer i = 0; i < 9; i = i + 1) begin
            window_buffer[i] <= 0;
        end
        for (integer i = 0; i < IMAGE_WIDTH; i = i + 1) begin
            line_buffer_0[i] <= 0;
            line_buffer_1[i] <= 0;
        end
    end else if (data_valid) begin
        if (pixel_x == IMAGE_WIDTH - 1) begin
            pixel_x <= 0;
            pixel_y <= pixel_y + 1;
        end else begin
            pixel_x <= pixel_x + 1;
        end
        
        line_buffer_0[pixel_x] <= pixel_in;
        
        if (pixel_x == IMAGE_WIDTH - 1) begin
            for (integer i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                line_buffer_1[i] <= line_buffer_0[i];
            end
        end
        
        window_buffer[0] <= (pixel_x > 0 && pixel_y > 0) ? line_buffer_1[pixel_x - 1] : 0;
        window_buffer[1] <= (pixel_y > 0) ? line_buffer_1[pixel_x] : 0;
        window_buffer[2] <= (pixel_x < IMAGE_WIDTH - 1 && pixel_y > 0) ? line_buffer_1[pixel_x + 1] : 0;
        window_buffer[3] <= (pixel_x > 0 && pixel_y >= 0) ? line_buffer_0[pixel_x - 1] : 0;
        window_buffer[4] <= line_buffer_0[pixel_x];
        window_buffer[5] <= (pixel_x < IMAGE_WIDTH - 1 && pixel_y >= 0) ? line_buffer_0[pixel_x + 1] : 0;
        window_buffer[6] <= (pixel_x > 0) ? line_buffer_0[pixel_x - 1] : 0;
        window_buffer[7] <= pixel_in;
        window_buffer[8] <= (pixel_x < IMAGE_WIDTH - 1) ? line_buffer_0[pixel_x + 1] : 0;
        
        if (pixel_x >= 1 && pixel_y >= 1 && 
            pixel_x < IMAGE_WIDTH - 1 && 
            pixel_y < 2) begin
            window_valid <= 1'b1;
        end else begin
            window_valid <= 1'b0;
        end
        
        if (window_valid) begin
            pipeline_stage <= (pipeline_stage == 6) ? 0 : pipeline_stage + 1;
        end else begin
            pipeline_stage <= 0;
        end
        
        if (pixel_x == 1 && pixel_y == 1) begin
            $display("窗口开始有效: 位置(%0d,%0d)", pixel_x, pixel_y);
        end
    end else begin
        pipeline_stage <= 0;
        window_valid <= 1'b0;
    end
end

always @(posedge clk) begin
    if (pipeline_stage == 1 && window_valid) begin
        gx = ($signed({3'b000, window_buffer[2]}) - $signed({3'b000, window_buffer[0]})) + 
             (($signed({3'b000, window_buffer[5]}) - $signed({3'b000, window_buffer[3]})) << 1) +
             ($signed({3'b000, window_buffer[8]}) - $signed({3'b000, window_buffer[6]}));
        
        gy = ($signed({3'b000, window_buffer[6]}) - $signed({3'b000, window_buffer[0]})) + 
             (($signed({3'b000, window_buffer[7]}) - $signed({3'b000, window_buffer[1]})) << 1) +
             ($signed({3'b000, window_buffer[8]}) - $signed({3'b000, window_buffer[2]}));
        
        gx2 = gx * gx;
        gy2 = gy * gy;
        gxy = gx * gy;
        
        if (pixel_x == 160 && pixel_y == 232) begin
            $display("梯度计算: gx=%0d, gy=%0d, gx2=%0d, gy2=%0d, gxy=%0d", 
                     gx, gy, gx2, gy2, gxy);
        end
    end
end

always @(posedge clk) begin
    if (pipeline_stage == 2 && window_valid) begin
        sum_gx2 <= gx2;
        sum_gy2 <= gy2;
        sum_gxy <= gxy;
        
        if (pixel_x == 160 && pixel_y == 232) begin
            $display("矩阵元素: sum_gx2=%0d, sum_gy2=%0d, sum_gxy=%0d", 
                     sum_gx2, sum_gy2, sum_gxy);
        end
    end
end

always @(posedge clk) begin
    if (pipeline_stage == 3 && window_valid) begin
        det = $signed(sum_gx2) * $signed(sum_gy2) - $signed(sum_gxy) * $signed(sum_gxy);
        
        trace_squared = ($signed(sum_gx2) + $signed(sum_gy2)) * ($signed(sum_gx2) + $signed(sum_gy2));
        
        harris_response = det - (($signed(K) * trace_squared) >> 16);
        
        if (pixel_x < 30 && pixel_y < 30) begin
            $display("Harris计算[%0d,%0d]: det=%0d, trace_squared=%0d, response=%0d, K=%0d, 阈值=%0d", 
                     pixel_x, pixel_y, det, trace_squared, harris_response, K, THRESH);
        end
        
        if ((pixel_x >= 1 && pixel_x <= 3 && pixel_y >= 1 && pixel_y <= 3) || 
            (pixel_x >= 6 && pixel_x <= 8 && pixel_y >= 6 && pixel_y <= 8)) begin
            $display("高对比度区域[%0d,%0d]: 响应值=%0d, 窗口数据=%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d", 
                     pixel_x, pixel_y, harris_response,
                     window_buffer[0], window_buffer[1], window_buffer[2],
                     window_buffer[3], window_buffer[4], window_buffer[5],
                     window_buffer[6], window_buffer[7], window_buffer[8]);
        end
    end else begin
        harris_response <= 0;
    end
end

always @(posedge clk) begin
    data_out_valid_next = 1'b0;
    corner_detected_next = 1'b0;
    pixel_out_next = 8'd0;
    
    if (pipeline_stage == 4 && window_valid) begin
        data_out_valid_next = 1'b1;
        
        if (pixel_x < 10 && pixel_y < 3) begin
            $display("输出阶段: stage=%0d, valid=%0d, pos=(%0d,%0d), response=%0d", 
                     pipeline_stage, window_valid, pixel_x, pixel_y, harris_response);
        end
        
        if ($signed(harris_response) > THRESH && $signed(harris_response) > 0) begin
            corner_detected_next = 1'b1;
            pixel_out_next = 8'hFF;
            
            $display("*** 角点检测到: 位置(%0d,%0d), 响应值=%0d ***", 
                     pixel_x, pixel_y, harris_response);
        end else begin
            corner_detected_next = 1'b0;
            pixel_out_next = window_buffer[4];
        end
    end
    
    data_out_valid <= data_out_valid_next;
    corner_detected <= corner_detected_next;
    pixel_out <= pixel_out_next;
end

endmodule