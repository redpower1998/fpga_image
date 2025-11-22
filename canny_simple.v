module canny_simple #(
    parameter IMAGE_WIDTH = 320,
    parameter integer LOW_THRESH  = 40,
    parameter integer HIGH_THRESH = 80
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        gray_valid,
    input  wire [7:0]  gray,
    output reg         canny_valid,
    output reg [7:0]   canny_out,
    output reg [31:0]  center_row_s2,
    output reg [31:0]  center_col_s2
);

    localparam integer COL_W = (IMAGE_WIDTH>1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [7:0] linebuf0 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf1 [0:IMAGE_WIDTH-1];

    reg [7:0] r0_c0, r0_c1, r0_c2;
    reg [7:0] r1_c0, r1_c1, r1_c2;
    reg [7:0] r2_c0, r2_c1, r2_c2;

    reg strong_lb0 [0:IMAGE_WIDTH-1];
    reg strong_lb1 [0:IMAGE_WIDTH-1];

    reg s0_c0, s0_c1, s0_c2;
    reg s1_c0, s1_c1, s1_c2;
    reg s2_c0, s2_c1, s2_c2;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    reg [COL_W-1:0] col_idx_s1;
    reg [COL_W-1:0] col_idx_s2;
    reg [31:0] center_row_s1;
    reg [31:0] center_col_s1;

    reg [7:0] t0, t1;
    reg t_s0, t_s1;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            r0_c0 <= 8'd0; r0_c1 <= 8'd0; r0_c2 <= 8'd0;
            r1_c0 <= 8'd0; r1_c1 <= 8'd0; r1_c2 <= 8'd0;
            r2_c0 <= 8'd0; r2_c1 <= 8'd0; r2_c2 <= 8'd0;
            center_row_s1 <= 32'd0;
            center_col_s1 <= 32'd0;
            col_idx_s1 <= {COL_W{1'b0}};
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                linebuf0[i] <= 8'd0;
                linebuf1[i] <= 8'd0;
                strong_lb0[i] <= 1'b0;
                strong_lb1[i] <= 1'b0;
            end
        end else begin
            if (gray_valid) begin
                t0 <= linebuf0[col_ptr];
                t1 <= linebuf1[col_ptr];

                r0_c0 <= r0_c1; r0_c1 <= r0_c2; r0_c2 <= t1;
                r1_c0 <= r1_c1; r1_c1 <= r1_c2; r1_c2 <= t0;
                r2_c0 <= r2_c1; r2_c1 <= r2_c2; r2_c2 <= gray;

                linebuf1[col_ptr] <= linebuf0[col_ptr];
                linebuf0[col_ptr] <= gray;

                if (col_ptr == {COL_W{1'b0}}) begin
                    center_col_s1 <= 32'd0;
                end else begin
                    center_col_s1 <= { { (32-COL_W){1'b0} }, (col_ptr - 1) };
                end
                center_row_s1 <= row_cnt;

                if (col_ptr == {COL_W{1'b0}}) col_idx_s1 <= {COL_W{1'b0}};
                else col_idx_s1 <= col_ptr - 1;

                if (col_ptr == IMAGE_WIDTH - 1) begin
                    col_ptr <= {COL_W{1'b0}};
                    row_cnt <= row_cnt + 1;
                end else begin
                    col_ptr <= col_ptr + 1;
                end
            end
        end
    end

    reg signed [11:0] gx_s;
    reg signed [11:0] gy_s;
    reg [11:0] abs_gx;
    reg [11:0] abs_gy;
    reg [11:0] mag;
    reg strong;
    reg weak;

    always @(posedge clk) begin
        if (rst) begin
            gx_s <= 12'sd0; gy_s <= 12'sd0;
            mag <= 12'd0;
            strong <= 1'b0; weak <= 1'b0;
            s0_c0 <= 1'b0; s0_c1 <= 1'b0; s0_c2 <= 1'b0;
            s1_c0 <= 1'b0; s1_c1 <= 1'b0; s1_c2 <= 1'b0;
            s2_c0 <= 1'b0; s2_c1 <= 1'b0; s2_c2 <= 1'b0;
            center_row_s2 <= 32'd0;
            center_col_s2 <= 32'd0;
            col_idx_s2 <= {COL_W{1'b0}};
        end else begin
            gx_s <= - $signed({4'd0,r0_c0}) + $signed({4'd0,r0_c2})
                    - ($signed({4'd0,r1_c0}) << 1) + ($signed({4'd0,r1_c2}) << 1)
                    - $signed({4'd0,r2_c0}) + $signed({4'd0,r2_c2});

            gy_s <= - $signed({4'd0,r0_c0}) - ($signed({4'd0,r0_c1}) << 1) - $signed({4'd0,r0_c2})
                    + $signed({4'd0,r2_c0}) + ($signed({4'd0,r2_c1}) << 1) + $signed({4'd0,r2_c2});

            abs_gx <= (gx_s[11]) ? -gx_s : gx_s;
            abs_gy <= (gy_s[11]) ? -gy_s : gy_s;

            mag <= (abs_gx + abs_gy) >> 1;

            if ( ( (abs_gx + abs_gy) >> 1 ) >= HIGH_THRESH ) begin
                strong <= 1'b1;
                weak   <= 1'b0;
            end else if ( ( (abs_gx + abs_gy) >> 1 ) >= LOW_THRESH ) begin
                strong <= 1'b0;
                weak   <= 1'b1;
            end else begin
                strong <= 1'b0;
                weak   <= 1'b0;
            end

            t_s0 <= strong_lb0[col_idx_s1];
            t_s1 <= strong_lb1[col_idx_s1];

            s0_c0 <= s0_c1; s0_c1 <= s0_c2; s0_c2 <= t_s1;
            s1_c0 <= s1_c1; s1_c1 <= s1_c2; s1_c2 <= t_s0;
            s2_c0 <= s2_c1; s2_c1 <= s2_c2; s2_c2 <= strong;

            strong_lb1[col_idx_s1] <= strong_lb0[col_idx_s1];
            strong_lb0[col_idx_s1] <= strong;

            center_row_s2 <= center_row_s1;
            center_col_s2 <= center_col_s1;
            col_idx_s2 <= col_idx_s1;
        end
    end

    reg center_strong_s1;
    reg center_weak_s1;
    reg [11:0] mag_s1;

    reg prev_stage1_valid;
    always @(posedge clk) begin
        if (rst) begin
            prev_stage1_valid <= 1'b0;
            mag_s1 <= 12'd0;
            center_strong_s1 <= 1'b0;
            center_weak_s1 <= 1'b0;
        end else begin
            mag_s1 <= mag;
            center_strong_s1 <= strong;
            center_weak_s1 <= weak;
            prev_stage1_valid <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            canny_valid <= 1'b0;
            canny_out <= 8'd0;
        end else begin
            if ((center_row_s2 >= 1) && (center_col_s2 >= 1)) begin
                if (center_strong_s1) begin
                    canny_out <= 8'd255;
                end else if (center_weak_s1) begin
                    if ( s0_c0 | s0_c1 | s0_c2 |
                         s1_c0 |        s1_c2 |
                         s2_c0 | s2_c1 | s2_c2 ) begin
                        canny_out <= 8'd255;
                    end else begin
                        canny_out <= 8'd0;
                    end
                end else begin
                    canny_out <= 8'd0;
                end
                canny_valid <= 1'b1;
            end else begin
                canny_valid <= 1'b0;
            end
        end
    end

endmodule