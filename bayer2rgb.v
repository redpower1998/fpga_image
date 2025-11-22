module bayer2rgb (
    input wire clk,
    input wire rst_n,
    input wire data_valid,
    input wire [7:0] bayer_data,
    input wire [1:0] pattern_select,
    output reg data_out_valid,
    output reg [7:0] r_out,
    output reg [7:0] g_out,
    output reg [7:0] b_out
);

parameter IMAGE_WIDTH = 320;
parameter IMAGE_HEIGHT = 466;

reg [9:0] x_cnt, y_cnt;
reg [9:0] x_sync, y_sync;
reg [7:0] line_buffer [2:0][0:IMAGE_WIDTH-1];
reg [1:0] valid_pipeline;

reg [7:0] window [2:0][2:0];

integer i, j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_cnt <= 0;
        y_cnt <= 0;
    end else if (data_valid) begin
        if (x_cnt == IMAGE_WIDTH - 1) begin
            x_cnt <= 0;
            y_cnt <= y_cnt + 1;
        end else begin
            x_cnt <= x_cnt + 1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 3; i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                line_buffer[i][j] <= 0;
            end
        end
    end else if (data_valid) begin
        line_buffer[2][x_cnt] <= bayer_data;
        
        if (x_cnt == IMAGE_WIDTH - 1) begin
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                line_buffer[0][i] <= line_buffer[1][i];
                line_buffer[1][i] <= line_buffer[2][i];
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 3; i = i + 1) begin
            for (j = 0; j < 3; j = j + 1) begin
                window[i][j] <= 0;
            end
        end
    end else if (data_valid) begin
        window[1][1] <= bayer_data;
        
        if (x_cnt > 0) begin
            window[1][0] <= line_buffer[2][x_cnt - 1];
        end else begin
            window[1][0] <= bayer_data;
        end
        
        if (x_cnt < IMAGE_WIDTH - 1) begin
            window[1][2] <= line_buffer[2][x_cnt + 1];
        end else begin
            window[1][2] <= bayer_data;
        end
        
        if (y_cnt > 0) begin
            window[0][1] <= line_buffer[1][x_cnt];
            
            if (x_cnt > 0) begin
                window[0][0] <= line_buffer[1][x_cnt - 1];
            end else begin
                window[0][0] <= line_buffer[1][x_cnt];
            end
            
            if (x_cnt < IMAGE_WIDTH - 1) begin
                window[0][2] <= line_buffer[1][x_cnt + 1];
            end else begin
                window[0][2] <= line_buffer[1][x_cnt];
            end
        end else begin
            window[0][0] <= (x_cnt > 0) ? line_buffer[2][x_cnt - 1] : bayer_data;
            window[0][1] <= bayer_data;
            window[0][2] <= (x_cnt < IMAGE_WIDTH - 1) ? line_buffer[2][x_cnt + 1] : bayer_data;
        end
        
        window[2][1] <= line_buffer[1][x_cnt];
        
        if (x_cnt > 0) begin
            window[2][0] <= line_buffer[1][x_cnt - 1];
        end else begin
            window[2][0] <= line_buffer[1][x_cnt];
        end
        
        if (x_cnt < IMAGE_WIDTH - 1) begin
            window[2][2] <= line_buffer[1][x_cnt + 1];
        end else begin
            window[2][2] <= line_buffer[1][x_cnt];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_sync <= 0;
        y_sync <= 0;
        valid_pipeline <= 0;
    end else begin
        x_sync <= x_cnt;
        y_sync <= y_cnt;
        valid_pipeline <= {valid_pipeline[0], data_valid};
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_out <= 0;
        g_out <= 0;
        b_out <= 0;
        data_out_valid <= 0;
    end else begin
        data_out_valid <= valid_pipeline[1];
        
        if (valid_pipeline[1]) begin
            case (pattern_select)
                2'b00: begin
                    if (y_sync % 2 == 0) begin
                        if (x_sync % 2 == 0) begin
                            r_out <= window[1][1];
                            g_out <= (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) >> 2;
                            b_out <= (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) >> 2;
                        end else begin
                            g_out <= window[1][1];
                            r_out <= (window[1][0] + window[1][2] + 1) >> 1;
                            b_out <= (window[0][1] + window[2][1] + 1) >> 1;
                        end
                    end else begin
                        if (x_sync % 2 == 0) begin
                            g_out <= window[1][1];
                            r_out <= (window[0][1] + window[2][1] + 1) >> 1;
                            b_out <= (window[1][0] + window[1][2] + 1) >> 1;
                        end else begin
                            b_out <= window[1][1];
                            g_out <= (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) >> 2;
                            r_out <= (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) >> 2;
                        end
                    end
                end
                
                2'b01: begin
                    if (y_sync % 2 == 0) begin
                        if (x_sync % 2 == 0) begin
                            b_out <= window[1][1];
                            g_out <= (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) >> 2;
                            r_out <= (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) >> 2;
                        end else begin
                            g_out <= window[1][1];
                            r_out <= (window[0][1] + window[2][1] + 1) >> 1;
                            b_out <= (window[1][0] + window[1][2] + 1) >> 1;
                        end
                    end else begin
                        if (x_sync % 2 == 0) begin
                            g_out <= window[1][1];
                            r_out <= (window[1][0] + window[1][2] + 1) >> 1;
                            b_out <= (window[0][1] + window[2][1] + 1) >> 1;
                        end else begin
                            r_out <= window[1][1];
                            g_out <= (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) >> 2;
                            b_out <= (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) >> 2;
                        end
                    end
                end
                
                2'b10: begin
                    if (y_sync % 2 == 0) begin
                        if (x_sync % 2 == 0) begin
                            g_out <= window[1][1];
                            r_out <= (window[1][0] + window[1][2] + 1) >> 1;
                            b_out <= (window[0][1] + window[2][1] + 1) >> 1;
                        end else begin
                            r_out <= window[1][1];
                            g_out <= (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) >> 2;
                            b_out <= (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) >> 2;
                        end
                    end else begin
                        if (x_sync % 2 == 0) begin
                            b_out <= window[1][1];
                            g_out <= (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) >> 2;
                            r_out <= (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) >> 2;
                        end else begin
                            g_out <= window[1][1];
                            r_out <= (window[0][1] + window[2][1] + 1) >> 1;
                            b_out <= (window[1][0] + window[1][2] + 1) >> 1;
                        end
                    end
                end
                
                2'b11: begin
                    if (y_sync % 2 == 0) begin
                        if (x_sync % 2 == 0) begin
                            g_out <= window[1][1];
                            b_out <= (window[1][0] + window[1][2] + 1) >> 1;
                            r_out <= (window[0][1] + window[2][1] + 1) >> 1;
                        end else begin
                            b_out <= window[1][1];
                            g_out <= (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) >> 2;
                            r_out <= (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) >> 2;
                        end
                    end else begin
                        if (x_sync % 2 == 0) begin
                            r_out <= window[1][1];
                            g_out <= (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) >> 2;
                            b_out <= (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) >> 2;
                        end else begin
                            g_out <= window[1][1];
                            b_out <= (window[0][1] + window[2][1] + 1) >> 1;
                            r_out <= (window[1][0] + window[1][2] + 1) >> 1;
                        end
                    end
                end
            endcase
            
            if (r_out > 255) r_out <= 255;
            if (g_out > 255) g_out <= 255;
            if (b_out > 255) b_out <= 255;
        end else begin
            r_out <= 0;
            g_out <= 0;
            b_out <= 0;
        end
    end
end

endmodule