module simple_bram #(
    parameter ADDR_WIDTH = 11,
    parameter DATA_WIDTH = 8,
    parameter MEM_SIZE = 2048
)(
    input clka,
    input wea,
    input [ADDR_WIDTH-1:0] addra,
    input [DATA_WIDTH-1:0] dina,
    input clkb,
    input [ADDR_WIDTH-1:0] addrb,
    output reg [DATA_WIDTH-1:0] doutb
);

    reg [DATA_WIDTH-1:0] memory [0:MEM_SIZE-1];
    
    always @(posedge clka) begin
        if (wea) begin
            memory[addra] <= dina;
        end
    end
    
    always @(posedge clkb) begin
        doutb <= memory[addrb];
    end

endmodule