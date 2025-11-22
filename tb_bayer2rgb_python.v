`timescale 1ns/1ps

module tb_bayer2rgb_python;

    parameter IMAGE_WIDTH = 320;
    parameter IMAGE_HEIGHT = 466;
    parameter IMAGE_SIZE = IMAGE_WIDTH * IMAGE_HEIGHT;
    
    parameter BAYER_FILE = "data/color2_bayer_rggb.raw";
    parameter OUTPUT_FILE = "output/output_rgb_python.ppm";
    
    parameter CLK_PERIOD = 10;
    
    reg clk;
    reg reset_n;
    integer file_in, file_out;
    integer i, j, x, y;
    integer pixel_count;
    
    reg [7:0] bayer_memory [0:IMAGE_SIZE-1];
    reg [7:0] padded_bayer [0:IMAGE_HEIGHT+1][0:IMAGE_WIDTH+1];
    
    reg [7:0] rgb_memory [0:IMAGE_SIZE-1][0:2];
    
    always #(CLK_PERIOD/2) clk = ~clk;
    
    initial begin
        clk = 0;
        reset_n = 0;
        pixel_count = 0;
        
        file_in = $fopen(BAYER_FILE, "rb");
        if (file_in == 0) begin
            $display("Error: Cannot open Bayer file %s", BAYER_FILE);
            $finish;
        end
        
        for (i = 0; i < IMAGE_SIZE; i = i + 1) begin
            bayer_memory[i] = $fgetc(file_in);
        end
        $fclose(file_in);
        $display("Successfully read Bayer file, total %0d bytes", IMAGE_SIZE);
        
        create_padded_bayer();
        
        apply_python_rggb_algorithm();
        
        save_rgb_to_ppm();
        
        $display("Test completed! RGB image saved as %s", OUTPUT_FILE);
        $finish;
    end
    
    task create_padded_bayer;
        integer row, col;
        begin
            for (row = 0; row < IMAGE_HEIGHT; row = row + 1) begin
                for (col = 0; col < IMAGE_WIDTH; col = col + 1) begin
                    padded_bayer[row+1][col+1] = bayer_memory[row * IMAGE_WIDTH + col];
                end
            end
            
            for (col = 0; col < IMAGE_WIDTH; col = col + 1) begin
                padded_bayer[0][col+1] = bayer_memory[col];
            end
            
            for (col = 0; col < IMAGE_WIDTH; col = col + 1) begin
                padded_bayer[IMAGE_HEIGHT+1][col+1] = bayer_memory[(IMAGE_HEIGHT-1) * IMAGE_WIDTH + col];
            end
            
            for (row = 0; row < IMAGE_HEIGHT; row = row + 1) begin
                padded_bayer[row+1][0] = bayer_memory[row * IMAGE_WIDTH];
            end
            
            for (row = 0; row < IMAGE_HEIGHT; row = row + 1) begin
                padded_bayer[row+1][IMAGE_WIDTH+1] = bayer_memory[row * IMAGE_WIDTH + IMAGE_WIDTH-1];
            end
            
            padded_bayer[0][0] = bayer_memory[0];
            padded_bayer[0][IMAGE_WIDTH+1] = bayer_memory[IMAGE_WIDTH-1];
            padded_bayer[IMAGE_HEIGHT+1][0] = bayer_memory[(IMAGE_HEIGHT-1) * IMAGE_WIDTH];
            padded_bayer[IMAGE_HEIGHT+1][IMAGE_WIDTH+1] = bayer_memory[(IMAGE_HEIGHT-1) * IMAGE_WIDTH + IMAGE_WIDTH-1];
            
            $display("Mirror boundary padding completed");
        end
    endtask
    
    task apply_python_rggb_algorithm;
        integer y, x, py, px;
        integer r, g, b;
        integer window [0:2][0:2];
        begin
            $display("Starting Python RGGB algorithm...");
            
            for (y = 0; y < IMAGE_HEIGHT; y = y + 1) begin
                for (x = 0; x < IMAGE_WIDTH; x = x + 1) begin
                    py = y + 1;
                    px = x + 1;
                    
                    window[0][0] = padded_bayer[py-1][px-1];
                    window[0][1] = padded_bayer[py-1][px];
                    window[0][2] = padded_bayer[py-1][px+1];
                    window[1][0] = padded_bayer[py][px-1];
                    window[1][1] = padded_bayer[py][px];
                    window[1][2] = padded_bayer[py][px+1];
                    window[2][0] = padded_bayer[py+1][px-1];
                    window[2][1] = padded_bayer[py+1][px];
                    window[2][2] = padded_bayer[py+1][px+1];
                    
                    if (y % 2 == 0) begin
                        if (x % 2 == 0) begin
                            r = window[1][1];
                            g = (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) / 4;
                            b = (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) / 4;
                        end else begin
                            g = window[1][1];
                            r = (window[1][0] + window[1][2] + 1) / 2;
                            b = (window[0][1] + window[2][1] + 1) / 2;
                        end
                    end else begin
                        if (x % 2 == 0) begin
                            g = window[1][1];
                            r = (window[0][1] + window[2][1] + 1) / 2;
                            b = (window[1][0] + window[1][2] + 1) / 2;
                        end else begin
                            b = window[1][1];
                            g = (window[1][0] + window[1][2] + window[0][1] + window[2][1] + 2) / 4;
                            r = (window[0][0] + window[0][2] + window[2][0] + window[2][2] + 2) / 4;
                        end
                    end
                    
                    if (r < 0) r = 0;
                    if (r > 255) r = 255;
                    if (g < 0) g = 0;
                    if (g > 255) g = 255;
                    if (b < 0) b = 0;
                    if (b > 255) b = 255;
                    
                    rgb_memory[y * IMAGE_WIDTH + x][0] = r;
                    rgb_memory[y * IMAGE_WIDTH + x][1] = g;
                    rgb_memory[y * IMAGE_WIDTH + x][2] = b;
                end
                
                if (y % 50 == 0) begin
                    $display("Processing progress: %0d/%0d rows", y, IMAGE_HEIGHT);
                end
            end
            
            $display("Python RGGB algorithm processing completed");
        end
    endtask
    
    task save_rgb_to_ppm;
        integer i, pixel_index;
        begin
            file_out = $fopen(OUTPUT_FILE, "w");
            if (file_out == 0) begin
                $display("Error: Cannot create output file %s", OUTPUT_FILE);
                $finish;
            end
            
            $fdisplay(file_out, "P3");
            $fdisplay(file_out, "%0d %0d", IMAGE_WIDTH, IMAGE_HEIGHT);
            $fdisplay(file_out, "255");
            
            for (i = 0; i < IMAGE_SIZE; i = i + 1) begin
                $fwrite(file_out, "%0d %0d %0d ", 
                       rgb_memory[i][0], rgb_memory[i][1], rgb_memory[i][2]);
                
                if ((i+1) % 10 == 0) begin
                    $fdisplay(file_out, "");
                end
            end
            
            $fclose(file_out);
            $display("PPM file saved successfully");
        end
    endtask
    
    initial begin
        #10;
        $display("=== Python Algorithm Test Platform Started ===");
        $display("Image size: %0d x %0d", IMAGE_WIDTH, IMAGE_HEIGHT);
        $display("Bayer file: %s", BAYER_FILE);
        $display("Output file: %s", OUTPUT_FILE);
    end

endmodule