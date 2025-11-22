module emboss #(
    parameter IMAGE_WIDTH = 320,
    parameter IMAGE_HEIGHT = 464,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire pixel_valid,
    input wire [DATA_WIDTH-1:0] pixel_in,
    output reg pixel_out_valid,
    output reg [DATA_WIDTH-1:0] pixel_out
);

    localparam WIDTH_BITS = $clog2(IMAGE_WIDTH);
    localparam HEIGHT_BITS = $clog2(IMAGE_HEIGHT);
    
    reg [DATA_WIDTH-1:0] line_buffer_0 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] line_buffer_1 [0:IMAGE_WIDTH-1];
    
    reg [DATA_WIDTH-1:0] window_00, window_01, window_02;
    reg [DATA_WIDTH-1:0] window_10, window_11, window_12;
    reg [DATA_WIDTH-1:0] window_20, window_21, window_22;
    
    reg [WIDTH_BITS-1:0] col_counter_d1, col_counter_d2;
    reg [HEIGHT_BITS-1:0] row_counter_d1, row_counter_d2;
    
    reg [WIDTH_BITS-1:0] col_counter;
    reg [HEIGHT_BITS-1:0] row_counter;
    
    reg pixel_valid_d1, pixel_valid_d2, pixel_valid_d3;
    
    parameter COEFF_00 = -2;
    parameter COEFF_01 = -1;
    parameter COEFF_02 = 0;
    parameter COEFF_10 = -1;
    parameter COEFF_11 = 1;
    parameter COEFF_12 = 1;
    parameter COEFF_20 = 0;
    parameter COEFF_21 = 1;
    parameter COEFF_22 = 2;
    
    reg signed [DATA_WIDTH+3:0] conv_result;
    reg signed [DATA_WIDTH+3:0] temp_result;
    
    integer i;
    initial begin
        for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
            line_buffer_0[i] = 0;
            line_buffer_1[i] = 0;
        end
        col_counter = 0;
        row_counter = 0;
        pixel_valid_d1 = 0;
        pixel_valid_d2 = 0;
        pixel_valid_d3 = 0;
        pixel_out_valid = 0;
        pixel_out = 0;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_counter <= 0;
            row_counter <= 0;
        end else if (pixel_valid) begin
            if (col_counter == IMAGE_WIDTH - 1) begin
                col_counter <= 0;
                if (row_counter == IMAGE_HEIGHT - 1) begin
                    row_counter <= 0;
                end else begin
                    row_counter <= row_counter + 1;
                end
            end else begin
                col_counter <= col_counter + 1;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_counter_d1 <= 0;
            col_counter_d2 <= 0;
            row_counter_d1 <= 0;
            row_counter_d2 <= 0;
            pixel_valid_d1 <= 0;
            pixel_valid_d2 <= 0;
            pixel_valid_d3 <= 0;
        end else begin
            col_counter_d1 <= col_counter;
            col_counter_d2 <= col_counter_d1;
            row_counter_d1 <= row_counter;
            row_counter_d2 <= row_counter_d1;
            pixel_valid_d1 <= pixel_valid;
            pixel_valid_d2 <= pixel_valid_d1;
            pixel_valid_d3 <= pixel_valid_d2;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                line_buffer_0[i] <= 0;
                line_buffer_1[i] <= 0;
            end
        end else if (pixel_valid) begin
            line_buffer_1[col_counter] <= line_buffer_0[col_counter];
            line_buffer_0[col_counter] <= pixel_in;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            window_00 <= 0; window_01 <= 0; window_02 <= 0;
            window_10 <= 0; window_11 <= 0; window_12 <= 0;
            window_20 <= 0; window_21 <= 0; window_22 <= 0;
        end else if (pixel_valid_d1) begin
            if (col_counter_d1 > 0 && row_counter_d1 > 0) begin
                window_00 <= line_buffer_1[col_counter_d1 - 1];
                window_10 <= line_buffer_0[col_counter_d1 - 1];
                window_20 <= pixel_in;
            end
            
            if (row_counter_d1 > 0) begin
                window_01 <= line_buffer_1[col_counter_d1];
                window_11 <= line_buffer_0[col_counter_d1];
                window_21 <= pixel_in;
            end
            
            if (col_counter_d1 < IMAGE_WIDTH - 1 && row_counter_d1 > 0) begin
                window_02 <= line_buffer_1[col_counter_d1 + 1];
                window_12 <= line_buffer_0[col_counter_d1 + 1];
                window_22 <= pixel_in;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            conv_result <= 0;
            temp_result <= 0;
        end else if (pixel_valid_d2) begin
            temp_result = 
                (COEFF_00 * $signed({1'b0, window_00})) +
                (COEFF_01 * $signed({1'b0, window_01})) +
                (COEFF_02 * $signed({1'b0, window_02})) +
                (COEFF_10 * $signed({1'b0, window_10})) +
                (COEFF_11 * $signed({1'b0, window_11})) +
                (COEFF_12 * $signed({1'b0, window_12})) +
                (COEFF_20 * $signed({1'b0, window_20})) +
                (COEFF_21 * $signed({1'b0, window_21})) +
                (COEFF_22 * $signed({1'b0, window_22}));
            
            conv_result <= temp_result + 128;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out_valid <= 0;
            pixel_out <= 0;
        end else if (pixel_valid_d3) begin
            pixel_out_valid <= 1;
            
            if (col_counter_d2 == 0 || col_counter_d2 == IMAGE_WIDTH - 1 || 
                row_counter_d2 == 0 || row_counter_d2 == IMAGE_HEIGHT - 1) begin
                pixel_out <= window_11;
            end else begin
                if (conv_result < 0) begin
                    pixel_out <= 0;
                end else if (conv_result > 255) begin
                    pixel_out <= 255;
                end else begin
                    pixel_out <= conv_result[DATA_WIDTH-1:0];
                end
            end
        end else begin
            pixel_out_valid <= 0;
        end
    end

endmodule