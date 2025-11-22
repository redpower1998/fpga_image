module bilateral5x5 #(
    parameter IMAGE_WIDTH = 320,
    parameter IMAGE_HEIGHT = 240
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
    reg [7:0] linebuf2 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf3 [0:IMAGE_WIDTH-1];

    reg [7:0] r0_c0, r0_c1, r0_c2, r0_c3, r0_c4;
    reg [7:0] r1_c0, r1_c1, r1_c2, r1_c3, r1_c4;
    reg [7:0] r2_c0, r2_c1, r2_c2, r2_c3, r2_c4;
    reg [7:0] r3_c0, r3_c1, r3_c2, r3_c3, r3_c4;
    reg [7:0] r4_c0, r4_c1, r4_c2, r4_c3, r4_c4;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    reg [7:0] t0, t1, t2, t3;

    localparam integer S00 = 1, S01 = 4, S02 = 6, S03 = 4, S04 = 1;
    localparam integer S10 = 4, S11 = 16, S12 = 24, S13 = 16, S14 = 4;
    localparam integer S20 = 6, S21 = 24, S22 = 36, S23 = 24, S24 = 6;
    localparam integer S30 = 4, S31 = 16, S32 = 24, S33 = 16, S34 = 4;
    localparam integer S40 = 1, S41 = 4, S42 = 6, S43 = 4, S44 = 1;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            bilat_valid <= 1'b0;
            bilat_out <= 8'd0;
            center_row_s1 <= 32'd0;
            center_col_s1 <= 32'd0;
            r0_c0 <= 8'd0; r0_c1 <= 8'd0; r0_c2 <= 8'd0; r0_c3 <= 8'd0; r0_c4 <= 8'd0;
            r1_c0 <= 8'd0; r1_c1 <= 8'd0; r1_c2 <= 8'd0; r1_c3 <= 8'd0; r1_c4 <= 8'd0;
            r2_c0 <= 8'd0; r2_c1 <= 8'd0; r2_c2 <= 8'd0; r2_c3 <= 8'd0; r2_c4 <= 8'd0;
            r3_c0 <= 8'd0; r3_c1 <= 8'd0; r3_c2 <= 8'd0; r3_c3 <= 8'd0; r3_c4 <= 8'd0;
            r4_c0 <= 8'd0; r4_c1 <= 8'd0; r4_c2 <= 8'd0; r4_c3 <= 8'd0; r4_c4 <= 8'd0;
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                linebuf0[i] <= 8'd0;
                linebuf1[i] <= 8'd0;
                linebuf2[i] <= 8'd0;
                linebuf3[i] <= 8'd0;
            end
        end else begin
            bilat_valid <= 1'b0;
            if (gray_valid) begin
                t0 <= linebuf0[col_ptr];
                t1 <= linebuf1[col_ptr];
                t2 <= linebuf2[col_ptr];
                t3 <= linebuf3[col_ptr];

                r0_c0 <= r0_c1; r0_c1 <= r0_c2; r0_c2 <= r0_c3; r0_c3 <= r0_c4; r0_c4 <= t3;
                r1_c0 <= r1_c1; r1_c1 <= r1_c2; r1_c2 <= r1_c3; r1_c3 <= r1_c4; r1_c4 <= t2;
                r2_c0 <= r2_c1; r2_c1 <= r2_c2; r2_c2 <= r2_c3; r2_c3 <= r2_c4; r2_c4 <= t1;
                r3_c0 <= r3_c1; r3_c1 <= r3_c2; r3_c2 <= r3_c3; r3_c3 <= r3_c4; r3_c4 <= t0;
                r4_c0 <= r4_c1; r4_c1 <= r4_c2; r4_c2 <= r4_c3; r4_c3 <= r4_c4; r4_c4 <= gray;

                linebuf3[col_ptr] <= linebuf2[col_ptr];
                linebuf2[col_ptr] <= linebuf1[col_ptr];
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

                $display("Module: gray_valid=1, col_ptr=%0d, row_cnt=%0d, center_col_s1=%0d, center_row_s1=%0d", 
                         col_ptr, row_cnt, center_col_s1, center_row_s1);
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
            center_pix = r2_c2;

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

            neigh = r0_c3; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S03 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r0_c4; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S04 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r1_c0; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S10 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r1_c1; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S11 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r1_c2; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S12 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r1_c3; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S13 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r1_c4; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S14 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r2_c0; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S20 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r2_c1; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S21 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r2_c2; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S22 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r2_c3; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S23 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r2_c4; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S24 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r3_c0; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S30 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r3_c1; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S31 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r3_c2; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S32 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r3_c3; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S33 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r3_c4; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S34 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r4_c0; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S40 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r4_c1; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S41 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r4_c2; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S42 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r4_c3; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S43 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            neigh = r4_c4; absd = (center_pix > neigh) ? (center_pix - neigh) : (neigh - center_pix);
            range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
            prod_w = S44 * range_w; tmp_sum_w = tmp_sum_w + prod_w; tmp_sum_n = tmp_sum_n + prod_w * neigh;

            if (tmp_sum_w == 0) bilat_out <= center_pix;
            else bilat_out <= tmp_sum_n / tmp_sum_w;

            if ((center_row_s1 >= 2) && (center_col_s1 >= 2) && 
                (center_col_s1 < IMAGE_WIDTH - 2) && (center_row_s1 < IMAGE_HEIGHT - 2)) 
                bilat_valid <= 1'b1;
            else 
                bilat_valid <= 1'b0;
        end
    end

endmodule