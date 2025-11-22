module sobel (
    input               clk,
    input               rst_n,
    input               gray_valid,
    input [7:0]         gray_data,
    input               hsync,
    input               vsync,
    output reg          sobel_valid,
    output reg [7:0]    sobel_data
);

reg [7:0] curr_row_col0, curr_row_col1, curr_row_col2;
reg [7:0] prev_row_col0, prev_row_col1, prev_row_col2;
reg [7:0] prev2_row_col0, prev2_row_col1, prev2_row_col2;
reg hsync_d1, hsync_d2;
reg line_valid;
reg [8:0] col_cnt;
reg window_valid;
reg pipe1_valid, pipe2_valid;
reg signed [10:0] gx, gy;
reg [10:0] abs_gx_reg, abs_gy_reg;
reg abs_valid;
reg [11:0] sum_abs_reg;
reg sum_valid;
reg [7:0] edge_threshold;
reg [7:0] gauss_data;
reg gauss_valid;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hsync_d1 <= 1'b1;
        hsync_d2 <= 1'b1;
        line_valid <= 1'b0;
    end else begin
        hsync_d1 <= hsync;
        hsync_d2 <= hsync_d1;
        if (hsync_d1 && !hsync_d2) begin
            line_valid <= 1'b0;
        end else if (gray_valid) begin
            line_valid <= 1'b1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        curr_row_col0 <= 8'd0; curr_row_col1 <= 8'd0; curr_row_col2 <= 8'd0;
        prev_row_col0 <= 8'd0; prev_row_col1 <= 8'd0; prev_row_col2 <= 8'd0;
        prev2_row_col0 <= 8'd0; prev2_row_col1 <= 8'd0; prev2_row_col2 <= 8'd0;
        col_cnt <= 9'd0;
    end else if (gray_valid) begin
        if (hsync_d1 && !hsync_d2) begin
            prev2_row_col0 <= prev_row_col0;
            prev2_row_col1 <= prev_row_col1;
            prev2_row_col2 <= prev_row_col2;
            prev_row_col0 <= curr_row_col0;
            prev_row_col1 <= curr_row_col1;
            prev_row_col2 <= curr_row_col2;
            curr_row_col0 <= gray_data;
            curr_row_col1 <= 8'd0;
            curr_row_col2 <= 8'd0;
            col_cnt <= 9'd0;
        end else begin
            curr_row_col0 <= curr_row_col1;
            curr_row_col1 <= curr_row_col2;
            curr_row_col2 <= gray_data;
            col_cnt <= col_cnt + 1'b1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gauss_data <= 8'd0;
        gauss_valid <= 1'b0;
    end else begin
        gauss_valid <= gray_valid;
        if (gray_valid) begin
            gauss_data <= (curr_row_col0 + curr_row_col1 + curr_row_col2 + 
                           prev_row_col0 + prev_row_col1 + prev_row_col2 + 
                           prev2_row_col0 + prev2_row_col1 + prev2_row_col2) / 9;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        window_valid <= 1'b0;
    end else begin
        window_valid <= line_valid && (col_cnt >= 9'd2) && 
                       (curr_row_col0 != 8'd0) && (curr_row_col1 != 8'd0) && (curr_row_col2 != 8'd0) &&
                       (prev_row_col0 != 8'd0) && (prev_row_col1 != 8'd0) && (prev_row_col2 != 8'd0) &&
                       (prev2_row_col0 != 8'd0) && (prev2_row_col1 != 8'd0) && (prev2_row_col2 != 8'd0);
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) pipe1_valid <= 1'b0;
    else pipe1_valid <= window_valid;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gx <= 11'sd0;
        gy <= 11'sd0;
        pipe2_valid <= 1'b0;
    end else begin
        pipe2_valid <= pipe1_valid;
        if (pipe1_valid) begin
            gx <= -$signed(prev2_row_col0) + $signed(prev2_row_col2)
                 - ($signed(prev_row_col0) << 1) + ($signed(prev_row_col2) << 1)
                 - $signed(curr_row_col0) + $signed(curr_row_col2);
            
            gy <= -$signed(prev2_row_col0) - ($signed(prev2_row_col1) << 1) - $signed(prev2_row_col2)
                 + $signed(curr_row_col0) + ($signed(curr_row_col1) << 1) + $signed(curr_row_col2);
        end else begin
            gx <= 11'sd0;
            gy <= 11'sd0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        abs_gx_reg <= 11'd0;
        abs_gy_reg <= 11'd0;
        abs_valid <= 1'b0;
    end else begin
        abs_valid <= pipe2_valid;
        if (pipe2_valid) begin
            abs_gx_reg <= (gx[10]) ? (~gx + 1'b1) : gx;
            abs_gy_reg <= (gy[10]) ? (~gy + 1'b1) : gy;
        end else begin
            abs_gx_reg <= 11'd0;
            abs_gy_reg <= 11'd0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum_abs_reg <= 12'd0;
        sum_valid <= 1'b0;
    end else begin
        sum_valid <= abs_valid;
        if (abs_valid) begin
            sum_abs_reg <= abs_gx_reg + abs_gy_reg;
        end else begin
            sum_abs_reg <= 12'd0;
        end
    end
end

initial edge_threshold = 8'd100;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sobel_data <= 8'd0;
        sobel_valid <= 1'b0;
    end else begin
        sobel_valid <= sum_valid;
        if (sum_valid) begin
            if (sum_abs_reg > 12'd255) begin
                sobel_data <= 8'd255;
            end else if (sum_abs_reg > edge_threshold) begin
                sobel_data <= sum_abs_reg;
            end else begin
                sobel_data <= 8'd0;
            end
        end else begin
            sobel_data <= (col_cnt == 9'd0 || col_cnt == 9'd319 || 
                           (prev2_row_col0 == 8'd0 && prev_row_col0 == 8'd0 && curr_row_col0 == 8'd0)) ? 8'd0 : sobel_data;
        end
    end
end

endmodule