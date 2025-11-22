module rgb_extractor (
    input wire clk,
    input wire rst_n,
    input wire [7:0] r_in,
    input wire [7:0] g_in,
    input wire [7:0] b_in,
    input wire data_valid,
    input wire [1:0] channel_select,
    output reg [7:0] channel_out,
    output reg data_out_valid
);

localparam IDLE = 1'b0;
localparam PROCESS = 1'b1;

reg state;
reg [7:0] r_reg, g_reg, b_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        r_reg <= 8'b0;
        g_reg <= 8'b0;
        b_reg <= 8'b0;
        channel_out <= 8'b0;
        data_out_valid <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                data_out_valid <= 1'b0;
                if (data_valid) begin
                    r_reg <= r_in;
                    g_reg <= g_in;
                    b_reg <= b_in;
                    state <= PROCESS;
                end
            end
            
            PROCESS: begin
                case (channel_select)
                    2'b00: channel_out <= r_reg;
                    2'b01: channel_out <= g_reg;
                    2'b10: channel_out <= b_reg;
                    default: channel_out <= 8'b0;
                endcase
                data_out_valid <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule