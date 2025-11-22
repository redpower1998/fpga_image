module census3x3 #(
    parameter IMAGE_WIDTH = 320
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        gray_valid,
    input  wire [7:0]  gray,
    output reg         census_valid,
    output reg [15:0]  census_out
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

    reg [7:0] census8;
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= 0;
            row_cnt <= 0;
            census_valid <= 1'b0;
            census_out <= 16'd0;
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
            census_valid <= 1'b0;

            if (gray_valid) begin
                top_read <= linebuf1[col_ptr];
                mid_read <= linebuf0[col_ptr];

                top_l <= top_c; top_c <= top_r; top_r <= top_read;
                mid_l <= mid_c; mid_c <= mid_r; mid_r <= mid_read;
                bot_l <= bot_c; bot_c <= bot_r; bot_r <= gray;

                linebuf1[col_ptr] <= mid_read;
                linebuf0[col_ptr] <= gray;

                if (col_ptr == 0) center_col_s1 <= {COL_W{1'b0}};
                else center_col_s1 <= col_ptr - 1;
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
            census_out <= 16'd0;
            census_valid <= 1'b0;
        end else begin
            census8[7] <= (top_l < mid_c) ? 1'b1 : 1'b0;
            census8[6] <= (top_c < mid_c) ? 1'b1 : 1'b0;
            census8[5] <= (top_r < mid_c) ? 1'b1 : 1'b0;
            census8[4] <= (mid_l < mid_c) ? 1'b1 : 1'b0;
            census8[3] <= (mid_r < mid_c) ? 1'b1 : 1'b0;
            census8[2] <= (bot_l < mid_c) ? 1'b1 : 1'b0;
            census8[1] <= (bot_c < mid_c) ? 1'b1 : 1'b0;
            census8[0] <= (bot_r < mid_c) ? 1'b1 : 1'b0;

            census_out <= {census8, census8};

            if ((center_row_s1 >= 2) && (center_col_s1 >= 2)) census_valid <= 1'b1;
            else census_valid <= 1'b0;
        end
    end

endmodule