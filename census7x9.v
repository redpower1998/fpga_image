module census7x9 #(
    parameter IMAGE_WIDTH = 320
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         gray_valid,
    input  wire [7:0]   gray,
    output reg          census_valid,
    output reg [63:0]   census_out,
    output reg [31:0]   center_row_s1,
    output reg [31:0]   center_col_s1
);

    localparam integer WIN_H = 7;
    localparam integer WIN_W = 9;
    localparam integer COL_W = (IMAGE_WIDTH>1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [7:0] linebuf0 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf1 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf2 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf3 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf4 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf5 [0:IMAGE_WIDTH-1];

    reg [7:0] r0_c0, r0_c1, r0_c2, r0_c3, r0_c4, r0_c5, r0_c6, r0_c7, r0_c8;
    reg [7:0] r1_c0, r1_c1, r1_c2, r1_c3, r1_c4, r1_c5, r1_c6, r1_c7, r1_c8;
    reg [7:0] r2_c0, r2_c1, r2_c2, r2_c3, r2_c4, r2_c5, r2_c6, r2_c7, r2_c8;
    reg [7:0] r3_c0, r3_c1, r3_c2, r3_c3, r3_c4, r3_c5, r3_c6, r3_c7, r3_c8;
    reg [7:0] r4_c0, r4_c1, r4_c2, r4_c3, r4_c4, r4_c5, r4_c6, r4_c7, r4_c8;
    reg [7:0] r5_c0, r5_c1, r5_c2, r5_c3, r5_c4, r5_c5, r5_c6, r5_c7, r5_c8;
    reg [7:0] r6_c0, r6_c1, r6_c2, r6_c3, r6_c4, r6_c5, r6_c6, r6_c7, r6_c8;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    reg [7:0] tmp0, tmp1, tmp2, tmp3, tmp4, tmp5;

    reg [63:0] census_bits;
    reg [7:0] center_val;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= 0;
            row_cnt <= 0;
            census_valid <= 1'b0;
            census_out <= 64'd0;
            center_row_s1 <= 32'd0;
            center_col_s1 <= {32{1'b0}};
            r0_c0 <= 0; r0_c1 <= 0; r0_c2 <= 0; r0_c3 <= 0; r0_c4 <= 0; r0_c5 <= 0; r0_c6 <= 0; r0_c7 <= 0; r0_c8 <= 0;
            r1_c0 <= 0; r1_c1 <= 0; r1_c2 <= 0; r1_c3 <= 0; r1_c4 <= 0; r1_c5 <= 0; r1_c6 <= 0; r1_c7 <= 0; r1_c8 <= 0;
            r2_c0 <= 0; r2_c1 <= 0; r2_c2 <= 0; r2_c3 <= 0; r2_c4 <= 0; r2_c5 <= 0; r2_c6 <= 0; r2_c7 <= 0; r2_c8 <= 0;
            r3_c0 <= 0; r3_c1 <= 0; r3_c2 <= 0; r3_c3 <= 0; r3_c4 <= 0; r3_c5 <= 0; r3_c6 <= 0; r3_c7 <= 0; r3_c8 <= 0;
            r4_c0 <= 0; r4_c1 <= 0; r4_c2 <= 0; r4_c3 <= 0; r4_c4 <= 0; r4_c5 <= 0; r4_c6 <= 0; r4_c7 <= 0; r4_c8 <= 0;
            r5_c0 <= 0; r5_c1 <= 0; r5_c2 <= 0; r5_c3 <= 0; r5_c4 <= 0; r5_c5 <= 0; r5_c6 <= 0; r5_c7 <= 0; r5_c8 <= 0;
            r6_c0 <= 0; r6_c1 <= 0; r6_c2 <= 0; r6_c3 <= 0; r6_c4 <= 0; r6_c5 <= 0; r6_c6 <= 0; r6_c7 <= 0; r6_c8 <= 0;
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                linebuf0[i] <= 8'd0;
                linebuf1[i] <= 8'd0;
                linebuf2[i] <= 8'd0;
                linebuf3[i] <= 8'd0;
                linebuf4[i] <= 8'd0;
                linebuf5[i] <= 8'd0;
            end
        end else begin
            census_valid <= 1'b0;

            if (gray_valid) begin
                tmp0 <= linebuf0[col_ptr];
                tmp1 <= linebuf1[col_ptr];
                tmp2 <= linebuf2[col_ptr];
                tmp3 <= linebuf3[col_ptr];
                tmp4 <= linebuf4[col_ptr];
                tmp5 <= linebuf5[col_ptr];

                r0_c0 <= r0_c1; r0_c1 <= r0_c2; r0_c2 <= r0_c3; r0_c3 <= r0_c4; r0_c4 <= r0_c5; r0_c5 <= r0_c6; r0_c6 <= r0_c7; r0_c7 <= r0_c8; r0_c8 <= tmp5;
                r1_c0 <= r1_c1; r1_c1 <= r1_c2; r1_c2 <= r1_c3; r1_c3 <= r1_c4; r1_c4 <= r1_c5; r1_c5 <= r1_c6; r1_c6 <= r1_c7; r1_c7 <= r1_c8; r1_c8 <= tmp4;
                r2_c0 <= r2_c1; r2_c1 <= r2_c2; r2_c2 <= r2_c3; r2_c3 <= r2_c4; r2_c4 <= r2_c5; r2_c5 <= r2_c6; r2_c6 <= r2_c7; r2_c7 <= r2_c8; r2_c8 <= tmp3;
                r3_c0 <= r3_c1; r3_c1 <= r3_c2; r3_c2 <= r3_c3; r3_c3 <= r3_c4; r3_c4 <= r3_c5; r3_c5 <= r3_c6; r3_c6 <= r3_c7; r3_c7 <= r3_c8; r3_c8 <= tmp2;
                r4_c0 <= r4_c1; r4_c1 <= r4_c2; r4_c2 <= r4_c3; r4_c3 <= r4_c4; r4_c4 <= r4_c5; r4_c5 <= r4_c6; r4_c6 <= r4_c7; r4_c7 <= r4_c8; r4_c8 <= tmp1;
                r5_c0 <= r5_c1; r5_c1 <= r5_c2; r5_c2 <= r5_c3; r5_c3 <= r5_c4; r5_c4 <= r5_c5; r5_c5 <= r5_c6; r5_c6 <= r5_c7; r5_c7 <= r5_c8; r5_c8 <= tmp0;
                r6_c0 <= r6_c1; r6_c1 <= r6_c2; r6_c2 <= r6_c3; r6_c3 <= r6_c4; r6_c4 <= r6_c5; r6_c5 <= r6_c6; r6_c6 <= r6_c7; r6_c7 <= r6_c8; r6_c8 <= gray;

                linebuf5[col_ptr] <= linebuf4[col_ptr];
                linebuf4[col_ptr] <= linebuf3[col_ptr];
                linebuf3[col_ptr] <= linebuf2[col_ptr];
                linebuf2[col_ptr] <= linebuf1[col_ptr];
                linebuf1[col_ptr] <= linebuf0[col_ptr];
                linebuf0[col_ptr] <= gray;

                if (col_ptr == 0) center_col_s1 <= 32'd0;
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
            census_out <= 64'd0;
            census_valid <= 1'b0;
            census_bits <= 64'd0;
            center_val <= 8'd0;
        end else begin
            center_val <= r3_c4;

            census_bits[63] <= (r0_c0 < center_val) ? 1'b1 : 1'b0;
            census_bits[62] <= (r0_c1 < center_val) ? 1'b1 : 1'b0;
            census_bits[61] <= (r0_c2 < center_val) ? 1'b1 : 1'b0;
            census_bits[60] <= (r0_c3 < center_val) ? 1'b1 : 1'b0;
            census_bits[59] <= (r0_c4 < center_val) ? 1'b1 : 1'b0;
            census_bits[58] <= (r0_c5 < center_val) ? 1'b1 : 1'b0;
            census_bits[57] <= (r0_c6 < center_val) ? 1'b1 : 1'b0;
            census_bits[56] <= (r0_c7 < center_val) ? 1'b1 : 1'b0;
            census_bits[55] <= (r0_c8 < center_val) ? 1'b1 : 1'b0;
            census_bits[54] <= (r1_c0 < center_val) ? 1'b1 : 1'b0;
            census_bits[53] <= (r1_c1 < center_val) ? 1'b1 : 1'b0;
            census_bits[52] <= (r1_c2 < center_val) ? 1'b1 : 1'b0;
            census_bits[51] <= (r1_c3 < center_val) ? 1'b1 : 1'b0;
            census_bits[50] <= (r1_c4 < center_val) ? 1'b1 : 1'b0;
            census_bits[49] <= (r1_c5 < center_val) ? 1'b1 : 1'b0;
            census_bits[48] <= (r1_c6 < center_val) ? 1'b1 : 1'b0;
            census_bits[47] <= (r1_c7 < center_val) ? 1'b1 : 1'b0;
            census_bits[46] <= (r1_c8 < center_val) ? 1'b1 : 1'b0;
            census_bits[45] <= (r2_c0 < center_val) ? 1'b1 : 1'b0;
            census_bits[44] <= (r2_c1 < center_val) ? 1'b1 : 1'b0;
            census_bits[43] <= (r2_c2 < center_val) ? 1'b1 : 1'b0;
            census_bits[42] <= (r2_c3 < center_val) ? 1'b1 : 1'b0;
            census_bits[41] <= (r2_c4 < center_val) ? 1'b1 : 1'b0;
            census_bits[40] <= (r2_c5 < center_val) ? 1'b1 : 1'b0;
            census_bits[39] <= (r2_c6 < center_val) ? 1'b1 : 1'b0;
            census_bits[38] <= (r2_c7 < center_val) ? 1'b1 : 1'b0;
            census_bits[37] <= (r2_c8 < center_val) ? 1'b1 : 1'b0;
            census_bits[36] <= (r3_c0 < center_val) ? 1'b1 : 1'b0;
            census_bits[35] <= (r3_c1 < center_val) ? 1'b1 : 1'b0;
            census_bits[34] <= (r3_c2 < center_val) ? 1'b1 : 1'b0;
            census_bits[33] <= (r3_c3 < center_val) ? 1'b1 : 1'b0;
            census_bits[32] <= 1'b0;
            census_bits[31] <= (r3_c5 < center_val) ? 1'b1 : 1'b0;
            census_bits[30] <= (r3_c6 < center_val) ? 1'b1 : 1'b0;
            census_bits[29] <= (r3_c7 < center_val) ? 1'b1 : 1'b0;
            census_bits[28] <= (r3_c8 < center_val) ? 1'b1 : 1'b0;
            census_bits[27] <= (r4_c0 < center_val) ? 1'b1 : 1'b0;
            census_bits[26] <= (r4_c1 < center_val) ? 1'b1 : 1'b0;
            census_bits[25] <= (r4_c2 < center_val) ? 1'b1 : 1'b0;
            census_bits[24] <= (r4_c3 < center_val) ? 1'b1 : 1'b0;
            census_bits[23] <= (r4_c4 < center_val) ? 1'b1 : 1'b0;
            census_bits[22] <= (r4_c5 < center_val) ? 1'b1 : 1'b0;
            census_bits[21] <= (r4_c6 < center_val) ? 1'b1 : 1'b0;
            census_bits[20] <= (r4_c7 < center_val) ? 1'b1 : 1'b0;
            census_bits[19] <= (r4_c8 < center_val) ? 1'b1 : 1'b0;
            census_bits[18] <= (r5_c0 < center_val) ? 1'b1 : 1'b0;
            census_bits[17] <= (r5_c1 < center_val) ? 1'b1 : 1'b0;
            census_bits[16] <= (r5_c2 < center_val) ? 1'b1 : 1'b0;
            census_bits[15] <= (r5_c3 < center_val) ? 1'b1 : 1'b0;
            census_bits[14] <= (r5_c4 < center_val) ? 1'b1 : 1'b0;
            census_bits[13] <= (r5_c5 < center_val) ? 1'b1 : 1'b0;
            census_bits[12] <= (r5_c6 < center_val) ? 1'b1 : 1'b0;
            census_bits[11] <= (r5_c7 < center_val) ? 1'b1 : 1'b0;
            census_bits[10] <= (r5_c8 < center_val) ? 1'b1 : 1'b0;
            census_bits[9]  <= (r6_c0 < center_val) ? 1'b1 : 1'b0;
            census_bits[8]  <= (r6_c1 < center_val) ? 1'b1 : 1'b0;
            census_bits[7]  <= (r6_c2 < center_val) ? 1'b1 : 1'b0;
            census_bits[6]  <= (r6_c3 < center_val) ? 1'b1 : 1'b0;
            census_bits[5]  <= (r6_c4 < center_val) ? 1'b1 : 1'b0;
            census_bits[4]  <= (r6_c5 < center_val) ? 1'b1 : 1'b0;
            census_bits[3]  <= (r6_c6 < center_val) ? 1'b1 : 1'b0;
            census_bits[2]  <= (r6_c7 < center_val) ? 1'b1 : 1'b0;
            census_bits[1]  <= (r6_c8 < center_val) ? 1'b1 : 1'b0;
            census_bits[0] <= 1'b0;

            census_out <= census_bits;

            if ((center_row_s1 >= 3) && (center_col_s1 >= 4)) census_valid <= 1'b1;
            else census_valid <= 1'b0;
        end
    end

endmodule