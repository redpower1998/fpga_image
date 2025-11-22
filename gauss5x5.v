module gauss5x5 #(
    parameter IMAGE_WIDTH = 320
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        gray_valid,
    input  wire [7:0]  gray,
    output reg         gauss_valid,
    output reg [7:0]   gauss_out,
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

    reg signed [18:0] sum_acc;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            gauss_valid <= 1'b0;
            gauss_out <= 8'd0;
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
            gauss_valid <= 1'b0;
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
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            sum_acc <= 19'd0;
            gauss_out <= 8'd0;
            gauss_valid <= 1'b0;
        end else begin
            sum_acc = 0;
            sum_acc = sum_acc + r0_c0 * 1 + r0_c1 * 4 + r0_c2 * 6 + r0_c3 * 4 + r0_c4 * 1;
            sum_acc = sum_acc + r1_c0 * 4 + r1_c1 * 16 + r1_c2 * 24 + r1_c3 * 16 + r1_c4 * 4;
            sum_acc = sum_acc + r2_c0 * 6 + r2_c1 * 24 + r2_c2 * 36 + r2_c3 * 24 + r2_c4 * 6;
            sum_acc = sum_acc + r3_c0 * 4 + r3_c1 * 16 + r3_c2 * 24 + r3_c3 * 16 + r3_c4 * 4;
            sum_acc = sum_acc + r4_c0 * 1 + r4_c1 * 4 + r4_c2 * 6 + r4_c3 * 4 + r4_c4 * 1;

            gauss_out <= sum_acc[18:8];

            if ((center_row_s1 >= 2) && (center_col_s1 >= 2)) gauss_valid <= 1'b1;
            else gauss_valid <= 1'b0;
        end
    end

endmodule