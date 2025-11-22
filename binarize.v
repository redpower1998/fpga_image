module binarize #(
    parameter IMAGE_WIDTH = 320,
    parameter integer THRESH = 128
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        gray_valid,
    input  wire [7:0]  gray,
    output reg         bin_valid,
    output reg [7:0]   bin_out,
    output reg [31:0]  center_row_s1,
    output reg [31:0]  center_col_s1
);

    localparam integer COL_W = (IMAGE_WIDTH>1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [7:0] pix_r;
    reg       gray_valid_d;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= {COL_W{1'b0}};
            row_cnt <= 32'd0;
            pix_r <= 8'd0;
            gray_valid_d <= 1'b0;
            center_row_s1 <= 32'd0;
            center_col_s1 <= 32'd0;
        end else begin
            gray_valid_d <= 1'b0;
            if (gray_valid) begin
                pix_r <= gray;
                gray_valid_d <= 1'b1;

                center_row_s1 <= row_cnt;
                if (col_ptr == {COL_W{1'b0}}) center_col_s1 <= 32'd0;
                else center_col_s1 <= { { (32-COL_W){1'b0} }, (col_ptr - 1) };

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
            bin_valid <= 1'b0;
            bin_out <= 8'd0;
        end else begin
            if (gray_valid_d) begin
                bin_valid <= 1'b1;
                bin_out <= (pix_r >= THRESH) ? 8'd255 : 8'd0;
            end else begin
                bin_valid <= 1'b0;
            end
        end
    end

endmodule