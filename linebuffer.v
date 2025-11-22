module mean9x9 #(
    parameter IMAGE_WIDTH = 320
)(
    input wire clk,
    input wire rst,
    input wire gray_valid,
    input wire [7:0] gray,
    output reg mean_valid,
    output reg [7:0] mean_out,
    output reg [31:0] center_row_s1,
    output reg [31:0] center_col_s1
);

    localparam integer COL_W = (IMAGE_WIDTH > 1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [7:0] linebuf[0:8][0:IMAGE_WIDTH-1];

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    integer pixel_count;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            mean_valid <= 1'b0;
            mean_out <= 8'd0;
            pixel_count <= 0;
        end else begin
            if (gray_valid) begin
                for (integer i = 8; i > 0; i = i - 1) begin
                    linebuf[i] <= linebuf[i-1];
                end
                linebuf[0][col_ptr] <= gray;

                if (row_cnt >= 8) begin
                    pixel_count = 0;
                    mean_out = 0;
                    for (integer r = 0; r < 9; r = r + 1) begin
                        for (integer c = 0; c < 9; c = c + 1) begin
                            mean_out = mean_out + linebuf[r][col_ptr + c];
                            pixel_count = pixel_count + 1;
                        end
                    end
                    mean_out = mean_out / pixel_count;
                    mean_valid <= 1'b1;
                end else begin
                    mean_valid <= 1'b0;
                end
                col_ptr <= col_ptr + 1;
                if (col_ptr == IMAGE_WIDTH - 1) begin
                    col_ptr <= 0;
                    row_cnt <= row_cnt + 1;
                end
            end
        end
    end

endmodule