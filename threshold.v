`timescale 1ns/1ps

module threshold #(
    parameter DATA_WIDTH = 8
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     data_valid,
    input  wire [DATA_WIDTH-1:0]    pixel_in,
    input  wire [DATA_WIDTH-1:0]    threshold_val,
    output reg                      data_out_valid,
    output reg  [DATA_WIDTH-1:0]    pixel_out
);

reg [DATA_WIDTH-1:0] pixel_in_reg;
reg data_valid_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_in_reg <= {DATA_WIDTH{1'b0}};
        data_valid_reg <= 1'b0;
        data_out_valid <= 1'b0;
        pixel_out <= {DATA_WIDTH{1'b0}};
    end else begin
        pixel_in_reg <= pixel_in;
        data_valid_reg <= data_valid;
        
        data_out_valid <= data_valid_reg;
        
        if (data_valid_reg) begin
            if (pixel_in_reg >= threshold_val) begin
                pixel_out <= 8'd255;
            end else begin
                pixel_out <= 8'd0;
            end
        end else begin
            pixel_out <= {DATA_WIDTH{1'b0}};
        end
    end
end

endmodule