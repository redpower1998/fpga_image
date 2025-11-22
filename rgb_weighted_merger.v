module rgb_weighted_merger (
    input wire clk,
    input wire rst_n,
    input wire [7:0] r1_in,
    input wire [7:0] g1_in,
    input wire [7:0] b1_in,
    input wire data1_valid,
    input wire [7:0] r2_in,
    input wire [7:0] g2_in,
    input wire [7:0] b2_in,
    input wire data2_valid,
    input wire [7:0] weight1,
    input wire [7:0] weight2,
    output reg [7:0] r_out,
    output reg [7:0] g_out,
    output reg [7:0] b_out,
    output reg data_out_valid
);

localparam IDLE = 1'b0;
localparam PROCESS = 1'b1;

reg state;
reg [7:0] r1_reg, g1_reg, b1_reg;
reg [7:0] r2_reg, g2_reg, b2_reg;
reg [7:0] weight1_reg, weight2_reg;

wire [15:0] r1_weighted, g1_weighted, b1_weighted;
wire [15:0] r2_weighted, g2_weighted, b2_weighted;
wire [15:0] r_sum, g_sum, b_sum;
wire [15:0] total_weight;

assign r1_weighted = r1_reg * weight1_reg;
assign g1_weighted = g1_reg * weight1_reg;
assign b1_weighted = b1_reg * weight1_reg;

assign r2_weighted = r2_reg * weight2_reg;
assign g2_weighted = g2_reg * weight2_reg;
assign b2_weighted = b2_reg * weight2_reg;

assign r_sum = r1_weighted + r2_weighted;
assign g_sum = g1_weighted + g2_weighted;
assign b_sum = b1_weighted + b2_weighted;

assign total_weight = weight1_reg + weight2_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        r1_reg <= 8'b0;
        g1_reg <= 8'b0;
        b1_reg <= 8'b0;
        r2_reg <= 8'b0;
        g2_reg <= 8'b0;
        b2_reg <= 8'b0;
        weight1_reg <= 8'b0;
        weight2_reg <= 8'b0;
        r_out <= 8'b0;
        g_out <= 8'b0;
        b_out <= 8'b0;
        data_out_valid <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                data_out_valid <= 1'b0;
                if (data1_valid && data2_valid) begin
                    r1_reg <= r1_in;
                    g1_reg <= g1_in;
                    b1_reg <= b1_in;
                    r2_reg <= r2_in;
                    g2_reg <= g2_in;
                    b2_reg <= b2_in;
                    weight1_reg <= weight1;
                    weight2_reg <= weight2;
                    state <= PROCESS;
                end
            end
            
            PROCESS: begin
                if (total_weight > 0) begin
                    r_out <= r_sum / total_weight;
                    g_out <= g_sum / total_weight;
                    b_out <= b_sum / total_weight;
                end else begin
                    r_out <= 8'b0;
                    g_out <= 8'b0;
                    b_out <= 8'b0;
                end
                data_out_valid <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule