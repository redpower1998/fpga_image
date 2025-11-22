module rgb2gray (
    input wire         clk,
    input wire         rst_n,
    input wire         data_valid,
    input wire [7:0]   r,
    input wire [7:0]   g,
    input wire [7:0]   b,
    output reg         gray_valid,
    output reg [7:0]   gray
);

localparam COEF_R = 8'd76;
localparam COEF_G = 8'd150;
localparam COEF_B = 8'd29;

wire [15:0] r_mult, g_mult, b_mult;
wire [17:0] sum;

assign r_mult = r * COEF_R;
assign g_mult = g * COEF_G;
assign b_mult = b * COEF_B;

assign sum = r_mult + g_mult + b_mult;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gray <= 8'd0;
        gray_valid <= 1'b0;
    end else begin
        gray <= sum[15:8];
        gray_valid <= data_valid;
    end
end

endmodule