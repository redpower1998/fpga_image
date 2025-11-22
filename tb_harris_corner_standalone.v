`timescale 1ns/1ps

module tb_harris_corner_standalone;

parameter CLK_PERIOD = 10;
parameter IMAGE_WIDTH = 320;
parameter IMAGE_HEIGHT = 466;
parameter IMAGE_SIZE = IMAGE_WIDTH * IMAGE_HEIGHT;

parameter K_PARAM = 32'h00000400;
parameter THRESHOLD = 32'h00001000;

reg clk;

integer pgm_file_in;
integer pgm_file_out;

reg [7:0] source_image [0:IMAGE_SIZE-1];
reg [7:0] output_image [0:IMAGE_SIZE-1];

reg [7:0] window_buffer [0:8];
reg [7:0] line_buffer_0 [0:IMAGE_WIDTH-1];
reg [7:0] line_buffer_1 [0:IMAGE_WIDTH-1];
integer pixel_x, pixel_y;
integer gx, gy;
integer gx2, gy2, gxy;
integer sum_gx2, sum_gy2, sum_gxy;
integer det, trace_squared;
integer harris_response;

initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

initial begin
    $dumpfile("tb_harris_corner_standalone.vcd");
    $dumpvars(0, tb_harris_corner_standalone);
    
    #10;
    $display("Clock signal check: clk=%0d", clk);
    
    repeat(5) @(posedge clk);
    
    $display("=== Starting Harris Corner Detection Algorithm Test ===");
    
    process_pgm_image("data/chessboard_resized.pgm", "output/harris_corner_output.pgm");
    
    $display("=== All Tests Completed ===");
    #1000;
    $finish;
end

task harris_corner_detection;
    input integer width;
    input integer height;
    
    integer i, j, k;
    integer corner_count;
    integer trace;
    integer window_size;
    integer half_window;
    integer win_x, win_y;
    integer actual_x, actual_y;
    integer sobel_i;
    integer sobel_win_x, sobel_win_y;
    reg [7:0] sobel_window [0:8];
    begin
        window_size = 3;
        half_window = 1;
        corner_count = 0;
        
        $display("=== Starting Harris Corner Detection Algorithm ===");
        $display("Image dimensions: %0d x %0d", width, height);
        
        for (i = 0; i < 9; i = i + 1) begin
            window_buffer[i] = 0;
        end
        for (i = 0; i < width; i = i + 1) begin
            line_buffer_0[i] = 0;
            line_buffer_1[i] = 0;
        end
        
        for (pixel_y = 0; pixel_y < height; pixel_y = pixel_y + 1) begin
            for (pixel_x = 0; pixel_x < width; pixel_x = pixel_x + 1) begin
                i = pixel_y * width + pixel_x;
                
                line_buffer_0[pixel_x] = source_image[i];
                
                if (pixel_x == width - 1) begin
                    for (j = 0; j < width; j = j + 1) begin
                        line_buffer_1[j] = line_buffer_0[j];
                    end
                end
                
                if (pixel_x >= 1 && pixel_y >= 1 && pixel_x < width - 1 && pixel_y < height - 1) begin
                    window_buffer[0] = line_buffer_1[pixel_x - 1];
                    window_buffer[1] = line_buffer_1[pixel_x];
                    window_buffer[2] = line_buffer_1[pixel_x + 1];
                    window_buffer[3] = line_buffer_0[pixel_x - 1];
                    window_buffer[4] = line_buffer_0[pixel_x];
                    window_buffer[5] = line_buffer_0[pixel_x + 1];
                    window_buffer[6] = source_image[(pixel_y + 1) * width + pixel_x - 1];
                    window_buffer[7] = source_image[(pixel_y + 1) * width + pixel_x];
                    window_buffer[8] = source_image[(pixel_y + 1) * width + pixel_x + 1];
                    
                    gx = (window_buffer[2] - window_buffer[0]) + 
                         ((window_buffer[5] - window_buffer[3]) * 2) +
                         (window_buffer[8] - window_buffer[6]);
                    
                    gy = (window_buffer[6] - window_buffer[0]) + 
                         ((window_buffer[7] - window_buffer[1]) * 2) +
                         (window_buffer[8] - window_buffer[2]);
                    
                    gx2 = gx * gx;
                    gy2 = gy * gy;
                    gxy = gx * gy;
                    
                    sum_gx2 = 0;
                    sum_gy2 = 0;
                    sum_gxy = 0;
                    
                    for (k = 0; k < 9; k = k + 1) begin
                        win_x = (k % 3) - 1;
                        win_y = (k / 3) - 1;
                        
                        actual_x = pixel_x + win_x;
                        actual_y = pixel_y + win_y;
                        
                        if (actual_x >= 0 && actual_x < width && 
                            actual_y >= 0 && actual_y < height) begin
                            
                            for (sobel_i = 0; sobel_i < 9; sobel_i = sobel_i + 1) begin
                                sobel_win_x = actual_x + (sobel_i % 3) - 1;
                                sobel_win_y = actual_y + (sobel_i / 3) - 1;
                                
                                if (sobel_win_x >= 0 && sobel_win_x < width && 
                                    sobel_win_y >= 0 && sobel_win_y < height) begin
                                    sobel_window[sobel_i] = source_image[sobel_win_y * width + sobel_win_x];
                                end else begin
                                    sobel_window[sobel_i] = 0;
                                end
                            end
                            
                            gx = (sobel_window[2] - sobel_window[0]) + 
                                 ((sobel_window[5] - sobel_window[3]) * 2) +
                                 (sobel_window[8] - sobel_window[6]);
                            
                            gy = (sobel_window[6] - sobel_window[0]) + 
                                 ((sobel_window[7] - sobel_window[1]) * 2) +
                                 (sobel_window[8] - sobel_window[2]);
                            
                            sum_gx2 = sum_gx2 + gx * gx;
                            sum_gy2 = sum_gy2 + gy * gy;
                            sum_gxy = sum_gxy + gx * gy;
                        end
                    end
                    
                    det = sum_gx2 * sum_gy2 - sum_gxy * sum_gxy;
                    
                    trace = sum_gx2 + sum_gy2;
                    trace_squared = trace * trace;
                    
                    harris_response = det - ((K_PARAM * trace_squared) >> 16);
                    
                    if (harris_response > 1000 || harris_response < -1000) begin
                        $display("Response value: Position(%0d,%0d), Response=%0d, det=%0d, trace=%0d", 
                                 pixel_x, pixel_y, harris_response, det, trace);
                    end
                    
                    if (harris_response > THRESHOLD) begin
                        output_image[i] = 8'hFF;
                        corner_count = corner_count + 1;
                        
                        if (corner_count < 10) begin
                            $display("Corner detected: Position(%0d,%0d), Response=%0d", 
                                     pixel_x, pixel_y, harris_response);
                        end
                    end else begin
                        output_image[i] = source_image[i];
                    end
                end else begin
                    output_image[i] = source_image[i];
                end
            end
            
            if (pixel_y % 50 == 0) begin
                $display("Processing progress: Row %0d/%0d", pixel_y, height);
            end
        end
        
        $display("=== Harris Corner Detection Completed ===");
        $display("Number of corners detected: %0d", corner_count);
        $display("Threshold setting: %0d", THRESHOLD);
        $display("K parameter: %0d", K_PARAM);
    end
endtask

task process_pgm_image;
    input [1023:0] input_filename;
    input [1023:0] output_filename;
    
    integer width, height, max_val;
    integer i, pixel_val;
    integer scan_result;
    integer actual_image_size;
    reg [1023:0] line_buffer;
    reg [15:0] magic;
    reg exit_loop;
    reg [7:0] char;
    begin
        $display("=== Starting Image File Processing: %s ===", input_filename);
        
        pgm_file_in = $fopen(input_filename, "r");
        if (pgm_file_in == 0) begin
            $display("Error: Cannot open input file %s", input_filename);
            $fclose(pgm_file_in);
            disable process_pgm_image;
        end
        
        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file_in, "%s", magic);
            if (scan_result == 0) begin
                char = $fgetc(pgm_file_in);
                if (char == "#") while ($fgetc(pgm_file_in) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        
        if (magic != "P2") begin
            $display("Error: File expected P2 format, got %s", magic);
            $fclose(pgm_file_in);
            disable process_pgm_image;
        end
        
        $display("Detected PGM format: %s", magic);
        
        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file_in, "%d %d", width, height);
            if (scan_result != 2) begin
                char = $fgetc(pgm_file_in);
                if (char == "#") while ($fgetc(pgm_file_in) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file_in, "%d", max_val);
            if (scan_result != 1) begin
                char = $fgetc(pgm_file_in);
                if (char == "#") while ($fgetc(pgm_file_in) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        
        $display("Image dimensions: %0d x %0d, Max value: %0d", width, height, max_val);
        
        actual_image_size = width * height;
        
        for (i = 0; i < actual_image_size; i = i + 1) begin
            scan_result = $fscanf(pgm_file_in, "%d", pixel_val);
            if (scan_result != 1) begin
                $display("Error: Failed to read pixel data");
                $fclose(pgm_file_in);
                disable process_pgm_image;
            end
            source_image[i] = pixel_val;
        end
        
        $fclose(pgm_file_in);
        $display("Pixel reading completed: %0d pixels", actual_image_size);
        
        harris_corner_detection(width, height);
        
        pgm_file_out = $fopen(output_filename, "w");
        if (pgm_file_out == 0) begin
            $display("Error: Cannot create output file %s", output_filename);
            $fclose(pgm_file_out);
            disable process_pgm_image;
        end
        
        $fdisplay(pgm_file_out, "P2");
        $fdisplay(pgm_file_out, "%0d %0d", width, height);
        $fdisplay(pgm_file_out, "255");
        
        for (i = 0; i < actual_image_size; i = i + 1) begin
            if (i % width == 0) begin
                $fdisplay(pgm_file_out);
            end
            $fwrite(pgm_file_out, "%0d ", output_image[i]);
        end
        
        $fclose(pgm_file_out);
        $display("Output file writing completed: %s", output_filename);
        $display("=== Image Processing Completed ===");
    end
endtask

endmodule