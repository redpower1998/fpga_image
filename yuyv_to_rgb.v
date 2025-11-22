module yuyv_to_rgb (
    input wire clk,
    input wire rst_n,
    
    input wire data_valid,
    input wire [31:0] yuyv_data,
    
    output reg data_out_valid,
    output reg [7:0] r0_out,
    output reg [7:0] g0_out,
    output reg [7:0] b0_out,
    output reg [7:0] r1_out,
    output reg [7:0] g1_out,
    output reg [7:0] b1_out,
    
    output reg [9:0] pixel_x,
    output reg [9:0] pixel_y
);

localparam COEF_R_Y  = 16'd256;
localparam COEF_R_CR = 16'd359;

localparam COEF_G_Y  = 16'd256;
localparam COEF_G_CB = 16'd88;
localparam COEF_G_CR = 16'd183;

localparam COEF_B_Y  = 16'd256;
localparam COEF_B_CB = 16'd454;

localparam IMG_WIDTH  = 10'd320;
localparam IMG_HEIGHT = 10'd466;

reg [17:0] y0_mult_r, cr_mult_r;
reg [17:0] y0_mult_g, cb_mult_g, cr_mult_g;
reg [17:0] y0_mult_b, cb_mult_b;

reg [17:0] y1_mult_r;
reg [17:0] y1_mult_g;
reg [17:0] y1_mult_b;

reg [17:0] r0_temp, g0_temp, b0_temp;
reg [17:0] r1_temp, g1_temp, b1_temp;
reg valid_p1, valid_p2, valid_p3;

reg [9:0] x_count, y_count;
reg frame_active;

reg [7:0] y0_data, u_data, y1_data, v_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_count <= 10'd0;
        y_count <= 10'd0;
        frame_active <= 1'b0;
        pixel_x <= 10'd0;
        pixel_y <= 10'd0;
    end else if (data_valid) begin
        if (x_count >= IMG_WIDTH - 2) begin
            x_count <= 10'd0;
            if (y_count == IMG_HEIGHT - 1) begin
                y_count <= 10'd0;
                frame_active <= 1'b0;
            end else begin
                y_count <= y_count + 10'd1;
            end
        end else begin
            x_count <= x_count + 10'd2;
        end
        
        pixel_x <= x_count;
        pixel_y <= y_count;
        frame_active <= 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y0_mult_r  <= 18'd0;
        cr_mult_r  <= 18'd0;
        y0_mult_g  <= 18'd0;
        cb_mult_g  <= 18'd0;
        cr_mult_g  <= 18'd0;
        y0_mult_b  <= 18'd0;
        cb_mult_b  <= 18'd0;
        y1_mult_r  <= 18'd0;
        y1_mult_g  <= 18'd0;
        y1_mult_b  <= 18'd0;
        valid_p1   <= 1'b0;
        
        y0_data <= 8'd0;
        u_data  <= 8'd0;
        y1_data <= 8'd0;
        v_data  <= 8'd0;
    end else begin
        y0_data <= yuyv_data[31:24];
        u_data  <= yuyv_data[23:16];
        y1_data <= yuyv_data[15:8];
        v_data  <= yuyv_data[7:0];
        
        y0_mult_r <= y0_data * COEF_R_Y;
        y0_mult_g <= y0_data * COEF_G_Y;
        y0_mult_b <= y0_data * COEF_B_Y;
        
        y1_mult_r <= y1_data * COEF_R_Y;
        y1_mult_g <= y1_data * COEF_G_Y;
        y1_mult_b <= y1_data * COEF_B_Y;
        
        if (v_data >= 8'd128) begin
            cr_mult_r <= (v_data - 8'd128) * COEF_R_CR;
            cr_mult_g <= (v_data - 8'd128) * COEF_G_CR;
        end else begin
            cr_mult_r <= 18'd0 - ((8'd128 - v_data) * COEF_R_CR);
            cr_mult_g <= 18'd0 - ((8'd128 - v_data) * COEF_G_CR);
        end
        
        if (u_data >= 8'd128) begin
            cb_mult_g <= (u_data - 8'd128) * COEF_G_CB;
            cb_mult_b <= (u_data - 8'd128) * COEF_B_CB;
        end else begin
            cb_mult_g <= 18'd0 - ((8'd128 - u_data) * COEF_G_CB);
            cb_mult_b <= 18'd0 - ((8'd128 - u_data) * COEF_B_CB);
        end
        
        valid_p1 <= data_valid;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r0_temp <= 18'd0;
        g0_temp <= 18'd0;
        b0_temp <= 18'd0;
        r1_temp <= 18'd0;
        g1_temp <= 18'd0;
        b1_temp <= 18'd0;
        valid_p2 <= 1'b0;
    end else begin
        r0_temp <= y0_mult_r + cr_mult_r;
        g0_temp <= y0_mult_g - cb_mult_g - cr_mult_g;
        b0_temp <= y0_mult_b + cb_mult_b;
        
        r1_temp <= y1_mult_r + cr_mult_r;
        g1_temp <= y1_mult_g - cb_mult_g - cr_mult_g;
        b1_temp <= y1_mult_b + cb_mult_b;
        
        valid_p2 <= valid_p1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r0_out <= 8'd0;
        g0_out <= 8'd0;
        b0_out <= 8'd0;
        r1_out <= 8'd0;
        g1_out <= 8'd0;
        b1_out <= 8'd0;
        data_out_valid <= 1'b0;
        valid_p3 <= 1'b0;
    end else begin
        if (r0_temp[17] == 1'b1) begin
            r0_out <= 8'd0;
        end else if (r0_temp > 18'd65280) begin
            r0_out <= 8'd255;
        end else begin
            r0_out <= r0_temp[17:8];
        end
        
        if (g0_temp[17] == 1'b1) begin
            g0_out <= 8'd0;
        end else if (g0_temp > 18'd65280) begin
            g0_out <= 8'd255;
        end else begin
            g0_out <= g0_temp[17:8];
        end
        
        if (b0_temp[17] == 1'b1) begin
            b0_out <= 8'd0;
        end else if (b0_temp > 18'd65280) begin
            b0_out <= 8'd255;
        end else begin
            b0_out <= b0_temp[17:8];
        end
        
        if (r1_temp[17] == 1'b1) begin
            r1_out <= 8'd0;
        end else if (r1_temp > 18'd65280) begin
            r1_out <= 8'd255;
        end else begin
            r1_out <= r1_temp[17:8];
        end
        
        if (g1_temp[17] == 1'b1) begin
            g1_out <= 8'd0;
        end else if (g1_temp > 18'd65280) begin
            g1_out <= 8'd255;
        end else begin
            g1_out <= g1_temp[17:8];
        end
        
        if (b1_temp[17] == 1'b1) begin
            b1_out <= 8'd0;
        end else if (b1_temp > 18'd65280) begin
            b1_out <= 8'd255;
        end else begin
            b1_out <= b1_temp[17:8];
        end
        
        data_out_valid <= valid_p2;
        valid_p3 <= valid_p2;
    end
end

endmodule