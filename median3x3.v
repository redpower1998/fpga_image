module median3x3 #(
    parameter IMAGE_WIDTH = 320
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        gray_valid,
    input  wire [7:0]  gray,
    output reg         median_valid,
    output reg [7:0]   median_out,
    output reg [31:0]  center_row_s1,
    output reg [31:0]  center_col_s1
);

    localparam integer COL_W = (IMAGE_WIDTH>1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [7:0] linebuf0 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf1 [0:IMAGE_WIDTH-1];

    reg [7:0] top_l, top_c, top_r;
    reg [7:8] mid_l;
    reg [7:0] mid_c, mid_r;
    reg [7:0] bot_l, bot_c, bot_r;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    reg [7:0] top_read, mid_read;

    reg [7:0] arr [0:8];
    reg [7:0] s   [0:8];
    integer ii, jj;
    reg [7:0] key;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            median_valid <= 1'b0;
            median_out <= 8'd0;
            top_l <= 8'd0; top_c <= 8'd0; top_r <= 8'd0;
            mid_l <= 8'd0; mid_c <= 8'd0; mid_r <= 8'd0;
            bot_l <= 8'd0; bot_c <= 8'd0; bot_r <= 8'd0;
            center_col_s1 <= 32'd0;
            center_row_s1 <= 32'd0;
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                linebuf0[i] <= 8'd0;
                linebuf1[i] <= 8'd0;
            end
        end else begin
            median_valid <= 1'b0;
            if (gray_valid) begin
                top_read <= linebuf1[col_ptr];
                mid_read <= linebuf0[col_ptr];

                top_l <= top_c; top_c <= top_r; top_r <= top_read;
                mid_l <= mid_c; mid_c <= mid_r; mid_r <= mid_read;
                bot_l <= bot_c; bot_c <= bot_r; bot_r <= gray;

                linebuf1[col_ptr] <= linebuf0[col_ptr];
                linebuf0[col_ptr] <= gray;

                if (col_ptr == {COL_W{1'b0}}) center_col_s1 <= 32'd0;
                else center_col_s1 <= { { (32-COL_W){1'b0} }, (col_ptr - {COL_W{1'b1}}) };
                center_row_s1 <= row_cnt;

                if (col_ptr == IMAGE_WIDTH - 1) begin
                    col_ptr <= {COL_W{1'b0}};
                    row_cnt <= row_cnt + 1;
                end else begin
                    col_ptr <= col_ptr + 1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            median_out <= 8'd0;
            median_valid <= 1'b0;
            for (i = 0; i < 9; i = i + 1) begin
                arr[i] <= 8'd0;
                s[i]   <= 8'd0;
            end
        end else begin
            arr[0] <= top_l; arr[1] <= top_c; arr[2] <= top_r;
            arr[3] <= mid_l; arr[4] <= mid_c; arr[5] <= mid_r;
            arr[6] <= bot_l; arr[7] <= bot_c; arr[8] <= bot_r;

            s[0] = arr[0];
            ii = 1;
            while (ii < 9) begin
                key = arr[ii];
                jj = ii - 1;
                while ((jj >= 0) && (s[jj] > key)) begin
                    s[jj+1] = s[jj];
                    jj = jj - 1;
                end
                s[jj+1] = key;
                ii = ii + 1;
            end

            median_out <= s[4];

            if ((center_row_s1 >= 1) && (center_col_s1 >= 1)) median_valid <= 1'b1;
            else median_valid <= 1'b0;
        end
    end

endmodule