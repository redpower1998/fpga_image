module gray_to_color (
    input wire clk,
    input wire rst_n,
    input wire [7:0] gray_in,
    input wire data_valid,
    input wire [2:0] colormap_sel,
    output reg [7:0] r_out,
    output reg [7:0] g_out,
    output reg [7:0] b_out,
    output reg data_out_valid
);

localparam IDLE = 1'b0;
localparam PROCESS = 1'b1;

reg state;
reg [7:0] gray_reg;
reg [2:0] colormap_reg;

function [23:0] apply_colormap;
    input [7:0] gray;
    input [2:0] sel;
    reg [7:0] r, g, b;
    reg [7:0] normalized_gray;
    reg [7:0] phase;
    reg [7:0] hue;
    reg [7:0] h, s, v;
    begin
        normalized_gray = gray;
        
        case (sel)
            3'b000: begin
                if (gray < 64) begin
                    r = 0;
                    g = 0;
                    b = gray * 4;
                end else if (gray < 128) begin
                    r = 0;
                    g = (gray - 64) * 4;
                    b = 255;
                end else if (gray < 192) begin
                    r = (gray - 128) * 4;
                    g = 255;
                    b = 255 - (gray - 128) * 4;
                end else begin
                    r = 255;
                    g = 255 - (gray - 192) * 4;
                    b = 0;
                end
            end
            
            3'b001: begin
                hue = gray;
                
                if (hue < 43) begin
                    r = 255;
                    g = hue * 6;
                    b = 0;
                end else if (hue < 85) begin
                    r = 255 - (hue - 43) * 6;
                    g = 255;
                    b = 0;
                end else if (hue < 128) begin
                    r = 0;
                    g = 255;
                    b = (hue - 85) * 6;
                end else if (hue < 170) begin
                    r = 0;
                    g = 255 - (hue - 128) * 6;
                    b = 255;
                end else if (hue < 213) begin
                    r = (hue - 170) * 6;
                    g = 0;
                    b = 255;
                end else begin
                    r = 255;
                    g = 0;
                    b = 255 - (hue - 213) * 6;
                end
            end
            
            3'b010: begin
                if (gray < 37) begin
                    r = 255;
                    g = 0;
                    b = 0;
                end else if (gray < 74) begin
                    r = 255;
                    g = (gray - 37) * 7;
                    b = 0;
                end else if (gray < 111) begin
                    r = 255;
                    g = 255;
                    b = 0;
                end else if (gray < 148) begin
                    r = 255 - (gray - 111) * 7;
                    g = 255;
                    b = 0;
                end else if (gray < 185) begin
                    r = 0;
                    g = 255;
                    b = (gray - 148) * 7;
                end else if (gray < 222) begin
                    r = 0;
                    g = 255 - (gray - 185) * 7;
                    b = 255;
                end else begin
                    r = (gray - 222) * 8;
                    g = 0;
                    b = 255;
                end
            end
            
            3'b011: begin
                r = 0;
                g = gray;
                b = 255 - gray / 2;
            end
            
            3'b100: begin
                r = gray;
                g = 255;
                b = 0;
            end
            
            3'b101: begin
                r = 0;
                g = gray;
                b = 255 - gray / 3;
            end
            
            3'b110: begin
                r = 255;
                g = gray;
                b = 0;
            end
            
            3'b111: begin
                r = gray;
                g = gray;
                b = gray;
            end
            
            default: begin
                if (gray < 85) begin
                    r = gray * 3;
                    g = 0;
                    b = 0;
                end else if (gray < 170) begin
                    r = 255;
                    g = (gray - 85) * 3;
                    b = 0;
                end else begin
                    r = 255;
                    g = 255;
                    b = (gray - 170) * 3;
                end
            end
            
            default: begin
                r = gray;
                g = gray;
                b = gray;
            end
        endcase
        
        apply_colormap = {r, g, b};
    end
endfunction

wire [23:0] rgb_result;

assign rgb_result = apply_colormap(gray_reg, colormap_reg);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        gray_reg <= 8'b0;
        colormap_reg <= 3'b0;
        r_out <= 8'b0;
        g_out <= 8'b0;
        b_out <= 8'b0;
        data_out_valid <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                data_out_valid <= 1'b0;
                if (data_valid) begin
                    gray_reg <= gray_in;
                    colormap_reg <= colormap_sel;
                    state <= PROCESS;
                end
            end
            
            PROCESS: begin
                r_out <= rgb_result[23:16];
                g_out <= rgb_result[15:8];
                b_out <= rgb_result[7:0];
                data_out_valid <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule