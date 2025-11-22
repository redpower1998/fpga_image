module rgb_brightness (
    input wire clk,
    input wire rst_n,
    input wire [7:0] r_in,
    input wire [7:0] g_in,
    input wire [7:0] b_in,
    input wire data_valid,
    input wire [7:0] brightness_level,
    input wire brightness_enable,
    output reg [7:0] r_out,
    output reg [7:0] g_out,
    output reg [7:0] b_out,
    output reg data_out_valid
);

localparam IDLE = 1'b0;
localparam PROCESS = 1'b1;

reg state;
reg [7:0] r_reg, g_reg, b_reg;
reg [7:0] brightness_reg;
reg enable_reg;

function [7:0] apply_brightness;
    input [7:0] channel;
    input [7:0] brightness;
    input enable;
    
    reg [7:0] result;
    reg [15:0] temp;
    
    begin
        if (!enable) begin
            result = channel;
        end else begin
            if (brightness > 128) begin
                temp = channel + ((brightness - 128) * 2);
                if (temp > 255) begin
                    result = 8'hFF;
                end else begin
                    result = temp[7:0];
                end
            end else if (brightness < 128) begin
                if (channel < (128 - brightness)) begin
                    result = 8'h00;
                end else begin
                    result = channel - (128 - brightness);
                end
            end else begin
                result = channel;
            end
        end
        
        apply_brightness = result;
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        r_reg <= 8'h00;
        g_reg <= 8'h00;
        b_reg <= 8'h00;
        brightness_reg <= 8'h80;
        enable_reg <= 1'b0;
        r_out <= 8'h00;
        g_out <= 8'h00;
        b_out <= 8'h00;
        data_out_valid <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                data_out_valid <= 1'b0;
                if (data_valid) begin
                    r_reg <= r_in;
                    g_reg <= g_in;
                    b_reg <= b_in;
                    brightness_reg <= brightness_level;
                    enable_reg <= brightness_enable;
                    state <= PROCESS;
                end
            end
            
            PROCESS: begin
                r_out <= apply_brightness(r_reg, brightness_reg, enable_reg);
                g_out <= apply_brightness(g_reg, brightness_reg, enable_reg);
                b_out <= apply_brightness(b_reg, brightness_reg, enable_reg);
                data_out_valid <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule