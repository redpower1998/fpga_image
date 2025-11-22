module sobel_basic #(
    parameter IMAGE_WIDTH = 320
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        pixel_in_valid,
    input  wire [7:0]  pixel_in,
    output reg         pixel_out_valid,
    output reg  [7:0]  pixel_out
);

    localparam integer COL_W = (IMAGE_WIDTH>1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [7:0] linebuf0 [0:IMAGE_WIDTH-1];
    reg [7:0] linebuf1 [0:IMAGE_WIDTH-1];

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    reg [7:0] top_l, top_c, top_r;
    reg [7:0] mid_l, mid_c, mid_r;
    reg [7:0] bot_l, bot_c, bot_r;

    reg [7:0] top_read;
    reg [7:0] mid_read;

    reg [COL_W-1:0] center_col_s1;
    reg [31:0]     center_row_s1;

    reg signed [12:0] s_tl, s_tc, s_tr;
    reg signed [12:0] s_ml, s_mc, s_mr;
    reg signed [12:0] s_bl, s_bc, s_br;
    reg signed [14:0] gx;
    reg signed [14:0] gy;
    reg [15:0] abs_sum;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= 0;
            row_cnt <= 0;
            pixel_out_valid <= 1'b0;
            pixel_out <= 8'd0;
            top_l <= 8'd0; top_c <= 8'd0; top_r <= 8'd0;
            mid_l <= 8'd0; mid_c <= 8'd0; mid_r <= 8'd0;
            bot_l <= 8'd0; bot_c <= 8'd0; bot_r <= 8'd0;
            center_col_s1 <= 0;
            center_row_s1 <= 0;
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                linebuf0[i] <= 8'd0;
                linebuf1[i] <= 8'd0;
            end
        end else begin
            pixel_out_valid <= 1'b0;

            if (pixel_in_valid) begin
                top_read <= linebuf1[col_ptr];
                mid_read <= linebuf0[col_ptr];

                top_l <= top_c; top_c <= top_r; top_r <= top_read;
                mid_l <= mid_c; mid_c <= mid_r; mid_r <= mid_read;
                bot_l <= bot_c; bot_c <= bot_r; bot_r <= pixel_in;

                linebuf1[col_ptr] <= mid_read;
                linebuf0[col_ptr] <= pixel_in;

                if (col_ptr == 0) begin
                    center_col_s1 <= {COL_W{1'b0}};
                end else begin
                    center_col_s1 <= col_ptr - 1;
                end
                center_row_s1 <= row_cnt;

                if (col_ptr == IMAGE_WIDTH - 1) begin
                    col_ptr <= 0;
                    row_cnt <= row_cnt + 1;
                end else begin
                    col_ptr <= col_ptr + 1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            s_tl <= 0; s_tc <= 0; s_tr <= 0;
            s_ml <= 0; s_mc <= 0; s_mr <= 0;
            s_bl <= 0; s_bc <= 0; s_br <= 0;
            gx <= 0; gy <= 0; abs_sum <= 0;
            pixel_out <= 8'd0;
            pixel_out_valid <= 1'b0;
        end else begin
            s_tl <= {5'b0, top_l};
            s_tc <= {5'b0, top_c};
            s_tr <= {5'b0, top_r};
            s_ml <= {5'b0, mid_l};
            s_mc <= {5'b0, mid_c};
            s_mr <= {5'b0, mid_r};
            s_bl <= {5'b0, bot_l};
            s_bc <= {5'b0, bot_c};
            s_br <= {5'b0, bot_r};

            gx <= (-s_tl) + s_tr + ((-s_ml) <<< 1) + ((s_mr) <<< 1) + (-s_bl) + s_br;
            gy <= (-s_tl) + ((-s_tc) <<< 1) + (-s_tr) + s_bl + ((s_bc) <<< 1) + s_br;

            abs_sum <= (gx[14] ? -gx : gx) + (gy[14] ? -gy : gy);

            if ((center_row_s1 >= 2) && (center_col_s1 >= 2)) begin
                if (abs_sum > 16'd255) pixel_out <= 8'd255;
                else pixel_out <= abs_sum[7:0];
                pixel_out_valid <= 1'b1;
            end else begin
                pixel_out <= 8'd0;
                pixel_out_valid <= 1'b0;
            end
        end
    end

endmodule