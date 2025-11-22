module bilateral9x9 #(
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
    reg [7:0] linebuf2 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf3 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf4 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf5 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf6 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf7 [0:IMAGE_WIDTH-1];

    reg [7:0] r0_c0, r0_c1, r0_c2, r0_c3, r0_c4, r0_c5, r0_c6, r0_c7, r0_c8;
    reg [7:0] r1_c0, r1_c1, r1_c2, r1_c3, r1_c4, r1_c5, r1_c6, r1_c7, r1_c8;
    reg [7:0] r2_c0, r2_c1, r2_c2, r2_c3, r2_c4, r2_c5, r2_c6, r2_c7, r2_c8;
    reg [7:0] r3_c0, r3_c1, r3_c2, r3_c3, r3_c4, r3_c5, r3_c6, r3_c7, r3_c8;
    reg [7:0] r4_c0, r4_c1, r4_c2, r4_c3, r4_c4, r4_c5, r4_c6, r4_c7, r4_c8;
    reg [7:0] r5_c0, r5_c1, r5_c2, r5_c3, r5_c4, r5_c5, r5_c6, r5_c7, r5_c8;
    reg [7:0] r6_c0, r6_c1, r6_c2, r6_c3, r6_c4, r6_c5, r6_c6, r6_c7, r6_c8;
    reg [7:0] r7_c0, r7_c1, r7_c2, r7_c3, r7_c4, r7_c5, r7_c6, r7_c7, r7_c8;
    reg [7:0] r8_c0, r8_c1, r8_c2, r8_c3, r8_c4, r8_c5, r8_c6, r8_c7, r8_c8;

    reg [7:0] t0, t1, t2, t3, t4, t5, t6, t7;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    localparam integer B0 = 1;
    localparam integer B1 = 8;
    localparam integer B2 = 28;
    localparam integer B3 = 56;
    localparam integer B4 = 70;
    localparam integer B5 = 56;
    localparam integer B6 = 28;
    localparam integer B7 = 8;
    localparam integer B8 = 1;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            bilat_valid <= 1'b0;
            bilat_out <= 8'd0;
            center_row_s1 <= 32'd0;
            center_col_s1 <= 32'd0;

            { r0_c0, r0_c1, r0_c2, r0_c3, r0_c4, r0_c5, r0_c6, r0_c7, r0_c8 } <= 9'd0;
            { r1_c0, r1_c1, r1_c2, r1_c3, r1_c4, r1_c5, r1_c6, r1_c7, r1_c8 } <= 9'd0;
            { r2_c0, r2_c1, r2_c2, r2_c3, r2_c4, r2_c5, r2_c6, r2_c7, r2_c8 } <= 9'd0;
            { r3_c0, r3_c1, r3_c2, r3_c3, r3_c4, r3_c5, r3_c6, r3_c7, r3_c8 } <= 9'd0;
            { r4_c0, r4_c1, r4_c2, r4_c3, r4_c4, r4_c5, r4_c6, r4_c7, r4_c8 } <= 9'd0;
            { r5_c0, r5_c1, r5_c2, r5_c3, r5_c4, r5_c5, r5_c6, r5_c7, r5_c8 } <= 9'd0;
            { r6_c0, r6_c1, r6_c2, r6_c3, r6_c4, r6_c5, r6_c6, r6_c7, r6_c8 } <= 9'd0;
            { r7_c0, r7_c1, r7_c2, r7_c3, r7_c4, r7_c5, r7_c6, r7_c7, r7_c8 } <= 9'd0;
            { r8_c0, r8_c1, r8_c2, r8_c3, r8_c4, r8_c5, r8_c6, r8_c7, r8_c8 } <= 9'd0;

            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                linebuf0[i] <= 8'd0;
                linebuf1[i] <= 8'd0;
                linebuf2[i] <= 8'd0;
                linebuf3[i] <= 8'd0;
                linebuf4[i] <= 8'd0;
                linebuf5[i] <= 8'd0;
                linebuf6[i] <= 8'd0;
                linebuf7[i] <= 8'd0;
            end
        end else begin
            bilat_valid <= 1'b0;
            if (gray_valid) begin
                t0 <= linebuf0[col_ptr];
                t1 <= linebuf1[col_ptr];
                t2 <= linebuf2[col_ptr];
                t3 <= linebuf3[col_ptr];
                t4 <= linebuf4[col_ptr];
                t5 <= linebuf5[col_ptr];
                t6 <= linebuf6[col_ptr];
                t7 <= linebuf7[col_ptr];

                r0_c0 <= r0_c1; r0_c1 <= r0_c2; r0_c2 <= r0_c3; r0_c3 <= r0_c4; r0_c4 <= r0_c5; r0_c5 <= r0_c6; r0_c6 <= r0_c7; r0_c7 <= r0_c8; r0_c8 <= t7;
                r1_c0 <= r1_c1; r1_c1 <= r1_c2; r1_c2 <= r1_c3; r1_c3 <= r1_c4; r1_c4 <= r1_c5; r1_c5 <= r1_c6; r1_c6 <= r1_c7; r1_c7 <= r1_c8; r1_c8 <= t6;
                r2_c0 <= r2_c1; r2_c1 <= r2_c2; r2_c2 <= r2_c3; r2_c3 <= r2_c4; r2_c4 <= r2_c5; r2_c5 <= r2_c6; r2_c6 <= r2_c7; r2_c7 <= r2_c8; r2_c8 <= t5;
                r3_c0 <= r3_c1; r3_c1 <= r3_c2; r3_c2 <= r3_c3; r3_c3 <= r3_c4; r3_c4 <= r3_c5; r3_c5 <= r3_c6; r3_c6 <= r3_c7; r3_c7 <= r3_c8; r3_c8 <= t4;
                r4_c0 <= r4_c1; r4_c1 <= r4_c2; r4_c2 <= r4_c3; r4_c3 <= r4_c4; r4_c4 <= r4_c5; r4_c5 <= r4_c6; r4_c6 <= r4_c7; r4_c7 <= r4_c8; r4_c8 <= t3;
                r5_c0 <= r5_c1; r5_c1 <= r5_c2; r5_c2 <= r5_c3; r5_c3 <= r5_c4; r5_c4 <= r5_c5; r5_c5 <= r5_c6; r5_c6 <= r5_c7; r5_c7 <= r5_c8; r5_c8 <= t2;
                r6_c0 <= r6_c1; r6_c1 <= r6_c2; r6_c2 <= r6_c3; r6_c3 <= r6_c4; r6_c4 <= r6_c5; r6_c5 <= r6_c6; r6_c6 <= r6_c7; r6_c7 <= r6_c8; r6_c8 <= t1;
                r7_c0 <= r7_c1; r7_c1 <= r7_c2; r7_c2 <= r7_c3; r7_c3 <= r7_c4; r7_c4 <= r7_c5; r7_c5 <= r7_c6; r7_c6 <= r7_c7; r7_c7 <= r7_c8; r7_c8 <= t0;
                r8_c0 <= r8_c1; r8_c1 <= r8_c2; r8_c2 <= r8_c3; r8_c3 <= r8_c4; r8_c4 <= r8_c5; r8_c5 <= r8_c6; r8_c6 <= r8_c7; r8_c7 <= r8_c8; r8_c8 <= gray;

                linebuf7[col_ptr] <= linebuf6[col_ptr];
                linebuf6[col_ptr] <= linebuf5[col_ptr];
                linebuf5[col_ptr] <= linebuf4[col_ptr];
                linebuf4[col_ptr] <= linebuf3[col_ptr];
                linebuf3[col_ptr] <= linebuf2[col_ptr];
                linebuf2[col_ptr] <= linebuf1[col_ptr];
                linebuf1[col_ptr] <= linebuf0[col_ptr];
                linebuf0[col_ptr] <= gray;

                if (col_ptr == {COL_W{1'b0}}) center_col_s1 <= 32'd0;
                else center_col_s1 <= { { (32-COL_W){1'b0} }, (col_ptr - 1) };
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

    function [15:0] coef9;
        input integer idx;
        begin
            case (idx)
                0: coef9 = B0;
                1: coef9 = B1;
                2: coef9 = B2;
                3: coef9 = B3;
                4: coef9 = B4;
                5: coef9 = B5;
                6: coef9 = B6;
                7: coef9 = B7;
                8: coef9 = B8;
                default: coef9 = 0;
            endcase
        end
    endfunction

    function [7:0] get_pix;
        input integer ri, ci;
        begin
            case (ri)
                0: case (ci)
                     0: get_pix = r0_c0;  1: get_pix = r0_c1;  2: get_pix = r0_c2;  3: get_pix = r0_c3;  4: get_pix = r0_c4;  5: get_pix = r0_c5;  6: get_pix = r0_c6;  7: get_pix = r0_c7;  8: get_pix = r0_c8;
                   endcase
                1: case (ci)
                     0: get_pix = r1_c0;  1: get_pix = r1_c1;  2: get_pix = r1_c2;  3: get_pix = r1_c3;  4: get_pix = r1_c4;  5: get_pix = r1_c5;  6: get_pix = r1_c6;  7: get_pix = r1_c7;  8: get_pix = r1_c8;
                   endcase
                2: case (ci)
                     0: get_pix = r2_c0;  1: get_pix = r2_c1;  2: get_pix = r2_c2;  3: get_pix = r2_c3;  4: get_pix = r2_c4;  5: get_pix = r2_c5;  6: get_pix = r2_c6;  7: get_pix = r2_c7;  8: get_pix = r2_c8;
                   endcase
                3: case (ci)
                     0: get_pix = r3_c0;  1: get_pix = r3_c1;  2: get_pix = r3_c2;  3: get_pix = r3_c3;  4: get_pix = r3_c4;  5: get_pix = r3_c5;  6: get_pix = r3_c6;  7: get_pix = r3_c7;  8: get_pix = r3_c8;
                   endcase
                4: case (ci)
                     0: get_pix = r4_c0;  1: get_pix = r4_c1;  2: get_pix = r4_c2;  3: get_pix = r4_c3;  4: get_pix = r4_c4;  5: get_pix = r4_c5;  6: get_pix = r4_c6;  7: get_pix = r4_c7;  8: get_pix = r4_c8;
                   endcase
                5: case (ci)
                     0: get_pix = r5_c0;  1: get_pix = r5_c1;  2: get_pix = r5_c2;  3: get_pix = r5_c3;  4: get_pix = r5_c4;  5: get_pix = r5_c5;  6: get_pix = r5_c6;  7: get_pix = r5_c7;  8: get_pix = r5_c8;
                   endcase
                6: case (ci)
                     0: get_pix = r6_c0;  1: get_pix = r6_c1;  2: get_pix = r6_c2;  3: get_pix = r6_c3;  4: get_pix = r6_c4;  5: get_pix = r6_c5;  6: get_pix = r6_c6;  7: get_pix = r6_c7;  8: get_pix = r6_c8;
                   endcase
                7: case (ci)
                     0: get_pix = r7_c0;  1: get_pix = r7_c1;  2: get_pix = r7_c2;  3: get_pix = r7_c3;  4: get_pix = r7_c4;  5: get_pix = r7_c5;  6: get_pix = r7_c6;  7: get_pix = r7_c7;  8: get_pix = r7_c8;
                   endcase
                8: case (ci)
                     0: get_pix = r8_c0;  1: get_pix = r8_c1;  2: get_pix = r8_c2;  3: get_pix = r8_c3;  4: get_pix = r8_c4;  5: get_pix = r8_c5;  6: get_pix = r8_c6;  7: get_pix = r8_c7;  8: get_pix = r8_c8;
                   endcase
                default: get_pix = 8'd0;
            endcase
        end
    endfunction

    reg [31:0] sum_w;
    reg [39:0] sum_n;
    reg [23:0] prod_w;
    reg [39:0] prod_n;
    integer ii, jj;
    reg [7:0] center_pix;
    reg [8:0] absd;
    reg [15:0] range_w;
    reg [15:0] sp_h, sp_v;
    reg [31:0] spatial;

    always @(posedge clk) begin
        if (rst) begin
            bilat_out <= 8'd0;
            bilat_valid <= 1'b0;
            sum_w <= 32'd0;
            sum_n <= 40'd0;
        end else begin
            center_pix = r4_c4;

            sum_w = 0;
            sum_n = 0;

            for (ii = 0; ii < 9; ii = ii + 1) begin
                for (jj = 0; jj < 9; jj = jj + 1) begin
                    sp_v = coef9(ii);
                    sp_h = coef9(jj);
                    spatial = sp_v * sp_h;

                    prod_n = 0;
                    prod_w = 0;
                    absd = (center_pix > get_pix(ii,jj)) ? (center_pix - get_pix(ii,jj)) : (get_pix(ii,jj) - center_pix);
                    range_w = (absd >= 9'd128) ? 16'd0 : (16'd256 - {7'd0, absd}*2);
                    prod_w = spatial * range_w;
                    prod_n = prod_w * get_pix(ii,jj);
                    sum_w = sum_w + prod_w;
                    sum_n = sum_n + prod_n;
                end
            end

            if (sum_w == 0) bilat_out <= center_pix;
            else bilat_out <= sum_n / sum_w;

            if ((center_row_s1 >= 4) && (center_col_s1 >= 4)) bilat_valid <= 1'b1;
            else bilat_valid <= 1'b0;
        end
    end

endmodule