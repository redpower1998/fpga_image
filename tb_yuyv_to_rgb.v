`timescale 1ns/1ps

module tb_yuyv_to_rgb;

    parameter CLK_PERIOD = 10;
    parameter IMG_WIDTH = 320;
    parameter IMG_HEIGHT = 466;
    parameter TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;
    parameter TOTAL_YUYV_WORDS = TOTAL_PIXELS / 2;
    
    reg clk;
    reg rst_n;
    
    reg data_valid;
    reg [31:0] yuyv_data;
    wire data_out_valid;
    wire [7:0] r0_out, g0_out, b0_out;
    wire [7:0] r1_out, g1_out, b1_out;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    
    integer yuyv_file;
    integer ppm_file;
    integer read_count;
    integer word_count;
    integer pixel_count;
    integer frame_count;
    reg [31:0] yuyv_buffer;
    reg eof_flag;
    
    yuyv_to_rgb dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(data_valid),
        .yuyv_data(yuyv_data),
        .data_out_valid(data_out_valid),
        .r0_out(r0_out),
        .g0_out(g0_out),
        .b0_out(b0_out),
        .r1_out(r1_out),
        .g1_out(g1_out),
        .b1_out(b1_out),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );
    
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
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
        yuyv_data = 32'd0;
        read_count = 0;
        word_count = 0;
        pixel_count = 0;
        frame_count = 0;
        eof_flag = 1'b0;
        
        yuyv_file = $fopen("data/color2_320x466.yuyv", "rb");
        if (yuyv_file == 0) begin
            $display("Error: Cannot open YUYV input file data/color2_320x466.yuyv");
            $finish;
        end
        
        ppm_file = $fopen("output/color2_320x466_yuyv.ppm", "wb");
        if (ppm_file == 0) begin
            $display("Warning: Cannot create PPM output file output/color2_320x466_yuyv.ppm");
            $display("Please ensure the output directory exists, or create the directory manually");
            $finish;
        end
        
        $display("=== Starting YUYV to RGB Test ===");
        $display("Input file: data/color2_320x466.yuyv");
        $display("Output file: output/color2_320x466_yuyv.ppm");
        $display("Image size: %dx%d", IMG_WIDTH, IMG_HEIGHT);
        $display("YUYV data words: %d", TOTAL_YUYV_WORDS);
        
        write_ppm_header(IMG_WIDTH, IMG_HEIGHT);
        
        #100;
        rst_n = 1'b1;
        #100;
        
        $display("Starting YUYV data processing...");
        while (!eof_flag && word_count < TOTAL_YUYV_WORDS) begin
            read_count = $fread(yuyv_buffer, yuyv_file);
            if (read_count == 0) begin
                eof_flag = 1'b1;
                yuyv_buffer = 32'd0;
            end else begin
                data_valid = 1'b1;
                yuyv_data = yuyv_buffer;
                
                #CLK_PERIOD;
                
                word_count = word_count + 1;
                
                if (word_count % 500 == 0) begin
                    $display("Processing progress: %d/%d words (%.1f%%)", 
                             word_count, TOTAL_YUYV_WORDS, 
                             (word_count * 100.0) / TOTAL_YUYV_WORDS);
                end
            end
        end
        
        #(CLK_PERIOD * 20);
        
        $fclose(yuyv_file);
        $fclose(ppm_file);
        
        $display("=== YUYV to RGB Test Complete ===");
        $display("Total processed words: %d", word_count);
        $display("Total output pixels: %d", pixel_count);
        $display("Output file saved: output/color2_320x466_yuyv.ppm");
        
        $finish;
    end
    
    always @(posedge clk) begin
        if (data_out_valid) begin
            write_ppm_pixel(r0_out, g0_out, b0_out);
            write_ppm_pixel(r1_out, g1_out, b1_out);
            
            pixel_count = pixel_count + 2;
            frame_count = frame_count + 1;
            
            if (frame_count % 500 == 0) begin
                $display("RGB output progress: %d/%d pixels (%.1f%%)", 
                         pixel_count, TOTAL_PIXELS, 
                         (pixel_count * 100.0) / TOTAL_PIXELS);
            end
        end
    end
    
    initial begin
        #10000000;
        $display("Error: Test timeout!");
        $fclose(yuyv_file);
        $fclose(ppm_file);
        $finish;
    end

endmodule