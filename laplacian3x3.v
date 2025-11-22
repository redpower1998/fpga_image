module laplacian3x3 #(
    parameter IMAGE_WIDTH = 320
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        gray_valid,
    input  wire [7:0]  gray,
    output reg         lap_valid,
    output reg [7:0]   lap_out,
    output reg [31:0]  center_row_s1,
    output reg [31:0]  center_col_s1
);

    localparam integer COL_W = (IMAGE_WIDTH>1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [7:0] linebuf0 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf1 [0:IMAGE_WIDTH-1];

    reg [7:0] r0_c0, r0_c1, r0_c2;
    reg [7:0] r1_c0, r1_c1, r1_c2;
    reg [7:0] r2_c0, r2_c1, r2_c2;

    reg [7:0] t0, t1;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            lap_valid <= 1'b0;
            lap_out <= 8'd0;
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
            lap_valid <= 1'b0;
            if (gray_valid) begin
                t0 <= linebuf0[col_ptr];
                t1 <= linebuf1[col_ptr];

                r0_c0 <= r0_c1; r0_c1 <= r0_c2; r0_c2 <= t1;
                r1_c0 <= r1_c1; r1_c1 <= r1_c2; r1_c2 <= t0;
                r2_c0 <= r2_c1; r2_c1 <= r2_c2; r2_c2 <= gray;

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

    reg signed [13:0] lap_acc;
    integer signed_tmp;

    always @(posedge clk) begin
        if (rst) begin
            lap_acc <= 14'sd0;
            lap_out <= 8'd0;
            lap_valid <= 1'b0;
        end else begin
            lap_acc = - $signed({1'b0,r0_c0}) - $signed({1'b0,r0_c1}) - $signed({1'b0,r0_c2})
                      - $signed({1'b0,r1_c0}) + ( $signed({1'b0,r1_c1}) << 3 ) - $signed({1'b0,r1_c2})
                      - $signed({1'b0,r2_c0}) - $signed({1'b0,r2_c1}) - $signed({1'b0,r2_c2});

            signed_tmp = $signed(lap_acc) + 128;
            if (signed_tmp < 0) lap_out <= 8'd0;
            else if (signed_tmp > 255) lap_out <= 8'd255;
            else lap_out <= signed_tmp[7:0];

            if ((center_row_s1 >= 1) && (center_col_s1 >= 1)) lap_valid <= 1'b1;
            else lap_valid <= 1'b0;
        end
    end

endmodule