module gray_brightness (
    input wire clk,
    input wire rst_n,
    input wire [7:0] gray_in,
    input wire data_valid,
    input wire [7:0] brightness_level,
    input wire brightness_enable,
    output reg [7:0] gray_out,
    output reg data_out_valid
);

localparam IDLE = 1'b0;
localparam PROCESS = 1'b1;

reg state;
reg [7:0] gray_reg;
reg [7:0] brightness_reg;
reg enable_reg;

function [7:0] apply_brightness;
    input [7:0] gray;
    input [7:0] brightness;
    input enable;
    
    reg [7:0] result;
    reg [15:0] temp;
    
    begin
        if (!enable) begin
            result = gray;
        end else begin
            if (brightness > 128) begin
                temp = gray + ((brightness - 128) * 2);
                if (temp > 255) begin
                    result = 8'hFF;
                end else begin
                    result = temp[7:0];
                end
            end else if (brightness < 128) begin
                if (gray < (128 - brightness)) begin
                    result = 8'h00;
                end else begin
                    result = gray - (128 - brightness);
                end
            end else begin
                result = gray;
            end
        end
        
        apply_brightness = result;
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        gray_reg <= 8'h00;
        brightness_reg <= 8'h80;
        enable_reg <= 1'b0;
        gray_out <= 8'h00;
        data_out_valid <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                data_out_valid <= 1'b0;
                if (data_valid) begin
                    gray_reg <= gray_in;
                    brightness_reg <= brightness_level;
                    enable_reg <= brightness_enable;
                    state <= PROCESS;
                end
            end
            
            PROCESS: begin
                gray_out <= apply_brightness(gray_reg, brightness_reg, enable_reg);
                data_out_valid <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule