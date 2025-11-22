module bilateral3x3 #(
    parameter IMAGE_WIDTH = 320
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        gray_valid,
    input  wire [7:0]  gray,
    output reg         bilat_valid,
    output reg [7:0]   bilat_out,
    output reg [31:0]  center_row_s1,
    output reg [31:0]  center_col_s1
);

    localparam integer COL_W = (IMAGE_WIDTH>1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [7:0] linebuf0 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf1 [0:IMAGE_WIDTH-1];

    reg [7:0] r0_c0, r0_c1, r0_c2;
    reg [7:0] r1_c0, r1_c1, r1_c2;
    reg [7:0] r2_c0, r2_c1, r2_c2;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    reg [7:0] t0, t1;

    localparam integer S00 = 1, S01 = 2, S02 = 1;
    localparam integer S10 = 2, S11 = 4, S12 = 2;
    localparam integer S20 = 1, S21 = 2, S22 = 1;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            bilat_valid <= 1'b0;
            bilat_out <= 8'd0;
            center_row_s1 <= 32'd0;
            center_col_s1 <= 32'd0;
            r0_c0 <= 8'd0; r0_c1 <= 8'd0; r0_c2 <= 8'd0;
            r1_c0 <= 8'd0; r1_c1 <= 8'd0; r1_c2 <= 8'd0;
            r2_c0 <= 8'd0; r2_c1 <= 8'd0; r2_c2 <= 8'd0;
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                linebuf0[i] <= 8'd0;
                linebuf1[i] <= 8'd0;
            end
        end else begin
            bilat_valid <= 1'b0;
            if (gray_valid) begin
                t0 <= linebuf0[col_ptr];
                t1 <= linebuf1[col_ptr];

                r0_c0 <= r0_c1; r0_c1 <= r0_c2; r0_c2 <= t1;
                r1_c0 <= r1_c1; r1_c1 <= r1_c2; r1_c2 <= t0;
                r2_c0 <= r2_c1; r2_c1 <= r2_c2; r2_c2 <= gray;

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

    reg [7:0] center_pix;
    reg [15:0] range_w;
    reg [15:0] prod_w;
    reg [31:0] tmp_sum_w;
    reg [31:0] tmp_sum_n;
    reg [8:0] absd;
    reg [7:0] neigh;

    always @(posedge clk) begin
        if (rst) begin
            bilat_out <= 8'd0;
            bilat_valid <= 1'b0;
            tmp_sum_w <= 32'd0;
            tmp_sum_n <= 32'd0;
        end else begin
            center_pix = r1_c1;

            tmp_sum_w = 0;
            tmp_sum_n = 0;

            neigh = r0_c0; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S00 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r0_c1; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S01 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r0_c2; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S02 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r1_c0; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S10 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r1_c1; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S11 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r1_c2; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S12 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r2_c0; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S20 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r2_c1; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S21 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r2_c2; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S22 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            if (tmp_sum_w != 0) begin
                bilat_out <= tmp_sum_n / tmp_sum_w;
            end else begin
                bilat_out <= center_pix;
            end

            if ((center_row_s1 >= 1) && (center_col_s1 >= 1)) bilat_valid <= 1'b1;
            else bilat_valid <= 1'b0;
        end
    end

endmodule