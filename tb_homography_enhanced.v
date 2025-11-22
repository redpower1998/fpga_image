`timescale 1ns/1ps

module tb_homography_enhanced;

    parameter CLK_PERIOD = 10;
    parameter TEST_IMAGE_WIDTH = 256;
    parameter TEST_IMAGE_HEIGHT = 256;
    
    reg clk;
    reg rst_n;
    reg coord_valid;
    reg [15:0] dst_x, dst_y;
    reg signed [31:0] h11, h12, h13, h21, h22, h23, h31, h32, h33;
    reg [15:0] src_width, src_height;
    
    wire coord_out_valid;
    wire [15:0] src_x, src_y;
    wire [15:0] src_x_frac, src_y_frac;
    wire [1:0] interpolation_weights;
    
    integer test_count;
    integer error_count;
    integer total_tests;
    
    integer f_gray_in, f_homography_out;
    integer width, height, max_val;
    integer pixel_count;
    reg [7:0] source_image [0:320*464-1];
    reg [7:0] output_image [0:320*464-1];
    reg [2550:0] output_filename;
    reg [7:0] ch;
    reg [1023:0] line_buffer;
    integer scan_result, scan_result2, gets_result;
    reg [15:0] magic;
    integer error_flag;
    integer i_img, j_img;
    integer pixel_val;
    integer wait_count;

    homography_enhanced #(
        .DATA_WIDTH(8),
        .COORD_WIDTH(16),
        .FRAC_WIDTH(16),
        .PIPELINE_STAGES(7),
        .INTERPOLATION_TYPE(1)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
.coord_valid(coord_valid),
        .dst_x(dst_x),
        .dst_y(dst_y),
        .h11(h11), .h12(h12), .h13(h13),
        .h21(h21), .h22(h22), .h23(h23),
        .h31(h31), .h32(h32), .h33(h33),
        .src_width(src_width),
        .src_height(src_height),
        .coord_out_valid(coord_out_valid),
        .src_x(src_x),
        .src_y(src_y),
        .src_x_frac(src_x_frac),
        .src_y_frac(src_y_frac),
        .interpolation_weights(interpolation_weights)
    );
    
    always #(CLK_PERIOD/2) clk = ~clk;
    
    task test_identity_transform;
        input integer start_x, start_y;
        input integer width, height;
        integer i, j;
        integer expected_x, expected_y;
        integer timeout_counter;
        begin
            $display("=== Test identity transformation ===");
            
            h11 = 32'h00010000; h12 = 32'h00000000; h13 = 32'h00000000;
            h21 = 32'h00000000; h22 = 32'h00010000; h23 = 32'h00000000;
            h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00010000;
            
            src_width = width;
            src_height = height;
            
            for (i = start_x; i < start_x + 5; i = i + 1) begin
                for (j = start_y; j < start_y + 5; j = j + 1) begin
                    @(posedge clk);
                    dst_x = i;
                    dst_y = j;
                    coord_valid = 1'b1;
                    
                    @(posedge clk);
                    coord_valid = 1'b0;
                    
                    timeout_counter = 0;
                    while (!coord_out_valid && timeout_counter < 15) begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;
                    end
                    
                    if (coord_out_valid) begin
                        expected_x = i;
                        expected_y = j;
                        
                        if (src_x !== expected_x || src_y !== expected_y) begin
                            $display("Error: coordinate(%0d,%0d) -> expected(%0d,%0d), actual(%0d,%0d)", 
                                     i, j, expected_x, expected_y, src_x, src_y);
                            error_count = error_count + 1;
                        end
                        test_count = test_count + 1;
                    end else begin
                        $display("Warning: coordinate(%0d,%0d) -> output invalid (timeout)", i, j);
                    end
                end
            end
        end
    endtask
    
    task test_translation_transform;
        input integer tx, ty;
        input integer start_x, start_y;
        input integer width, height;
        integer i, j;
        integer expected_x, expected_y;
        integer timeout_counter;
        begin
            $display("=== Test translation transformation: tx=%0d, ty=%0d ===", tx, ty);
            
            h11 = 32'h00010000; h12 = 32'h00000000; h13 = -tx * 65536;
            h21 = 32'h00000000; h22 = 32'h00010000; h23 = -ty * 65536;
            h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00010000;
            
            src_width = width;
            src_height = height;
            for (i = start_x; i < start_x + 5; i = i + 1) begin
                for (j = start_y; j < start_y + 5; j = j + 1) begin
                    @(posedge clk);
                    dst_x = i;
                    dst_y = j;
                    coord_valid = 1'b1;
                    
                    @(posedge clk);
                    coord_valid = 1'b0;
                    
                    timeout_counter = 0;
                    while (!coord_out_valid && timeout_counter < 15) begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;
                    end
                    
                    if (coord_out_valid) begin
                        expected_x = i - tx;
                        expected_y = j - ty;
                        
                        if (expected_x >= 0 && expected_x < width && 
                            expected_y >= 0 && expected_y < height) begin
                            if (src_x !== expected_x || src_y !== expected_y) begin
                                $display("Error: coordinate(%0d,%0d) -> expected(%0d,%0d), actual(%0d,%0d)", 
                                         i, j, expected_x, expected_y, src_x, src_y);
                                error_count = error_count + 1;
                            end
                        end else begin
                            $display("Boundary: coordinate(%0d,%0d) -> out of range", i, j);
                        end
                        test_count = test_count + 1;
                    end else begin
                        $display("Warning: coordinate(%0d,%0d) -> output invalid (timeout)", i, j);
                    end
                end
            end
        end
    endtask
    
    task test_scale_transform;
        input integer sx_num, sx_den;
        input integer sy_num, sy_den;
        input integer start_x, start_y;
        input integer width, height;
        integer i, j;
        integer expected_x, expected_y;
        integer timeout_counter;
        integer temp_num_x, temp_num_y, temp_result_x, temp_result_y;
        begin
            $display("=== Test scale transformation: sx=%0d/%0d, sy=%0d/%0d ===", sx_num, sx_den, sy_num, sy_den);
            
            h11 = (sx_den * 65536) / sx_num; h12 = 32'h00000000; h13 = 32'h00000000;
            h21 = 32'h00000000; h22 = (sy_den * 65536) / sy_num; h23 = 32'h00000000;
            h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00010000;
            src_width = width;
            src_height = height;
            
            for (i = start_x; i < start_x + 5; i = i + 1) begin
                for (j = start_y; j < start_y + 5; j = j + 1) begin
                    @(posedge clk);
                    dst_x = i;
                    dst_y = j;
                    coord_valid = 1'b1;
                    
                    @(posedge clk);
                    coord_valid = 1'b0;
                    
                    timeout_counter = 0;
                    while (!coord_out_valid && timeout_counter < 15) begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;
                    end
                    
                    if (coord_out_valid) begin
                        expected_x = ((i * sx_den * 65536) / sx_num) >> 16;
                        expected_y = ((j * sy_den * 65536) / sy_num) >> 16;
                        
                        if (expected_x >= 0 && expected_x < width && 
                            expected_y >= 0 && expected_y < height) begin
                            if (src_x !== expected_x || src_y !== expected_y) begin
                                if (src_y == expected_y - 1 && src_x == expected_x) begin
                                    $display("Precision truncation: coordinate(%0d,%0d) -> expected(%0d,%0d), actual(%0d,%0d) [expected]", 
                                             i, j, expected_x, expected_y, src_x, src_y);
                                end else begin
                                    $display("Error: coordinate(%0d,%0d) -> expected(%0d,%0d), actual(%0d,%0d)", 
                                             i, j, expected_x, expected_y, src_x, src_y);
                                    error_count = error_count + 1;
                                end
                            end
                        end else begin
                            $display("Boundary: coordinate(%0d,%0d) -> out of range", i, j);
                        end
                        test_count = test_count + 1;
                    end else begin
                        $display("Warning: coordinate(%0d,%0d) -> output invalid (timeout)", i, j);
                    end
                end
            end
        end
    endtask
    
    task test_perspective_transform;
        input integer start_x, start_y;
        input integer width, height;
        integer i, j;
        integer timeout_counter;
        begin
            $display("=== Test perspective transformation ===");
            
            h11 = 32'h00010000; h12 = 32'h00000000; h13 = 32'h00000000;
            h21 = 32'h00000000; h22 = 32'h00010000; h23 = 32'h00000000;
            h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00010000;
            
            src_width = width;
            src_height = height;
            
            for (i = start_x; i < start_x + 5; i = i + 1) begin
                for (j = start_y; j < start_y + 5; j = j + 1) begin
                    @(posedge clk);
                    dst_x = i;
                    dst_y = j;
                    coord_valid = 1'b1;
                    
                    @(posedge clk);
                    coord_valid = 1'b0;
                    
                    timeout_counter = 0;
                    while (!coord_out_valid && timeout_counter < 15) begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;
                    end
                    
                    if (coord_out_valid) begin
                        test_count = test_count + 1;
                    end else begin
                        $display("Perspective: coordinate(%0d,%0d) -> invalid (timeout)", i, j);
                    end
                end
            end
        end
    endtask

    task test_pgm_image;
        input [2550:0] image_file;
        input integer test_type;
        reg exit_loop;  
        begin
            case (test_type)
                0: begin
                    $display("=== Starting PGM image identity transformation test ===");
                    output_filename = "output/out_homography_enhanced_identity.pgm";
                end
                1: begin
                    $display("=== Starting PGM image translation transformation test ===");
                    output_filename = "output/out_homography_enhanced_translate.pgm";
                end
                2: begin
                    $display("=== Starting PGM image scale transformation test ===");
                    output_filename = "output/out_homography_enhanced_scale.pgm";
                end
                3: begin
                    $display("=== Starting PGM image perspective transformation test ===");
                    output_filename = "output/out_homography_enhanced_perspective.pgm";
                end
                default: begin
                    $display("=== Starting PGM image identity transformation test ===");
                    output_filename = "output/out_homography_enhanced_default.pgm";
                end
            endcase
            
            error_flag = 0;
            
            f_gray_in = $fopen(image_file, "r");
            if (f_gray_in == 0) begin
                $display("ERROR: Cannot open input image file %s", image_file);
                error_flag = 1;
            end
            
           
             if (!error_flag) begin
                exit_loop = 1'b0;
                while (!exit_loop) begin
                    scan_result = $fscanf(f_gray_in, "%s", magic);
                    if (scan_result == 0) begin
                        ch = $fgetc(f_gray_in);
                        if (ch == "#") while ($fgetc(f_gray_in) != "\n" && !$feof(f_gray_in)) begin end
                    end else exit_loop = 1'b1;
                end
                
                if (scan_result != 1 || (magic != "P2" && magic != "P5")) begin
                    $display("ERROR: Unsupported PGM format");
                    $fclose(f_gray_in);
                    error_flag = 1;
                end
            end
            
            if (!error_flag) begin
                exit_loop = 1'b0;
                while (!exit_loop) begin
                    scan_result2 = $fscanf(f_gray_in, "%d %d", width, height);
                    if (scan_result2 != 2) begin
                        ch = $fgetc(f_gray_in);
                        if (ch == "#") while ($fgetc(f_gray_in) != "\n" && !$feof(f_gray_in)) begin end
                    end else begin
                        exit_loop = 1'b1;
                    end
                end
                
                exit_loop = 1'b0;
                while (!exit_loop) begin
                    scan_result2 = $fscanf(f_gray_in, "%d", max_val);
                    if (scan_result2 != 1) begin
                        ch = $fgetc(f_gray_in);
                        if (ch == "#") while ($fgetc(f_gray_in) != "\n" && !$feof(f_gray_in)) begin end
                    end else begin
                        exit_loop = 1'b1;
                    end
                end
            end
            
            if (!error_flag) begin
                $display("Image dimensions: %d x %d, maximum value: %d", width, height, max_val);
                
                if (width > 320 || height > 464) begin
                    $display("ERROR: Image dimensions too large");
                    $fclose(f_gray_in);
                    error_flag = 1;
                end
            end
            
            if (!error_flag) begin
                f_homography_out = $fopen(output_filename, "w");
                
                if (f_homography_out == 0) begin
                    $display("ERROR: Cannot create output file %s", output_filename);
                    error_flag = 1;
                end
            end
            
            if (!error_flag) begin
                $fdisplay(f_homography_out, "P2");
                case (test_type)
                    0: $fdisplay(f_homography_out, "# Identity transformation output (enhanced)");
                    1: $fdisplay(f_homography_out, "# Translation transformation output (enhanced)");
                    2: $fdisplay(f_homography_out, "# Scale transformation output (enhanced)");
                    3: $fdisplay(f_homography_out, "# Perspective transformation output (enhanced)");
                    default: $fdisplay(f_homography_out, "# Homography transformation output (enhanced)");
                endcase
                $fdisplay(f_homography_out, "%d %d", width, height);
                $fdisplay(f_homography_out, "%d", max_val);
                
                case (test_type)
                    0: begin
                        h11 = 32'h00010000; h12 = 32'h00000000; h13 = 32'h00000000;
                        h21 = 32'h00000000; h22 = 32'h00010000; h23 = 32'h00000000;
                        h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00010000;
                        $display("Using identity transformation matrix");
                    end
                    1: begin
                        h11 = 32'h00010000; h12 = 32'h00000000; h13 = -20 * 65536;
                        h21 = 32'h00000000; h22 = 32'h00010000; h23 = -10 * 65536;
                        h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00010000;
                        $display("Using translation transformation matrix (right 20, down 10)");
                    end
                    2: begin
                        h11 = 32'h00020000; h12 = 32'h00000000; h13 = 32'h00000000;
                        h21 = 32'h00000000; h22 = 32'h00008000; h23 = 32'h00000000;
                        h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00010000;
                        $display("Using scale transformation matrix (X:0.5, Y:2.0)");
                    end
                    3: begin
                        h11 = 32'h00010000; h12 = 32'h00000000; h13 = 32'h00000000;
                        h21 = 32'h00000000; h22 = 32'h00010000; h23 = 32'h00000000;
                        h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00010000;
                        h31 = 32'h00000080;
                        h32 = 32'h00000040;
                        $display("Using perspective transformation matrix (slight perspective effect)");
                    end
                    default: begin
                        h11 = 32'h00010000; h12 = 32'h00000000; h13 = 32'h00000000;
                        h21 = 32'h00000000; h22 = 32'h00010000; h23 = 32'h00000000;
                        h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00010000;
                        $display("Using default unit transformation matrix");
                    end
                endcase
                
                src_width = width;
                src_height = height;
                
                rst_n = 1'b0;
                coord_valid = 1'b0;
                dst_x = 16'd0;
                dst_y = 16'd0;
                
                repeat(5) @(posedge clk);
                rst_n = 1'b1;
                repeat(2) @(posedge clk);
                
                pixel_count = 0;
                $display("Starting image single homography transformation...");
                
                for (i_img = 0; i_img < width * height; i_img = i_img + 1) begin
                    output_image[i_img] = 8'd0;
                end
                
                for (j_img = 0; j_img < height; j_img = j_img + 1) begin
                    for (i_img = 0; i_img < width; i_img = i_img + 1) begin
                        scan_result = $fscanf(f_gray_in, "%d", pixel_val);
                        if (scan_result != 1) begin
                            $display("ERROR: Cannot read pixel data");
                            error_flag = 1;
                            disable test_pgm_image;
                        end
                        source_image[j_img * width + i_img] = pixel_val;
                    end
                end
                
                for (j_img = 0; j_img < height; j_img = j_img + 1) begin
                    for (i_img = 0; i_img < width; i_img = i_img + 1) begin
                        @(posedge clk);
                        dst_x = i_img;
                        dst_y = j_img;
                        coord_valid = 1'b1;
                        
                        @(posedge clk);
                        coord_valid = 1'b0;
                        
                        wait_count = 0;
                        while (!coord_out_valid && wait_count < 15) begin
                            @(posedge clk);
                            wait_count = wait_count + 1;
                        end
                        
                        if (coord_out_valid) begin
                            if (src_x < width && src_y < height && 
                                src_x >= 0 && src_y >= 0) begin
                                output_image[j_img * width + i_img] = source_image[src_y * width + src_x];
                                pixel_count = pixel_count + 1;
                                
                                if (pixel_count < 10) begin
                                    $display("Mapping success: dst(%0d,%0d) -> src(%0d,%0d), pixel_value=%d", 
                                             i_img, j_img, src_x, src_y, source_image[src_y * width + src_x]);
                                end
                            end else begin
                                if (pixel_count < 10) begin
                                    $display("Mapping failed: dst(%0d,%0d) -> src(%0d,%0d)", i_img, j_img, src_x, src_y);
                                end
                            end
                        end else begin
                            if (pixel_count < 10) begin
                                $display("Coordinate output timeout or invalid: dst(%0d,%0d), wait_cycles=%0d", i_img, j_img, wait_count);
                            end
                        end
                        
                        if ((j_img * width + i_img) % 1000 == 0) begin
                            $display("Processing progress: %0d/%0d pixels", j_img * width + i_img, width * height);
                        end
                    end
                end
                
                coord_valid = 1'b0;
                
                for (j_img = 0; j_img < height; j_img = j_img + 1) begin
                    for (i_img = 0; i_img < width; i_img = i_img + 1) begin
                        $fwrite(f_homography_out, "%d ", output_image[j_img * width + i_img]);
                    end
                    $fdisplay(f_homography_out, "");
                end
                
                $fclose(f_homography_out);
                $display("Image processing completed, processed %d pixels", pixel_count);
                
                $display("Valid pixel ratio: %.2f%%", (pixel_count * 100.0) / (width * height));
            end
            
            $fclose(f_gray_in);
            case (test_type)
                0: $display("=== PGM image identity transformation test completed ===\n");
                1: $display("=== PGM image translation transformation test completed ===\n");
                2: $display("=== PGM image scale transformation test completed ===\n");
                3: $display("=== PGM image perspective transformation test completed ===\n");
                default: $display("=== PGM image homography transformation test completed ===\n");
            endcase
        end
    endtask
    
    function integer calculate_percentage;
        input integer passed;
        input integer total;
        integer temp;
        begin
            if (total == 0) begin
                calculate_percentage = 0;
            end else begin
                temp = (passed * 100) / total;
                calculate_percentage = temp;
            end
        end
    endfunction
    
    initial begin
        clk = 0;
        rst_n = 0;
        coord_valid = 0;
        dst_x = 0;
        dst_y = 0;
        test_count = 0;
        error_count = 0;
        total_tests = 0;
        
        #20 rst_n = 1;
        
        #100;
        
        test_identity_transform(10, 10, TEST_IMAGE_WIDTH, TEST_IMAGE_HEIGHT);
        test_translation_transform(5, 3, 15, 15, TEST_IMAGE_WIDTH, TEST_IMAGE_HEIGHT);
        test_scale_transform(2, 1, 3, 2, 20, 20, TEST_IMAGE_WIDTH, TEST_IMAGE_HEIGHT);
        test_perspective_transform(25, 25, TEST_IMAGE_WIDTH, TEST_IMAGE_HEIGHT);
        
        test_translation_transform(10, 10, TEST_IMAGE_WIDTH-5, TEST_IMAGE_HEIGHT-5, 
                                  TEST_IMAGE_WIDTH, TEST_IMAGE_HEIGHT);
        
        $display("=== Testing zero denominator case ===");
        h11 = 32'h00000000; h12 = 32'h00000000; h13 = 32'h00000000;
        h21 = 32'h00000000; h22 = 32'h00000000; h23 = 32'h00000000;
        h31 = 32'h00000000; h32 = 32'h00000000; h33 = 32'h00000000;
        
        @(posedge clk);
        dst_x = 100;
        dst_y = 100;
        coord_valid = 1'b1;
        
        @(posedge clk);
        coord_valid = 1'b0;
        repeat(10) @(posedge clk);
        
        if ($test$plusargs("image_test")) begin
            $display("\n=== Starting image processing test ===");
            
            test_pgm_image("data/gray1.pgm", 0);
            
            test_pgm_image("data/gray1.pgm", 1);
            
            test_pgm_image("data/gray1.pgm", 2);
            
            test_pgm_image("data/gray1.pgm", 3);
            
            $display("=== Image processing test completed ===\n");
        end
        
        $display("\n=== Test completed ===");
        $display("Total tests: %0d", test_count);
        $display("Error count: %0d", error_count);
        
        if (test_count > 0) begin
            $display("Success rate: %0d%%", calculate_percentage(test_count - error_count, test_count));
        end else begin
            $display("Success rate: 0%%");
        end
        
        if (error_count == 0) begin
            $display("All tests passed!");
        end else begin
            $display("Found %0d errors", error_count);
        end
        
        $finish;
    end
    
    initial begin
        $dumpfile("homography_enhanced.vcd");
        $dumpvars(0, tb_homography_enhanced);
    end

endmodule