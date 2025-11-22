module gray_weighted_merger (
    input wire clk,
    input wire rst_n,
    input wire [7:0] gray1_in,
    input wire data1_valid,
    input wire [7:0] gray2_in,
    input wire data2_valid,
    input wire [7:0] weight1,
    input wire [7:0] weight2,
    output reg [7:0] gray_out,
    output reg data_out_valid
);

localparam IDLE = 1'b0;
localparam PROCESS = 1'b1;

reg state;
reg [7:0] gray1_reg, gray2_reg;
reg [7:0] weight1_reg, weight2_reg;

wire [15:0] gray1_weighted, gray2_weighted;
wire [15:0] gray_sum;
wire [15:0] total_weight;

assign gray1_weighted = gray1_reg * weight1_reg;
assign gray2_weighted = gray2_reg * weight2_reg;
assign gray_sum = gray1_weighted + gray2_weighted;
assign total_weight = weight1_reg + weight2_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        gray1_reg <= 8'b0;
        gray2_reg <= 8'b0;
        weight1_reg <= 8'b0;
        weight2_reg <= 8'b0;
        gray_out <= 8'b0;
        data_out_valid <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                data_out_valid <= 1'b0;
                if (data1_valid && data2_valid) begin
                    gray1_reg <= gray1_in;
                    gray2_reg <= gray2_in;
                    weight1_reg <= weight1;
                    weight2_reg <= weight2;
                    state <= PROCESS;
                end
            end
            
            PROCESS: begin
                if (total_weight > 0) begin
                    gray_out <= gray_sum / total_weight;
                end else begin
                    gray_out <= 8'b0;
                end
                data_out_valid <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule