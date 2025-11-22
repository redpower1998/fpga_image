module mean3x3 #(
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

    reg [7:0] r0_c0, r0_c1, r0_c2;
    reg [7:0] r1_c0, r1_c1, r1_c2;
    reg [7:0] r2_c0, r2_c1, r2_c2;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    reg [7:0] t0, t1;

    reg [7:0] arr [0:8];
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
            r0_c0 <= 8'd0; r0_c1 <= 8'd0; r0_c2 <= 8'd0;
            r1_c0 <= 8'd0; r1_c1 <= 8'd0; r1_c2 <= 8'd0;
            r2_c0 <= 8'd0; r2_c1 <= 8'd0; r2_c2 <= 8'd0;
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                linebuf0[i] <= 8'd0;
                linebuf1[i] <= 8'd0;
            end
        end else begin
            mean_valid <= 1'b0;
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

    always @(posedge clk) begin
        if (rst) begin
            mean_out <= 8'd0;
            mean_valid <= 1'b0;
            for (i = 0; i < 9; i = i + 1) begin
                arr[i] <= 8'd0;
            end
        end else begin
            arr[0] <= r0_c0; arr[1] <= r0_c1; arr[2] <= r0_c2;
            arr[3] <= r1_c0; arr[4] <= r1_c1; arr[5] <= r1_c2;
            arr[6] <= r2_c0; arr[7] <= r2_c1; arr[8] <= r2_c2;

            sum = 0;
            for (i = 0; i < 9; i = i + 1) begin
                sum = sum + arr[i];
            end

            mean_out <= sum / 9;

            if ((center_row_s1 >= 1) && (center_col_s1 >= 1)) mean_valid <= 1'b1;
            else mean_valid <= 1'b0;
        end
    end

endmodule