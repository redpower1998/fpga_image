module yv12_to_rgb (
    input wire clk,
    input wire rst_n,
    
    input wire data_valid,
    input wire [7:0] y_data,
    input wire [7:0] u_data,
    input wire [7:0] v_data,
    
    output reg data_out_valid,
    output reg [7:0] r_out,
    output reg [7:0] g_out,
    output reg [7:0] b_out,
    
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

reg [17:0] y_mult_r, cr_mult_r;
reg [17:0] y_mult_g, cb_mult_g, cr_mult_g;
reg [17:0] y_mult_b, cb_mult_b;

reg [17:0] r_temp, g_temp, b_temp;
reg valid_p1, valid_p2, valid_p3;

reg [9:0] x_count, y_count;
reg frame_active;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_count <= 10'd0;
        y_count <= 10'd0;
        frame_active <= 1'b0;
        pixel_x <= 10'd0;
        pixel_y <= 10'd0;
    end else if (data_valid) begin
        if (x_count == IMG_WIDTH - 1) begin
            x_count <= 10'd0;
            if (y_count == IMG_HEIGHT - 1) begin
                y_count <= 10'd0;
                frame_active <= 1'b0;
            end else begin
                y_count <= y_count + 10'd1;
            end
        end else begin
            x_count <= x_count + 10'd1;
        end
        
        pixel_x <= x_count;
        pixel_y <= y_count;
        frame_active <= 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_mult_r  <= 18'd0;
        cr_mult_r <= 18'd0;
        y_mult_g  <= 18'd0;
        cb_mult_g <= 18'd0;
        cr_mult_g <= 18'd0;
        y_mult_b  <= 18'd0;
        cb_mult_b <= 18'd0;
        valid_p1  <= 1'b0;
    end else begin
        y_mult_r <= y_data * COEF_R_Y;
        y_mult_g <= y_data * COEF_G_Y;
        y_mult_b <= y_data * COEF_B_Y;
        
        if (u_data >= 8'd128) begin
            cr_mult_r <= (u_data - 8'd128) * COEF_R_CR;
            cr_mult_g <= (u_data - 8'd128) * COEF_G_CR;
        end else begin
            cr_mult_r <= 18'd0 - ((8'd128 - u_data) * COEF_R_CR);
            cr_mult_g <= 18'd0 - ((8'd128 - u_data) * COEF_G_CR);
        end
        
        if (v_data >= 8'd128) begin
            cb_mult_g <= (v_data - 8'd128) * COEF_G_CB;
            cb_mult_b <= (v_data - 8'd128) * COEF_B_CB;
        end else begin
            cb_mult_g <= 18'd0 - ((8'd128 - v_data) * COEF_G_CB);
            cb_mult_b <= 18'd0 - ((8'd128 - v_data) * COEF_B_CB);
        end
        
        valid_p1 <= data_valid;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_temp <= 18'd0;
        g_temp <= 18'd0;
        b_temp <= 18'd0;
        valid_p2 <= 1'b0;
    end else begin
        r_temp <= y_mult_r + cr_mult_r;
        
        g_temp <= y_mult_g - cb_mult_g - cr_mult_g;
        
        b_temp <= y_mult_b + cb_mult_b;
        
        valid_p2 <= valid_p1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_out <= 8'd0;
        g_out <= 8'd0;
        b_out <= 8'd0;
        data_out_valid <= 1'b0;
        valid_p3 <= 1'b0;
    end else begin
        if (r_temp[17] == 1'b1) begin
            r_out <= 8'd0;
        end else if (r_temp > 18'd65280) begin
            r_out <= 8'd255;
        end else begin
            r_out <= r_temp[17:8];
        end
        
        if (g_temp[17] == 1'b1) begin
            g_out <= 8'd0;
        end else if (g_temp > 18'd65280) begin
            g_out <= 8'd255;
        end else begin
            g_out <= g_temp[17:8];
        end
        
        if (b_temp[17] == 1'b1) begin
            b_out <= 8'd0;
        end else if (b_temp > 18'd65280) begin
            b_out <= 8'd255;
        end else begin
            b_out <= b_temp[17:8];
        end
        
        data_out_valid <= valid_p2;
        valid_p3 <= valid_p2;
    end
end

endmodule