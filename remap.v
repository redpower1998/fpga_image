module remap #(
    parameter IMAGE_WIDTH  = 640,
    parameter IMAGE_HEIGHT = 480,
    parameter FRAC = 12
)(
    input  wire                clk,
    input  wire                rst,
    input  wire                mem_wr_en,
    input  wire [31:0]         mem_wr_addr,
    input  wire [7:0]          mem_wr_data,
    input  wire                map_valid,
    input  wire [23:0]         map_x,
    input  wire [23:0]         map_y,
    output reg                 map_ready,
    output reg                 out_valid,
    output reg [7:0]           out_pixel
);

    localparam TOT_PIX = IMAGE_WIDTH * IMAGE_HEIGHT;

    reg [7:0] frame_mem [0:TOT_PIX-1];

    integer __init_i;
    initial begin
        for (__init_i = 0; __init_i < TOT_PIX; __init_i = __init_i + 1)
            frame_mem[__init_i] = 8'd0;
    end

    reg [19:0] ix_comb, iy_comb;
    reg [11:0] fx_comb, fy_comb;
    reg [31:0] addr0_comb, addr1_comb, addr2_comb, addr3_comb;
    reg [4:0] denom_comb;

    always @(*) begin
        if ((map_x >> FRAC) >= IMAGE_WIDTH)
            ix_comb = IMAGE_WIDTH - 1;
        else
            ix_comb = map_x >> FRAC;

        if ((map_y >> FRAC) >= IMAGE_HEIGHT)
            iy_comb = IMAGE_HEIGHT - 1;
        else
            iy_comb = map_y >> FRAC;

        fx_comb = map_x[FRAC-1:0];
        fy_comb = map_y[FRAC-1:0];

        addr0_comb = (iy_comb * IMAGE_WIDTH) + ix_comb;
        
        if ((ix_comb + 1) >= IMAGE_WIDTH)
            addr1_comb = (iy_comb * IMAGE_WIDTH) + ix_comb;
        else
            addr1_comb = (iy_comb * IMAGE_WIDTH) + (ix_comb + 1);

        if ((iy_comb + 1) >= IMAGE_HEIGHT)
            addr2_comb = (iy_comb * IMAGE_WIDTH) + ix_comb;
        else
            addr2_comb = ((iy_comb + 1) * IMAGE_WIDTH) + ix_comb;

        if ((ix_comb + 1) >= IMAGE_WIDTH) begin
            if ((iy_comb + 1) >= IMAGE_HEIGHT)
                addr3_comb = (iy_comb * IMAGE_WIDTH) + ix_comb;
            else
                addr3_comb = ((iy_comb + 1) * IMAGE_WIDTH) + ix_comb;
        end else begin
            if ((iy_comb + 1) >= IMAGE_HEIGHT)
                addr3_comb = (iy_comb * IMAGE_WIDTH) + (ix_comb + 1);
            else
                addr3_comb = ((iy_comb + 1) * IMAGE_WIDTH) + (ix_comb + 1);
        end

        denom_comb = (1 << FRAC);
    end

    always @(posedge clk) begin
        if (mem_wr_en && mem_wr_addr < TOT_PIX)
            frame_mem[mem_wr_addr] <= mem_wr_data;
    end

    reg [2:0] state;
    reg [7:0] p00, p01, p10, p11;
    reg [11:0] lat_fx, lat_fy;
    reg [4:0] lat_denom;
    reg [31:0] lat_addr1, lat_addr2, lat_addr3;
    integer wx, wy, wxi, wyi;
    integer s00, s01, s10, s11;
    integer ssum;
    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
            map_ready <= 1'b1;
            out_valid <= 1'b0;
            out_pixel <= 8'd0;
            p00 <= 0; p01 <= 0; p10 <= 0; p11 <= 0;
            lat_fx <= 0; lat_fy <= 0;
            lat_denom <= 0;
            lat_addr1 <= 0; lat_addr2 <= 0; lat_addr3 <= 0;
        end else begin
            out_valid <= 1'b0;
            
            case (state)
                3'd0: begin
                    map_ready <= 1'b1;
                    if (map_valid) begin
                        map_ready <= 1'b0;
                        lat_fx <= fx_comb;
                        lat_fy <= fy_comb;
                        lat_denom <= denom_comb;
                        lat_addr1 <= addr1_comb;
                        lat_addr2 <= addr2_comb;
                        lat_addr3 <= addr3_comb;
                        if (addr0_comb < TOT_PIX)
                            p00 <= frame_mem[addr0_comb];
                        else
                            p00 <= 8'd0;
                        state <= 3'd1;
                    end
                end

                3'd1: begin
                    if (lat_addr1 < TOT_PIX)
                        p01 <= frame_mem[lat_addr1];
                    else
                        p01 <= 8'd0;
                    state <= 3'd2;
                end

                3'd2: begin
                    if (lat_addr2 < TOT_PIX)
                        p10 <= frame_mem[lat_addr2];
                    else
                        p10 <= 8'd0;
                    state <= 3'd3;
                end

                3'd3: begin
                    if (lat_addr3 < TOT_PIX)
                        p11 <= frame_mem[lat_addr3];
                    else
                        p11 <= 8'd0;
                    state <= 3'd4;
                end

                3'd4: begin

                    
                    wx = lat_fx;
                    wy = lat_fy;
                    wxi = (lat_denom << FRAC) - wx;
                    wyi = (lat_denom << FRAC) - wy;
                    
                    s00 = p00 * wxi * wyi;
                    s01 = p01 * wx  * wyi;
                    s10 = p10 * wxi * wy;
                    s11 = p11 * wx  * wy;
                    ssum = s00 + s01 + s10 + s11;
                    
                    out_pixel <= (ssum >> (2*FRAC));
                    out_valid <= 1'b1;
                    state <= 3'd0;
                end

                default: state <= 3'd0;
            endcase
        end
    end

endmodule