module rgb2gray_high_perf (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         data_valid,
    input  wire [7:0]   r,
    input  wire [7:0]   g,
    input  wire [7:0]   b,
    output reg          gray_valid,
    output reg  [7:0]   gray
);

localparam COEF_R = 8'd76;
localparam COEF_G = 8'd150;
localparam COEF_B = 8'd29;

reg [15:0] r_mult_reg, g_mult_reg, b_mult_reg;
reg        valid_p1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_mult_reg <= 16'd0;
        g_mult_reg <= 16'd0;
        b_mult_reg <= 16'd0;
        valid_p1   <= 1'b0;
    end else begin
        r_mult_reg <= r * COEF_R;
        g_mult_reg <= g * COEF_G;
        b_mult_reg <= b * COEF_B;
        valid_p1   <= data_valid;
    end
end

reg [16:0] sum_rg_reg;
reg [15:0] b_mult_p2;
reg        valid_p2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum_rg_reg <= 17'd0;
        b_mult_p2  <= 16'd0;
        valid_p2   <= 1'b0;
    end else begin
        sum_rg_reg <= r_mult_reg + g_mult_reg;
        b_mult_p2  <= b_mult_reg;
        valid_p2   <= valid_p1;
    end
end

reg [17:0] sum_total_reg;
reg        valid_p3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum_total_reg <= 18'd0;
        valid_p3      <= 1'b0;
    end else begin
        sum_total_reg <= sum_rg_reg + b_mult_p2;
        valid_p3      <= valid_p2;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gray       <= 8'd0;
        gray_valid <= 1'b0;
    end else begin
        gray       <= sum_total_reg[15:8];
        gray_valid <= valid_p3;
    end
end

endmodule