module mean9x9 #(
    parameter IMAGE_WIDTH = 320
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        gray_valid,
    input  wire [7:0]  gray,
    output reg         mean_valid,
    output reg [7:0]   mean_out,
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

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    reg [7:0] t0, t1, t2, t3, t4, t5, t6, t7;

    reg [7:0] arr [0:80];
    integer i, j;
    integer sum;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            mean_valid <= 1'b0;
            mean_out <= 8'd0;
            center_row_s1 <= 32'd0;
            center_col_s1 <= 32'd0;
            r0_c0 <= 8'd0; r0_c1 <= 8'd0; r0_c2 <= 8'd0; r0_c3 <= 8'd0; r0_c4 <= 8'd0; r0_c5 <= 8'd0; r0_c6 <= 8'd0; r0_c7 <= 8'd0; r0_c8 <= 8'd0;
            r1_c0 <= 8'd0; r1_c1 <= 8'd0; r1_c2 <= 8'd0; r1_c3 <= 8'd0; r1_c4 <= 8'd0; r1_c5 <= 8'd0; r1_c6 <= 8'd0; r1_c7 <= 8'd0; r1_c8 <= 8'd0;
            r2_c0 <= 8'd0; r2_c1 <= 8'd0; r2_c2 <= 8'd0; r2_c3 <= 8'd0; r2_c4 <= 8'd0; r2_c5 <= 8'd0; r2_c6 <= 8'd0; r2_c7 <= 8'd0; r2_c8 <= 8'd0;
            r3_c0 <= 8'd0; r3_c1 <= 8'd0; r3_c2 <= 8'd0; r3_c3 <= 8'd0; r3_c4 <= 8'd0; r3_c5 <= 8'd0; r3_c6 <= 8'd0; r3_c7 <= 8'd0; r3_c8 <= 8'd0;
            r4_c0 <= 8'd0; r4_c1 <= 8'd0; r4_c2 <= 8'd0; r4_c3 <= 8'd0; r4_c4 <= 8'd0; r4_c5 <= 8'd0; r4_c6 <= 8'd0; r4_c7 <= 8'd0; r4_c8 <= 8'd0;
            r5_c0 <= 8'd0; r5_c1 <= 8'd0; r5_c2 <= 8'd0; r5_c3 <= 8'd0; r5_c4 <= 8'd0; r5_c5 <= 8'd0; r5_c6 <= 8'd0; r5_c7 <= 8'd0; r5_c8 <= 8'd0;
            r6_c0 <= 8'd0; r6_c1 <= 8'd0; r6_c2 <= 8'd0; r6_c3 <= 8'd0; r6_c4 <= 8'd0; r6_c5 <= 8'd0; r6_c6 <= 8'd0; r6_c7 <= 8'd0; r6_c8 <= 8'd0;
            r7_c0 <= 8'd0; r7_c1 <= 8'd0; r7_c2 <= 8'd0; r7_c3 <= 8'd0; r7_c4 <= 8'd0; r7_c5 <= 8'd0; r7_c6 <= 8'd0; r7_c7 <= 8'd0; r7_c8 <= 8'd0;
            r8_c0 <= 8'd0; r8_c1 <= 8'd0; r8_c2 <= 8'd0; r8_c3 <= 8'd0; r8_c4 <= 8'd0; r8_c5 <= 8'd0; r8_c6 <= 8'd0; r8_c7 <= 8'd0; r8_c8 <= 8'd0;
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
            mean_valid <= 1'b0;
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

    always @(posedge clk) begin
        if (rst) begin
            mean_out <= 8'd0;
            mean_valid <= 1'b0;
            for (i = 0; i < 81; i = i + 1) begin
                arr[i] <= 8'd0;
            end
        end else begin
            arr[0]  <= r0_c0; arr[1]  <= r0_c1; arr[2]  <= r0_c2; arr[3]  <= r0_c3; arr[4]  <= r0_c4; arr[5]  <= r0_c5; arr[6]  <= r0_c6; arr[7]  <= r0_c7; arr[8]  <= r0_c8;
            arr[9]  <= r1_c0; arr[10] <= r1_c1; arr[11] <= r1_c2; arr[12] <= r1_c3; arr[13] <= r1_c4; arr[14] <= r1_c5; arr[15] <= r1_c6; arr[16] <= r1_c7; arr[17] <= r1_c8;
            arr[18] <= r2_c0; arr[19] <= r2_c1; arr[20] <= r2_c2; arr[21] <= r2_c3; arr[22] <= r2_c4; arr[23] <= r2_c5; arr[24] <= r2_c6; arr[25] <= r2_c7; arr[26] <= r2_c8;
            arr[27] <= r3_c0; arr[28] <= r3_c1; arr[29] <= r3_c2; arr[30] <= r3_c3; arr[31] <= r3_c4; arr[32] <= r3_c5; arr[33] <= r3_c6; arr[34] <= r3_c7; arr[35] <= r3_c8;
            arr[36] <= r4_c0; arr[37] <= r4_c1; arr[38] <= r4_c2; arr[39] <= r4_c3; arr[40] <= r4_c4; arr[41] <= r4_c5; arr[42] <= r4_c6; arr[43] <= r4_c7; arr[44] <= r4_c8;
            arr[45] <= r5_c0; arr[46] <= r5_c1; arr[47] <= r5_c2; arr[48] <= r5_c3; arr[49] <= r5_c4; arr[50] <= r5_c5; arr[51] <= r5_c6; arr[52] <= r5_c7; arr[53] <= r5_c8;
            arr[54] <= r6_c0; arr[55] <= r6_c1; arr[56] <= r6_c2; arr[57] <= r6_c3; arr[58] <= r6_c4; arr[59] <= r6_c5; arr[60] <= r6_c6; arr[61] <= r6_c7; arr[62] <= r6_c8;
            arr[63] <= r7_c0; arr[64] <= r7_c1; arr[65] <= r7_c2; arr[66] <= r7_c3; arr[67] <= r7_c4; arr[68] <= r7_c5; arr[69] <= r7_c6; arr[70] <= r7_c7; arr[71] <= r7_c8;
            arr[72] <= r8_c0; arr[73] <= r8_c1; arr[74] <= r8_c2; arr[75] <= r8_c3; arr[76] <= r8_c4; arr[77] <= r8_c5; arr[78] <= r8_c6; arr[79] <= r8_c7; arr[80] <= r8_c8;

            sum = 0;
            for (i = 0; i < 81; i = i + 1) begin
                sum = sum + arr[i];
            end

            mean_out <= sum / 81;

            if ((center_row_s1 >= 4) && (center_col_s1 >= 4)) mean_valid <= 1'b1;
            else mean_valid <= 1'b0;
        end
    end

endmodule