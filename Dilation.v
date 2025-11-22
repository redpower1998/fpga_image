module Dilation #(
    parameter IMAGE_WIDTH = 320,
    parameter IMAGE_HEIGHT = 464,
    parameter DATA_WIDTH = 8,
    parameter BACKGROUND_COLOR = 1
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
    
    reg valid_delay_1, valid_delay_2, valid_delay_3;
    
    wire [DATA_WIDTH-1:0] background_value;
    assign background_value = (BACKGROUND_COLOR == 1) ? {DATA_WIDTH{1'b1}} : {DATA_WIDTH{1'b0}};
    
    wire [DATA_WIDTH-1:0] foreground_value;
    assign foreground_value = (BACKGROUND_COLOR == 1) ? {DATA_WIDTH{1'b0}} : {DATA_WIDTH{1'b1}};
    
    integer i;
    initial begin
        for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
            line_buffer_0[i] = {DATA_WIDTH{1'b0}};
            line_buffer_1[i] = {DATA_WIDTH{1'b0}};
        end
        window_00 = {DATA_WIDTH{1'b0}};
        window_01 = {DATA_WIDTH{1'b0}};
        window_02 = {DATA_WIDTH{1'b0}};
        window_10 = {DATA_WIDTH{1'b0}};
        window_11 = {DATA_WIDTH{1'b0}};
        window_12 = {DATA_WIDTH{1'b0}};
        window_20 = {DATA_WIDTH{1'b0}};
        window_21 = {DATA_WIDTH{1'b0}};
        window_22 = {DATA_WIDTH{1'b0}};
        col_counter_d1 = {WIDTH_BITS{1'b0}};
        col_counter_d2 = {WIDTH_BITS{1'b0}};
        row_counter_d1 = {HEIGHT_BITS{1'b0}};
        row_counter_d2 = {HEIGHT_BITS{1'b0}};
        valid_delay_1 = 1'b0;
        valid_delay_2 = 1'b0;
        valid_delay_3 = 1'b0;
        pixel_out_valid = 1'b0;
        pixel_out = {DATA_WIDTH{1'b0}};
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                line_buffer_0[i] <= {DATA_WIDTH{1'b0}};
                line_buffer_1[i] <= {DATA_WIDTH{1'b0}};
            end
            window_00 <= {DATA_WIDTH{1'b0}};
            window_01 <= {DATA_WIDTH{1'b0}};
            window_02 <= {DATA_WIDTH{1'b0}};
            window_10 <= {DATA_WIDTH{1'b0}};
            window_11 <= {DATA_WIDTH{1'b0}};
            window_12 <= {DATA_WIDTH{1'b0}};
            window_20 <= {DATA_WIDTH{1'b0}};
            window_21 <= {DATA_WIDTH{1'b0}};
            window_22 <= {DATA_WIDTH{1'b0}};
            col_counter_d1 <= {WIDTH_BITS{1'b0}};
            col_counter_d2 <= {WIDTH_BITS{1'b0}};
            row_counter_d1 <= {HEIGHT_BITS{1'b0}};
            row_counter_d2 <= {HEIGHT_BITS{1'b0}};
            valid_delay_1 <= 1'b0;
            valid_delay_2 <= 1'b0;
            valid_delay_3 <= 1'b0;
            pixel_out_valid <= 1'b0;
            pixel_out <= {DATA_WIDTH{1'b0}};
        end else begin
            valid_delay_1 <= pixel_valid;
            valid_delay_2 <= valid_delay_1;
            valid_delay_3 <= valid_delay_2;
            pixel_out_valid <= valid_delay_3;
            
            if (pixel_valid) begin
                line_buffer_1[col_counter_d1] <= line_buffer_0[col_counter_d1];
                line_buffer_0[col_counter_d1] <= pixel_in;
                
                if (col_counter_d1 == IMAGE_WIDTH - 1) begin
                    col_counter_d1 <= {WIDTH_BITS{1'b0}};
                    if (row_counter_d1 == IMAGE_HEIGHT - 1) begin
                        row_counter_d1 <= {HEIGHT_BITS{1'b0}};
                    end else begin
                        row_counter_d1 <= row_counter_d1 + 1;
                    end
                end else begin
                    col_counter_d1 <= col_counter_d1 + 1;
                end
                
                col_counter_d2 <= col_counter_d1;
                row_counter_d2 <= row_counter_d1;
            end
            
            if (valid_delay_1) begin
                if (row_counter_d2 > 0) begin
                    window_00 <= (col_counter_d2 > 0) ? line_buffer_1[col_counter_d2-1] : {DATA_WIDTH{1'b0}};
                    window_01 <= line_buffer_1[col_counter_d2];
                    window_02 <= (col_counter_d2 < IMAGE_WIDTH-1) ? line_buffer_1[col_counter_d2+1] : {DATA_WIDTH{1'b0}};
                end else begin
                    window_00 <= {DATA_WIDTH{1'b0}};
                    window_01 <= {DATA_WIDTH{1'b0}};
                    window_02 <= {DATA_WIDTH{1'b0}};
                end
                
                window_10 <= (col_counter_d2 > 0) ? line_buffer_0[col_counter_d2-1] : {DATA_WIDTH{1'b0}};
                window_11 <= line_buffer_0[col_counter_d2];
                window_12 <= (col_counter_d2 < IMAGE_WIDTH-1) ? line_buffer_0[col_counter_d2+1] : {DATA_WIDTH{1'b0}};
                
                if (row_counter_d2 < IMAGE_HEIGHT - 1) begin
                    window_20 <= (col_counter_d2 > 0) ? line_buffer_0[col_counter_d2-1] : {DATA_WIDTH{1'b0}};
                    window_21 <= line_buffer_0[col_counter_d2];
                    window_22 <= (col_counter_d2 < IMAGE_WIDTH-1) ? line_buffer_0[col_counter_d2+1] : {DATA_WIDTH{1'b0}};
                end else begin
                    window_20 <= {DATA_WIDTH{1'b0}};
                    window_21 <= {DATA_WIDTH{1'b0}};
                    window_22 <= {DATA_WIDTH{1'b0}};
                end
            end
            
            if (valid_delay_3) begin
                if (row_counter_d2 < 1 || row_counter_d2 >= IMAGE_HEIGHT - 1 || 
                    col_counter_d2 < 1 || col_counter_d2 >= IMAGE_WIDTH - 1) begin
                    pixel_out <= background_value;
                end else begin
                    if (BACKGROUND_COLOR == 1) begin
                        if (window_00 == 8'd0 || window_01 == 8'd0 || window_02 == 8'd0 ||
                            window_10 == 8'd0 || window_11 == 8'd0 || window_12 == 8'd0 ||
                            window_20 == 8'd0 || window_21 == 8'd0 || window_22 == 8'd0) begin
                            pixel_out <= foreground_value;
                        end else begin
                            pixel_out <= background_value;
                        end
                    end else begin
                        if (window_00 == 8'd255 || window_01 == 8'd255 || window_02 == 8'd255 ||
                            window_10 == 8'd255 || window_11 == 8'd255 || window_12 == 8'd255 ||
                            window_20 == 8'd255 || window_21 == 8'd255 || window_22 == 8'd255) begin
                            pixel_out <= foreground_value;
                        end else begin
                            pixel_out <= background_value;
                        end
                    end
                end
            end else begin
                pixel_out <= background_value;
            end
        end
    end

endmodule