`timescale 1ns/1ps

module tb_simple_barrel_distortion;

reg clk;
reg rst_n;

reg [23:0] pixel_in;
reg pixel_valid;
reg frame_start;
reg frame_end;

wire [23:0] pixel_out;
wire pixel_out_valid;
wire frame_out_start;
wire frame_out_end;

parameter WIDTH = 320;
parameter HEIGHT = 466;
parameter DATA_WIDTH = 24;
parameter DISTORTION_K1 = 8'h40;

simple_barrel_distortion #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .DATA_WIDTH(DATA_WIDTH),
    .DISTORTION_K1(DISTORTION_K1)
) u_simple_barrel_distortion (
    .clk(clk),
    .rst_n(rst_n),
    .pixel_in(pixel_in),
    .pixel_valid(pixel_valid),
    .frame_start(frame_start),
    .frame_end(frame_end),
    .pixel_out(pixel_out),
    .pixel_out_valid(pixel_out_valid),
    .frame_out_start(frame_out_start),
    .frame_out_end(frame_out_end)
);

integer x, y;
reg [23:0] test_pixel;
integer pixel_count;

integer input_file, output_file;
integer width, height, max_val;
integer i, j, r_val, g_val, b_val, scan_result;
reg [7:0] char;
reg [15:0] magic;
reg exit_loop;
reg file_end;
reg [23:0] rgb_pixel;
reg [23:0] output_pixel;

initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;  
end

initial begin
    rst_n = 1'b0;
    pixel_in = 24'd0;
    pixel_valid = 1'b0;
    frame_start = 1'b0;
    frame_end = 1'b0;

    #100;
    rst_n = 1'b1;  
    #100;

    $display("=== Starting simplified barrel distortion correction test ===");
    
    $display("=== Basic function test ===");
    test_basic_function();
    #100;

    $display("=== Image file processing test ===");
    process_ppm_image("data/rgb1.ppm",
                     "output/out_rgb1_simple_corrected.ppm");
    #100;

    $display("=== All tests completed ===");
    #1000;
    $finish;
end

task test_basic_function;
    integer timeout_counter;
    reg error_flag;
    reg frame_start_detected;
    begin
        $display("Starting basic function test...");
        error_flag = 1'b0;
        frame_start_detected = 1'b0;
        
        @(posedge clk);
        frame_start <= 1'b1;
        pixel_valid <= 1'b1;
        pixel_in <= 24'hFF0000;  
        @(posedge clk);
        frame_start <= 1'b0;
        
        fork
            begin
                for (y = 0; y < HEIGHT; y = y + 1) begin
                    for (x = 0; x < WIDTH; x = x + 1) begin
                        test_pixel = {8'hFF, x[7:0], y[7:0]};
                        
                        pixel_in <= test_pixel;
                        pixel_valid <= 1'b1;
                        
                        if (x == WIDTH - 1 && y == HEIGHT - 1) begin
                            frame_end <= 1'b1;
                        end else begin
                            frame_end <= 1'b0;
                        end
                        
                        @(posedge clk);
                    end
                end
                
                pixel_valid <= 1'b0;
                frame_end <= 1'b0;
                $display("Test frame transmission completed");
            end
            
            begin
                timeout_counter = 0;
                while (!frame_out_start && timeout_counter < WIDTH * HEIGHT * 2) begin
                    @(posedge clk);
                    timeout_counter = timeout_counter + 1;
                end
                
                if (timeout_counter >= WIDTH * HEIGHT * 2) begin
                    $display("Error: Frame start timeout, module may not have started correctly");
                    $display("Current state: state=%d, frame_active=%d", u_simple_barrel_distortion.state, u_simple_barrel_distortion.frame_active);
                    error_flag = 1'b1;
                end else begin
                    frame_start_detected = 1'b1;
                    $display("Frame start signal detected, wait time: %d cycles", timeout_counter);
                end
            end
        join
        
        if (!error_flag && frame_start_detected) begin
            pixel_count = 0;
            $display("Starting to receive corrected frame data...");
            
            for (y = 0; y < HEIGHT; y = y + 1) begin
                for (x = 0; x < WIDTH; x = x + 1) begin
                    timeout_counter = 0;
                    while (!pixel_out_valid && timeout_counter < 100) begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;
                    end
                    
                    if (timeout_counter >= 100) begin
                        $display("Error: Pixel data timeout at (%d, %d)", x, y);
                        error_flag = 1'b1;
                        disable test_basic_function;
                    end
                    
                    pixel_count = pixel_count + 1;
                    
                    if (pixel_count % 10000 == 0) begin
                        $display("Received %d pixels...", pixel_count);
                    end
                    
                    @(posedge clk);
                end
            end
            
            if (!error_flag) begin
                $display("Frame reception completed, total received %d pixels", pixel_count);
                $display("Basic function test completed");
            end else begin
                $display("Basic function test failed");
            end
        end else begin
            $display("Basic function test failed");
        end
    end
endtask

task process_ppm_image;
    input [80*8-1:0] input_filename;
    input [80*8-1:0] output_filename;
    integer timeout_counter;
    reg error_flag;
    reg frame_start_detected;
    begin
        $display("Processing image file: %s -> %s", input_filename, output_filename);
        error_flag = 1'b0;
        frame_start_detected = 1'b0;
        
        input_file = $fopen(input_filename, "r");
        if (input_file == 0) begin
            $display("Error: Cannot open input file %s", input_filename);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(input_file, "%s", magic);
            if (scan_result == 0) begin
                char = $fgetc(input_file);
                if (char == "#") while ($fgetc(input_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        
        if (magic != "P3") begin
            $display("Error: Expected P3 format, got %s", magic);
            $fclose(input_file);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(input_file, "%d %d", width, height);
            if (scan_result != 2) begin
                char = $fgetc(input_file);
                if (char == "#") while ($fgetc(input_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(input_file, "%d", max_val);
            if (scan_result != 1) begin
                char = $fgetc(input_file);
                if (char == "#") while ($fgetc(input_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        $display("Image dimensions: %dx%d, maximum pixel value: %d", width, height, max_val);

        output_file = $fopen(output_filename, "w");
        if (output_file == 0) begin
            $display("Error: Cannot create output file %s", output_filename);
            $fclose(input_file);
            $finish;
        end

        $fdisplay(output_file, "P3");
        $fdisplay(output_file, "%d %d", width, height);
        $fdisplay(output_file, "%d", max_val);

        pixel_count = 0;
        file_end = 1'b0;

        @(posedge clk);
        frame_start <= 1'b1;
        pixel_valid <= 1'b1;
        @(posedge clk);
        frame_start <= 1'b0;

        fork
            begin
                for (j = 0; j < height; j = j + 1) begin
                    for (i = 0; i < width; i = i + 1) begin
                        scan_result = $fscanf(input_file, "%d %d %d", r_val, g_val, b_val);
                        if (scan_result != 3) begin
                            $display("Error: Failed to read pixel data");
                            file_end = 1'b1;
                            error_flag = 1'b1;
                            disable process_ppm_image;
                        end

                        rgb_pixel = {r_val[7:0], g_val[7:0], b_val[7:0]};
                        pixel_in <= rgb_pixel;
                        pixel_valid <= 1'b1;

                        if (i == width - 1 && j == height - 1) begin
                            frame_end <= 1'b1;
                        end else begin
                            frame_end <= 1'b0;
                        end

                        @(posedge clk);
                        pixel_count = pixel_count + 1;

                        if (pixel_count % 1000 == 0) begin
                            $display("Sent %d pixels...", pixel_count);
                        end
                    end
                end
                
                pixel_valid <= 1'b0;
                frame_end <= 1'b0;
                $display("Image data transmission completed, total %d pixels", pixel_count);
            end
            
            begin
                timeout_counter = 0;
                while (!frame_out_start && timeout_counter < width * height * 2) begin
                    @(posedge clk);
                    timeout_counter = timeout_counter + 1;
                end
                
                if (timeout_counter >= width * height * 2) begin
                    $display("Error: Frame start timeout, module may not have started correctly");
                    error_flag = 1'b1;
                end else begin
                    frame_start_detected = 1'b1;
                    $display("Frame start signal detected, wait time: %d cycles", timeout_counter);
                end
            end
        join
        
        if (!error_flag && frame_start_detected) begin
            pixel_count = 0;
            $display("Starting to receive corrected image data...");

            for (j = 0; j < height; j = j + 1) begin
                for (i = 0; i < width; i = i + 1) begin
                    timeout_counter = 0;
                    while (!pixel_out_valid && timeout_counter < 100) begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;
                    end

                    if (timeout_counter >= 100) begin
                        $display("Error: Pixel data timeout at (%d, %d)", i, j);
                        error_flag = 1'b1;
                        disable process_ppm_image;
                    end

                    output_pixel = pixel_out;
                    $fwrite(output_file, "%d %d %d ", 
                            output_pixel[23:16], 
                            output_pixel[15:8], 
                            output_pixel[7:0]);

                    pixel_count = pixel_count + 1;

                    if (pixel_count % 1000 == 0) begin
                        $display("Received %d pixels...", pixel_count);
                    end

                    @(posedge clk);
                end
                $fdisplay(output_file, "");  
            end
            
            if (!error_flag) begin
                $display("Image reception completed, total %d pixels", pixel_count);
                $display("Image processing completed: %s", output_filename);
            end else begin
                $display("Image processing failed");
            end
        end else begin
            $display("Image processing failed");
        end

        $fclose(input_file);
        $fclose(output_file);
    end
endtask

endmodule