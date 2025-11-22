`timescale 1ns/1ps

module tb_yv12_to_rgb;

    parameter CLK_PERIOD = 10;
    parameter IMG_WIDTH = 320;
    parameter IMG_HEIGHT = 466;
    parameter TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;
    parameter UV_WIDTH = IMG_WIDTH / 2;
    parameter UV_HEIGHT = IMG_HEIGHT / 2;
    parameter UV_PLANE_SIZE = UV_WIDTH * UV_HEIGHT;
    
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
    integer read_count;
    integer pixel_count;
    integer frame_count;
    reg [7:0] y_buffer;
    reg [7:0] u_buffer;
    reg [7:0] v_buffer;
    reg eof_flag;
    
    reg [7:0] u_plane [0:UV_PLANE_SIZE-1];
    reg [7:0] v_plane [0:UV_PLANE_SIZE-1];
    reg uv_loaded;
    integer uv_index;
    reg [7:0] temp_byte;
    
    yv12_to_rgb dut (
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
    
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    task load_uv_planes;
        integer i;
        begin
            $display("Starting UV plane data loading...");
            
            for (i = 0; i < UV_PLANE_SIZE; i = i + 1) begin
                read_count = $fread(temp_byte, yuv_file);
                if (read_count == 0) begin
                    $display("Error: Failed to read U plane data, index %d", i);
                    $finish;
                end
                u_plane[i] = temp_byte;
            end
            
            for (i = 0; i < UV_PLANE_SIZE; i = i + 1) begin
                read_count = $fread(temp_byte, yuv_file);
                if (read_count == 0) begin
                    $display("Error: Failed to read V plane data, index %d", i);
                    $finish;
                end
                v_plane[i] = temp_byte;
            end
            
            uv_loaded = 1'b1;
            $display("UV plane data loading completed, size: %dx%d", UV_WIDTH, UV_HEIGHT);
        end
    endtask
    
    task read_yuv_pixel_yv12;
        integer current_x;
        integer current_y;
        integer uv_x;
        integer uv_y;
        begin
            read_count = $fread(y_buffer, yuv_file);
            if (read_count == 0) begin
                eof_flag = 1'b1;
                y_buffer = 8'd0;
                u_buffer = 8'd128;
                v_buffer = 8'd128;
            end else begin
                current_x = pixel_count % IMG_WIDTH;
                current_y = pixel_count / IMG_WIDTH;
                
                uv_x = current_x / 2;
                uv_y = current_y / 2;
                uv_index = uv_y * UV_WIDTH + uv_x;
                
                if (uv_index < UV_PLANE_SIZE && uv_loaded) begin
                    u_buffer = u_plane[uv_index];
                    v_buffer = v_plane[uv_index];
                end else begin
                    u_buffer = 8'd128;
                    v_buffer = 8'd128;
                end
            end
        end
    endtask
    
    task write_ppm_header;
        input integer width;
        input integer height;
        begin
            $fdisplay(ppm_file, "P6");
            $fdisplay(ppm_file, "%d %d", width, height);
            $fdisplay(ppm_file, "255");
        end
    endtask
    
    task write_ppm_pixel;
        input [7:0] r_val;
        input [7:0] g_val;
        input [7:0] b_val;
        begin
            $fwrite(ppm_file, "%c%c%c", r_val, g_val, b_val);
        end
    endtask
    
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        data_valid = 1'b0;
        y_data = 8'd0;
        u_data = 8'd0;
        v_data = 8'd0;
        read_count = 0;
        pixel_count = 0;
        frame_count = 0;
        eof_flag = 1'b0;
        uv_loaded = 1'b0;
        uv_index = 0;
        temp_byte = 8'd0;
        
        yuv_file = $fopen("data/color2_320x466_yv12.yuv", "rb");
        if (yuv_file == 0) begin
            $display("Error: Cannot open YUV input file data/color2_320x466_yv12.yuv");
            $finish;
        end
        
        ppm_file = $fopen("output/color2_320x466_yv12.ppm", "wb");
        if (ppm_file == 0) begin
            $display("Warning: Cannot create PPM output file output/color2_320x466_yv12.ppm");
            $display("Please ensure the output directory exists, or create the directory manually");
            $finish;
        end
        
        $display("=== Starting YV12 to RGB Test ===");
        $display("Input file: data/color2_320x466_yv12.yuv");
        $display("Output file: output/color2_320x466_yv12.ppm");
        $display("Image size: %dx%d", IMG_WIDTH, IMG_HEIGHT);
        $display("UV plane size: %dx%d", UV_WIDTH, UV_HEIGHT);
        
        write_ppm_header(IMG_WIDTH, IMG_HEIGHT);
        
        #100;
        rst_n = 1'b1;
        #100;
        
        $display("Phase 1: Reading Y component...");
        while (pixel_count < TOTAL_PIXELS) begin
            read_count = $fread(y_buffer, yuv_file);
            if (read_count == 0) begin
                $display("Error: Incomplete Y component reading");
                $finish;
            end
            pixel_count = pixel_count + 1;
        end
        
        $display("Y component reading completed, total pixels: %d", pixel_count);
        
        load_uv_planes();
        
        $fclose(yuv_file);
        yuv_file = $fopen("data/color2_320x466_yv12.yuv", "rb");
        if (yuv_file == 0) begin
            $display("Error: Cannot reopen YUV input file");
            $finish;
        end
        
        pixel_count = 0;
        eof_flag = 1'b0;
        
        $display("Phase 2: Processing YV12 data...");
        while (!eof_flag && pixel_count < TOTAL_PIXELS) begin
            read_yuv_pixel_yv12();
            
            if (!eof_flag) begin
                data_valid = 1'b1;
                y_data = y_buffer;
                u_data = u_buffer;
                v_data = v_buffer;
                
                #CLK_PERIOD;
                
                pixel_count = pixel_count + 1;
                
                if (pixel_count % 1000 == 0) begin
                    $display("Processing progress: %d/%d pixels (%.1f%%)", 
                             pixel_count, TOTAL_PIXELS, 
                             (pixel_count * 100.0) / TOTAL_PIXELS);
                end
            end else begin
                data_valid = 1'b0;
            end
        end
        
        #(CLK_PERIOD * 10);
        
        $fclose(yuv_file);
        $fclose(ppm_file);
        
        $display("=== YV12 to RGB Test Complete ===");
        $display("Total processed pixels: %d", pixel_count);
        $display("Output file saved: output/color2_320x466_yv12.ppm");
        
        $finish;
    end
    
    always @(posedge clk) begin
        if (data_out_valid) begin
            write_ppm_pixel(r_out, g_out, b_out);
            frame_count = frame_count + 1;
            
            if (frame_count % 1000 == 0) begin
                $display("RGB output progress: %d/%d pixels (%.1f%%)", 
                         frame_count, TOTAL_PIXELS, 
                         (frame_count * 100.0) / TOTAL_PIXELS);
            end
        end
    end
    
    initial begin
        #10000000;
        $display("Error: Test timeout!");
        $fclose(yuv_file);
        $fclose(ppm_file);
        $finish;
    end

endmodule