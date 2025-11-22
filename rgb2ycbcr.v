module rgb2ycbcr (
    input wire clk,
    input wire rst_n,
    input wire data_valid,
    input wire [7:0] r_in,
    input wire [7:0] g_in,
    input wire [7:0] b_in,
    output reg data_out_valid,
    output reg [7:0] y_out,
    output reg [7:0] cb_out,
    output reg [7:0] cr_out
);

localparam COEF_Y_R  = 8'd77;
localparam COEF_Y_G  = 8'd150;
localparam COEF_Y_B  = 8'd29;

localparam COEF_CB_R = 8'd43;
localparam COEF_CB_G = 8'd85;
localparam COEF_CB_B = 8'd128;

localparam COEF_CR_R = 8'd128;
localparam COEF_CR_G = 8'd107;
localparam COEF_CR_B = 8'd21;

reg [15:0] r_mult_y, g_mult_y, b_mult_y;
reg [15:0] r_mult_cb, g_mult_cb, b_mult_cb;
reg [15:0] r_mult_cr, g_mult_cr, b_mult_cr;

reg [15:0] y_sum, cb_sum, cr_sum;
reg valid_p1, valid_p2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_mult_y  <= 16'd0;
        g_mult_y  <= 16'd0;
        b_mult_y  <= 16'd0;
        r_mult_cb <= 16'd0;
        g_mult_cb <= 16'd0;
        b_mult_cb <= 16'd0;
        r_mult_cr <= 16'd0;
        g_mult_cr <= 16'd0;
        b_mult_cr <= 16'd0;
        valid_p1  <= 1'b0;
    end else begin
        r_mult_y  <= r_in * COEF_Y_R;
        g_mult_y  <= g_in * COEF_Y_G;
        b_mult_y  <= b_in * COEF_Y_B;
        r_mult_cb <= r_in * COEF_CB_R;
        g_mult_cb <= g_in * COEF_CB_G;
        b_mult_cb <= b_in * COEF_CB_B;
        r_mult_cr <= r_in * COEF_CR_R;
        g_mult_cr <= g_in * COEF_CR_G;
        b_mult_cr <= b_in * COEF_CR_B;
        valid_p1 <= data_valid;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_sum  <= 16'd0;
        cb_sum <= 16'd0;
        cr_sum <= 16'd0;
        valid_p2 <= 1'b0;
    end else begin
        y_sum <= r_mult_y + g_mult_y + b_mult_y;
        cb_sum <= 16'd32768 + (b_mult_cb - r_mult_cb - g_mult_cb);
        cr_sum <= 16'd32768 + (r_mult_cr - g_mult_cr - b_mult_cr);
        valid_p2 <= valid_p1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_out  <= 8'd0;
        cb_out <= 8'd0;
        cr_out <= 8'd0;
        data_out_valid <= 1'b0;
    end else begin
        y_out <= y_sum[15:8];
        if (cb_sum[15:8] > 8'd255) begin
            cb_out <= 8'd255;
        end else if (cb_sum[15:8] < 8'd0) begin
            cb_out <= 8'd0;
        end else begin
            cb_out <= cb_sum[15:8];
        end
        if (cr_sum[15:8] > 8'd255) begin
            cr_out <= 8'd255;
        end else if (cr_sum[15:8] < 8'd0) begin
            cr_out <= 8'd0;
        end else begin
            cr_out <= cr_sum[15:8];
        end
        data_out_valid <= valid_p2;
    end
end

endmodule