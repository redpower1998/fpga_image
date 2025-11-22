module gauss9x9 #(
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

    reg [15:0] linebuf0 [0:IMAGE_WIDTH-1];
    reg [15:0] linebuf1 [0:IMAGE_WIDTH-1];
    reg [15:0] linebuf2 [0:IMAGE_WIDTH-1];
    reg [15:0] linebuf3 [0:IMAGE_WIDTH-1];
    reg [15:0] linebuf4 [0:IMAGE_WIDTH-1];
    reg [15:0] linebuf5 [0:IMAGE_WIDTH-1];
    reg [15:0] linebuf6 [0:IMAGE_WIDTH-1];
    reg [15:0] linebuf7 [0:IMAGE_WIDTH-1];

    reg [7:0] h0, h1, h2, h3, h4, h5, h6, h7, h8;

    reg [15:0] r0, r1, r2, r3, r4, r5, r6, r7, r8;

    reg [15:0] t0, t1, t2, t3, t4, t5, t6, t7;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    localparam integer C0 = 1;
    localparam integer C1 = 8;
    localparam integer C2 = 28;
    localparam integer C3 = 56;
    localparam integer C4 = 70;
    localparam integer C5 = 56;
    localparam integer C6 = 28;
    localparam integer C7 = 8;
    localparam integer C8 = 1;

    reg [23:0] sum_v;

    integer i;

    reg [15:0] sum_h;
    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            gauss_valid <= 1'b0;
            gauss_out <= 8'd0;
            center_row_s1 <= 32'd0;
            center_col_s1 <= 32'd0;
            h0 <= 0; h1 <= 0; h2 <= 0; h3 <= 0; h4 <= 0; h5 <= 0; h6 <= 0; h7 <= 0; h8 <= 0;
            r0 <= 0; r1 <= 0; r2 <= 0; r3 <= 0; r4 <= 0; r5 <= 0; r6 <= 0; r7 <= 0; r8 <= 0;
            sum_h <= 16'd0;
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                linebuf0[i] <= 16'd0;
                linebuf1[i] <= 16'd0;
                linebuf2[i] <= 16'd0;
                linebuf3[i] <= 16'd0;
                linebuf4[i] <= 16'd0;
                linebuf5[i] <= 16'd0;
                linebuf6[i] <= 16'd0;
                linebuf7[i] <= 16'd0;
            end
        end else begin
            gauss_valid <= 1'b0;
            if (gray_valid) begin
                h0 = h1; h1 = h2; h2 = h3; h3 = h4; h4 = h5; h5 = h6; h6 = h7; h7 = h8; h8 = gray;

                sum_h = 0;
                sum_h = sum_h + C0 * h0 + C1 * h1 + C2 * h2 + C3 * h3 + C4 * h4 + C5 * h5 + C6 * h6 + C7 * h7 + C8 * h8;

                t0 <= linebuf0[col_ptr];
                t1 <= linebuf1[col_ptr];
                t2 <= linebuf2[col_ptr];
                t3 <= linebuf3[col_ptr];
                t4 <= linebuf4[col_ptr];
                t5 <= linebuf5[col_ptr];
                t6 <= linebuf6[col_ptr];
                t7 <= linebuf7[col_ptr];

                r0 <= r1; r1 <= r2; r2 <= r3; r3 <= r4; r4 <= r5; r5 <= r6; r6 <= r7; r7 <= r8; r8 <= sum_h;

                linebuf7[col_ptr] <= linebuf6[col_ptr];
                linebuf6[col_ptr] <= linebuf5[col_ptr];
                linebuf5[col_ptr] <= linebuf4[col_ptr];
                linebuf4[col_ptr] <= linebuf3[col_ptr];
                linebuf3[col_ptr] <= linebuf2[col_ptr];
                linebuf2[col_ptr] <= linebuf1[col_ptr];
                linebuf1[col_ptr] <= linebuf0[col_ptr];
                linebuf0[col_ptr] <= sum_h;

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
            sum_v <= 24'd0;
            gauss_out <= 8'd0;
            gauss_valid <= 1'b0;
        end else begin
            sum_v = 0;
            sum_v = sum_v + C0 * r0 + C1 * r1 + C2 * r2 + C3 * r3 + C4 * r4 + C5 * r5 + C6 * r6 + C7 * r7 + C8 * r8;

            gauss_out <= sum_v[23:16];

            if ((center_row_s1 >= 4) && (center_col_s1 >= 4)) gauss_valid <= 1'b1;
            else gauss_valid <= 1'b0;
        end
    end

endmodule