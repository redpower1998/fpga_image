`timescale 1ns/1ps

module tb_homography;

    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 8;
    parameter COORD_WIDTH = 16;
    parameter FRAC_WIDTH = 16;
    
    reg clk;
    reg rst_n;
    
    reg coord_valid;
    reg [COORD_WIDTH-1:0] dst_x_reg, dst_y_reg;
    
    reg [FRAC_WIDTH-1:0] h11, h12, h13;
    reg [FRAC_WIDTH-1:0] h21, h22, h23;
    reg [FRAC_WIDTH-1:0] h31, h32, h33;
    
    reg [COORD_WIDTH-1:0] src_width, src_height;
    
    wire coord_out_valid;
    wire [COORD_WIDTH-1:0] src_x, src_y;
    
    integer f_gray_in, f_homography_out;
    integer width, height, max_val;
    integer pixel_count;
    
    integer i, j;
    integer pixel_val;
    integer error_flag;
    integer center_x, center_y;
    
    reg [7:0] source_image [0:320*464-1];
    
    reg [7:0] ch;
    reg [1023:0] line_buffer;
    integer scan_result, scan_result2, gets_result;
    
    reg [15:0] magic;
    
    homography #(
        .DATA_WIDTH(DATA_WIDTH),
        .COORD_WIDTH(COORD_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) u_homography (
        .clk(clk),
        .rst_n(rst_n),
        .coord_valid(coord_valid),
        .dst_x(dst_x_reg),
        .dst_y(dst_y_reg),
        .h11(h11), .h12(h12), .h13(h13),
        .h21(h21), .h22(h22), .h23(h23),
        .h31(h31), .h32(h32), .h33(h33),
        .src_width(src_width),
        .src_height(src_height),
        .coord_out_valid(coord_out_valid),
        .src_x(src_x),
        .src_y(src_y)
    );
    
    always #(CLK_PERIOD/2) clk = ~clk;
    
    task test_basic_operations;
        begin
            $display("=== Starting basic homography transformation function test ===");
            
            rst_n = 1'b0;
            coord_valid = 1'b0;
            dst_x_reg = 16'd0;
            dst_y_reg = 16'd0;
            
            repeat(5) @(posedge clk);
            rst_n = 1'b1;
            repeat(2) @(posedge clk);
            
            $display("Test 1: Identity transformation test");
            
            h11 = 16'h0100;
            h12 = 16'h0000;
            h13 = 16'h0000;
            h21 = 16'h0000;
            h22 = 16'h0100;
            h23 = 16'h0000;
            h31 = 16'h0000;
            h32 = 16'h0000;
            h33 = 16'h0100;
            
            src_width = 320;
            src_height = 464;
            
            coord_valid = 1'b1;
            dst_x_reg = 16'd100;
            dst_y_reg = 16'd50;
            
            repeat(6) @(posedge clk);
            
            if (coord_out_valid) begin
                $display("Input: dst_x=%d, dst_y=%d", dst_x_reg, dst_y_reg);
                $display("Output: src_x=%d, src_y=%d", src_x, src_y);
                
                if (src_x == 100 && src_y == 50) begin
                    $display("PASS: Identity transformation test passed");
                end else begin
                    $display("FAIL: Identity transformation test failed, expected(%d,%d), actual(%d,%d)", 
                            100, 50, src_x, src_y);
                end
            end else begin
                $display("ERROR: Coordinate output invalid");
            end
            
            coord_valid = 1'b0;
            repeat(2) @(posedge clk);
            
            $display("Test 2: Translation transformation test");
            
            h11 = 16'h0100;
            h12 = 16'h0000;
            h13 = 16'h0A00;
            h21 = 16'h0000;
            h22 = 16'h0100;
            h23 = 16'h0500;
            h31 = 16'h0000;
            h32 = 16'h0000;
            h33 = 16'h0100;
            
            coord_valid = 1'b1;
            dst_x_reg = 16'd100;
            dst_y_reg = 16'd50;
            
            repeat(6) @(posedge clk);
            
            if (coord_out_valid) begin
                $display("Input: dst_x=%d, dst_y=%d", dst_x_reg, dst_y_reg);
                $display("Output: src_x=%d, src_y=%d", src_x, src_y);
                
                if (src_x == 90 && src_y == 45) begin
                    $display("PASS: Translation transformation test passed");
                end else begin
                    $display("INFO: Translation transformation test, expected(%d,%d), actual(%d,%d)", 
                            90, 45, src_x, src_y);
                end
            end
            
            coord_valid = 1'b0;
            repeat(2) @(posedge clk);
            
            $display("Test 3: Scale transformation test");
            
            h11 = 16'h00CD;
            h12 = 16'h0000;
            h13 = 16'h0000;
            h21 = 16'h0000;
            h22 = 16'h0133;
            h23 = 16'h0000;
            h31 = 16'h0000;
            h32 = 16'h0000;
            h33 = 16'h0100;
            
            coord_valid = 1'b1;
            dst_x_reg = 16'd100;
            dst_y_reg = 16'd50;
            
            repeat(6) @(posedge clk);
            
            if (coord_out_valid) begin
                $display("Input: dst_x=%d, dst_y=%d", dst_x_reg, dst_y_reg);
                $display("Output: src_x=%d, src_y=%d", src_x, src_y);
                
                $display("INFO: Scale transformation test, input(%d,%d), output(%d,%d)", 
                        100, 50, src_x, src_y);
            end
            
            coord_valid = 1'b0;
            repeat(2) @(posedge clk);
            
            $display("=== Basic homography transformation function test completed ===\n");
        end
    endtask
    
    task test_pgm_image;
        input [2550:0] image_file;
        input integer test_type;
        reg [7:0] output_image [0:320*464-1];
        reg [2550:0] output_filename;
        begin
            case (test_type)
                0: begin
                    $display("=== Starting PGM image identity transformation test ===");
                    output_filename = "output/out_homography_identity.pgm";
                end
                1: begin
                    $display("=== Starting PGM image translation transformation test ===");
                    output_filename = "output/out_homography_translate.pgm";
                end
                2: begin
                    $display("=== Starting PGM image scale transformation test ===");
                    output_filename = "output/out_homography_scale.pgm";
                end
                default: begin
                    $display("=== Starting PGM image identity transformation test ===");
                    output_filename = "output/out_homography_default.pgm";
                end
            endcase
            
            error_flag = 0;
            
            f_gray_in = $fopen(image_file, "r");
            if (f_gray_in == 0) begin
                $display("ERROR: Cannot open input image file %s", image_file);
                error_flag = 1;
            end
            
            if (!error_flag) begin
                scan_result = $fscanf(f_gray_in, "%s", magic);
                if (scan_result != 1 || (magic != "P2" && magic != "P5")) begin
                    $display("ERROR: Unsupported PGM format");
                    $fclose(f_gray_in);
                    error_flag = 1;
                end
            end
            
            if (!error_flag) begin
                scan_result = 0; 
                while (!$feof(f_gray_in) && scan_result != 1) begin
                    scan_result = $fscanf(f_gray_in, "%d", width);
                    if (scan_result != 1 && !$feof(f_gray_in)) begin  
                        ch = $fgetc(f_gray_in);
                        if (ch == "#") begin
                            while ($fgetc(f_gray_in) != "\n" && !$feof(f_gray_in)) begin end
                        end
                    end
                end
                
                if (scan_result != 1) begin
                    $display("ERROR: Cannot read image width");
                    $fclose(f_gray_in);
                    error_flag = 1;
                end
            end
            
            if (!error_flag) begin
                scan_result = 0;
                while (!$feof(f_gray_in) && scan_result != 1) begin
                    scan_result = $fscanf(f_gray_in, "%d", height);
                    if (scan_result != 1 && !$feof(f_gray_in)) begin 
                        ch = $fgetc(f_gray_in);
                        if (ch == "#") begin
                            while ($fgetc(f_gray_in) != "\n" && !$feof(f_gray_in)) begin end
                        end
                    end
                end
                
                if (scan_result != 1) begin
                    $display("ERROR: Cannot read image height");
                    $fclose(f_gray_in);
                    error_flag = 1;
                end
            end
            
            if (!error_flag) begin
                scan_result = 0;
                while (!$feof(f_gray_in) && scan_result != 1) begin
                    scan_result = $fscanf(f_gray_in, "%d", max_val);
                    if (scan_result != 1 && !$feof(f_gray_in)) begin  
                        ch = $fgetc(f_gray_in);
                        if (ch == "#") begin
                            while ($fgetc(f_gray_in) != "\n" && !$feof(f_gray_in)) begin end
                        end
                    end
                end
                
                if (scan_result != 1) begin
                    $display("ERROR: Cannot read image max value");
                    $fclose(f_gray_in);
                    error_flag = 1;
                end
            end
            
            if (!error_flag) begin
                $display("Image dimensions: %d x %d, Max value: %d", width, height, max_val);
                
                if (width > 320 || height > 464) begin
                    $display("ERROR: Image dimensions too large (max 320x464)");
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
                    0: $fdisplay(f_homography_out, "# Identity transformation output");
                    1: $fdisplay(f_homography_out, "# Translation transformation output");
                    2: $fdisplay(f_homography_out, "# Scale transformation output");
                    default: $fdisplay(f_homography_out, "# Homography transformation output");
                endcase
                $fdisplay(f_homography_out, "%d %d", width, height);
                $fdisplay(f_homography_out, "%d", max_val);
                
                case (test_type)
                    0: begin
                        h11 = 16'h0100; h12 = 16'h0000; h13 = 16'h0000;
                        h21 = 16'h0000; h22 = 16'h0100; h23 = 16'h0000;
                        h31 = 16'h0000; h32 = 16'h0000; h33 = 16'h0100;
                        $display("Using identity transformation matrix");
                    end
                    1: begin
                        h11 = 16'h0100; h12 = 16'h0000; h13 = 16'h1400;
                        h21 = 16'h0000; h22 = 16'h0100; h23 = 16'h0A00;
                        h31 = 16'h0000; h32 = 16'h0000; h33 = 16'h0100;
                        $display("Using translation transformation matrix (right 20, down 10)");
                    end
                    2: begin
                        h11 = 16'h00B3; h12 = 16'h0000; h13 = 16'h0000;
                        h21 = 16'h0000; h22 = 16'h014D; h23 = 16'h0000;
                        h31 = 16'h0000; h32 = 16'h0000; h33 = 16'h0100;
                        $display("Using scale transformation matrix (X:0.7, Y:1.3)");
                    end
                    default: begin
                        h11 = 16'h0100; h12 = 16'h0000; h13 = 16'h0000;
                        h21 = 16'h0000; h22 = 16'h0100; h23 = 16'h0000;
                        h31 = 16'h0000; h32 = 16'h0000; h33 = 16'h0100;
                        $display("Using default identity transformation matrix");
                    end
                endcase
                
                src_width = width;
                src_height = height;
                
                rst_n = 1'b0;
                coord_valid = 1'b0;
                dst_x_reg = 16'd0;
                dst_y_reg = 16'd0;
                
                repeat(5) @(posedge clk);
                rst_n = 1'b1;
                repeat(2) @(posedge clk);
                
                pixel_count = 0;
                $display("Starting image homography transformation processing...");
                
                for (i = 0; i < width * height; i = i + 1) begin
                    output_image[i] = 8'd0;
                end
                
                for (j = 0; j < height; j = j + 1) begin
                    for (i = 0; i < width; i = i + 1) begin
                        scan_result = $fscanf(f_gray_in, "%d", pixel_val);
                        if (scan_result != 1) begin
                            $display("ERROR: Failed to read pixel data");
                            error_flag = 1;
                            disable test_pgm_image;
                        end
                        source_image[j * width + i] = pixel_val;
                    end
                end
                
                for (j = 0; j < height; j = j + 1) begin
                    for (i = 0; i < width; i = i + 1) begin
                        coord_valid = 1'b1;
                        dst_x_reg = i;
                        dst_y_reg = j;
                        
                        repeat(6) @(posedge clk);
                        
                        if (coord_out_valid) begin
                            if (pixel_count < 10) begin
                                $display("Debug: dst(%d,%d) -> src(%d,%d), src_width=%d, src_height=%d", 
                                         i, j, src_x, src_y, width, height);
                            end
                            
                            if (src_x < width && src_y < height && 
                                src_x >= 0 && src_y >= 0) begin
                                output_image[j * width + i] = source_image[src_y * width + src_x];
                                pixel_count = pixel_count + 1;
                                
                                if (pixel_count < 10) begin
                                    $display("Mapping success: dst(%d,%d) -> src(%d,%d), pixel_value=%d", 
                                             i, j, src_x, src_y, source_image[src_y * width + src_x]);
                                end
                            end else begin
                                if (pixel_count < 10) begin
                                    $display("Mapping failed: dst(%d,%d) -> src(%d,%d)", i, j, src_x, src_y);
                                end
                            end
                        end else begin
                            if (pixel_count < 10) begin
                                $display("Coordinate output invalid: dst(%d,%d), h11=%h, h12=%h, h13=%h, h21=%h, h22=%h, h23=%h, h31=%h, h32=%h, h33=%h", 
                                         i, j, h11, h12, h13, h21, h22, h23, h31, h32, h33);
                            end
                        end
                    end
                end
                
                coord_valid = 1'b0;
                
                for (j = 0; j < height; j = j + 1) begin
                    for (i = 0; i < width; i = i + 1) begin
                        $fwrite(f_homography_out, "%d ", output_image[j * width + i]);
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
                default: $display("=== PGM image homography transformation test completed ===\n");
            endcase
        end
    endtask
    
    initial begin
        clk = 1'b0;
        
        test_basic_operations;
        
        if ($test$plusargs("image_test")) begin
            test_pgm_image("data/gray1.pgm", 0);
            
            test_pgm_image("data/gray1.pgm", 1);
            
            test_pgm_image("data/gray1.pgm", 2);
        end
        
        #100;
        $display("=== All tests completed ===");
        $finish;
    end
    
    initial begin
        $dumpfile("homography.vcd");
        $dumpvars(0, tb_homography);
    end

endmodule