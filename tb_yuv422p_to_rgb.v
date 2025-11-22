`timescale 1ns/1ps

module tb_yuv422p_to_rgb;

parameter CLK_PERIOD = 10;
parameter IMG_WIDTH = 320;
parameter IMG_HEIGHT = 466;
parameter Y_PLANE_SIZE = IMG_WIDTH * IMG_HEIGHT;
parameter UV_PLANE_SIZE = (IMG_WIDTH/2) * IMG_HEIGHT;
parameter TOTAL_YUV_SIZE = Y_PLANE_SIZE + 2*UV_PLANE_SIZE;

reg clk;
reg rst_n;

reg data_valid;
reg [7:0] y_data;
reg [7:0] u_data;
reg [7:0] v_data;

wire data_out_valid;
wire [7:0] r_out;
wire [7:0] g_out;
wire [7:0] b_out;
wire [9:0] pixel_x;
wire [9:0] pixel_y;

integer yuv_file;
integer ppm_file;

integer pixel_count;
integer timeout_counter;
parameter TIMEOUT_LIMIT = 1000000;

yuv422p_to_rgb dut (
    .clk(clk),
    .rst_n(rst_n),
    .data_valid(data_valid),
    .y_data(y_data),
    .u_data(u_data),
    .v_data(v_data),
    .data_out_valid(data_out_valid),
    .r_out(r_out),
    .g_out(g_out),
    .b_out(b_out),
    .pixel_x(pixel_x),
    .pixel_y(pixel_y)
);

always #(CLK_PERIOD/2) clk = ~clk;

initial begin
    clk = 0;
    rst_n = 0;
    data_valid = 0;
    y_data = 8'd0;
    u_data = 8'd0;
    v_data = 8'd0;
    pixel_count = 0;
    timeout_counter = 0;
    
    yuv_file = $fopen("data/color2_320x466.yuv422p", "rb");
    if (yuv_file == 0) begin
        $display("Error: Cannot open YUV422P file");
        $finish;
    end
    
    ppm_file = $fopen("output/color2_320x466_yuv422p.ppm", "wb");
    if (ppm_file == 0) begin
        $display("Error: Cannot create PPM file");
        $fclose(yuv_file);
        $finish;
    end
    
    $fwrite(ppm_file, "P6\n%d %d\n255\n", IMG_WIDTH, IMG_HEIGHT);
    
    #(CLK_PERIOD*2);
    rst_n = 1;
    #(CLK_PERIOD*2);
    
    $display("Starting YUV422P to RGB conversion test...");
    
    read_yuv422p_data();
    
    wait_for_completion();
    
    $fclose(yuv_file);
    $fclose(ppm_file);
    
    $display("YUV422P to RGB conversion test completed!");
    $display("Output file: output/color2_320x466_yuv422p.ppm");
    $finish;
end

task read_yuv422p_data;
    integer i, j;
    reg [7:0] temp_byte;
    integer y_offset, u_offset, v_offset;
    integer u_index, v_index;
    reg error_flag;
    integer seek_result;
    
    begin
        error_flag = 0;
        
        for (j = 0; j < IMG_HEIGHT && !error_flag; j = j + 1) begin
            for (i = 0; i < IMG_WIDTH && !error_flag; i = i + 1) begin
                if ($fread(temp_byte, yuv_file) != 1) begin
                    $display("Error: Y plane data read failed");
                    error_flag = 1;
                    disable read_yuv422p_data;
                end
                y_data = temp_byte;
                
                u_index = (i / 2) + (j * (IMG_WIDTH/2));
                v_index = u_index + UV_PLANE_SIZE;
                
                y_offset = $ftell(yuv_file);
                
                seek_result = $fseek(yuv_file, Y_PLANE_SIZE + u_index, 0);
                if (seek_result != 0) begin
                    $display("Error: U component file positioning failed");
                    error_flag = 1;
                    disable read_yuv422p_data;
                end
                if ($fread(temp_byte, yuv_file) != 1) begin
                    $display("Error: U component read failed");
                    error_flag = 1;
                    disable read_yuv422p_data;
                end
                u_data = temp_byte;
                
                seek_result = $fseek(yuv_file, Y_PLANE_SIZE + v_index, 0);
                if (seek_result != 0) begin
                    $display("Error: V component file positioning failed");
                    error_flag = 1;
                    disable read_yuv422p_data;
                end
                if ($fread(temp_byte, yuv_file) != 1) begin
                    $display("Error: V component read failed");
                    error_flag = 1;
                    disable read_yuv422p_data;
                end
                v_data = temp_byte;
                
                seek_result = $fseek(yuv_file, y_offset, 0);
                if (seek_result != 0) begin
                    $display("Error: Y plane file positioning recovery failed");
                    error_flag = 1;
                    disable read_yuv422p_data;
                end
                
                data_valid = 1;
                #(CLK_PERIOD);
                data_valid = 0;
                #(CLK_PERIOD*2);
                
                pixel_count = pixel_count + 1;
                
                if (pixel_count % 1000 == 0) begin
                    $display("Processing progress: %0d/%0d pixels", pixel_count, Y_PLANE_SIZE);
                end
            end
        end
        
        if (error_flag) begin
            $display("YUV422P data read failed, test terminated");
            $fclose(yuv_file);
            $fclose(ppm_file);
            $finish;
        end
    end
endtask

task write_ppm_pixel;
    input [7:0] r, g, b;
    begin
        $fwrite(ppm_file, "%c%c%c", r, g, b);
    end
endtask

task wait_for_completion;
    begin
        timeout_counter = 0;
        while (pixel_count < Y_PLANE_SIZE && timeout_counter < TIMEOUT_LIMIT) begin
            #(CLK_PERIOD);
            timeout_counter = timeout_counter + 1;
            
            if (data_out_valid) begin
                write_ppm_pixel(r_out, g_out, b_out);
                pixel_count = pixel_count + 1;
            end
        end
        
        if (timeout_counter >= TIMEOUT_LIMIT) begin
            $display("Error: Processing timeout");
        end
    end
endtask

always @(posedge clk) begin
    if (data_out_valid) begin
        if (pixel_count < Y_PLANE_SIZE) begin
            write_ppm_pixel(r_out, g_out, b_out);
        end
    end
end

always @(posedge clk) begin
    if (timeout_counter >= TIMEOUT_LIMIT) begin
        $display("Error: Test timeout");
        $fclose(yuv_file);
        $fclose(ppm_file);
        $finish;
    end
end

endmodule