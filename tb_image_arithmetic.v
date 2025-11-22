`timescale 1ns/1ps

module tb_image_arithmetic;

    reg clk;
    reg rst_n;
    
    reg pixel_valid;
    reg [7:0] pixel_a;
    reg [7:0] pixel_b;
    reg [1:0] operation;
    
    wire pixel_out_valid;
    wire [7:0] pixel_out;
    
    image_arithmetic #(
        .DATA_WIDTH(8),
        .OPERATION_WIDTH(2),
        .SCALE_FACTOR(8'd10)
    ) u_image_arithmetic (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .pixel_a(pixel_a),
        .pixel_b(pixel_b),
        .operation(operation),
        .pixel_out_valid(pixel_out_valid),
        .pixel_out(pixel_out)
    );
    
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst_n = 1'b0;
        pixel_valid = 1'b0;
        pixel_a = 8'd0;
        pixel_b = 8'd0;
        operation = 2'b00;
        
        #200;
        rst_n = 1'b1;
        #100;
        
        test_arithmetic_operations();
        
        test_image_add_operations();
        test_image_sub_operations();
        test_image_mul_operations();
        test_image_div_operations();
        
        #1000;
        $display("=== All tests completed ===");
        $finish;
    end
    
    task test_arithmetic_operations;
        integer i;
        reg [7:0] expected;
        begin
            $display("=== Starting basic arithmetic operations test ===");
            
            operation = 2'b00;
            $display("Testing addition operation:");
            for (i = 0; i < 10; i = i + 1) begin
                @(posedge clk);
                pixel_valid = 1'b1;
                pixel_a = i * 25;
                pixel_b = i * 10;
                
                expected = pixel_a + pixel_b;
                if (expected > 255) expected = 255;
                
                @(posedge clk);
                pixel_valid = 1'b0;
                
                repeat(2) @(posedge clk);
                
                if (pixel_out_valid) begin
                    $display("  %d + %d = %d (expected: %d)", pixel_a, pixel_b, pixel_out, expected);
                    if (pixel_out !== expected) begin
                        $display("  ERROR: Result mismatch!");
                    end
                end
                #20;
            end
            
            operation = 2'b01;
            $display("Testing subtraction operation:");
            for (i = 0; i < 10; i = i + 1) begin
                @(posedge clk);
                pixel_valid = 1'b1;
                pixel_a = i * 30;
                pixel_b = i * 10;
                
                if (pixel_a >= pixel_b) begin
                    expected = pixel_a - pixel_b;
                end else begin
                    expected = 0;
                end
                
                @(posedge clk);
                pixel_valid = 1'b0;
                
                repeat(2) @(posedge clk);
                
                if (pixel_out_valid) begin
                    $display("  %d - %d = %d (expected: %d)", pixel_a, pixel_b, pixel_out, expected);
                    if (pixel_out !== expected) begin
                        $display("  ERROR: Result mismatch!");
                    end
                end
                #20;
            end
            
            operation = 2'b10;
            $display("Testing multiplication operation:");
            for (i = 1; i <= 5; i = i + 1) begin
                @(posedge clk);
                pixel_valid = 1'b1;
                pixel_a = i * 20;
                pixel_b = i * 5;
                
                expected = (pixel_a * pixel_b) / 10;
                if (expected > 255) expected = 255;
                
                @(posedge clk);
                pixel_valid = 1'b0;
                
                repeat(2) @(posedge clk);
                
                if (pixel_out_valid) begin
                    $display("  (%d * %d) / 10 = %d (expected: %d)", pixel_a, pixel_b, pixel_out, expected);
                    if (pixel_out !== expected) begin
                        $display("  ERROR: Result mismatch!");
                    end
                end
                #20;
            end
            
            operation = 2'b11;
            $display("Testing division operation:");
            for (i = 1; i <= 5; i = i + 1) begin
                @(posedge clk);
                pixel_valid = 1'b1;
                pixel_a = i * 50;
                pixel_b = i * 5;
                
                if (pixel_b > 0) begin
                    expected = (pixel_a * 10) / pixel_b;
                    if (expected > 255) expected = 255;
                end else begin
                    expected = 255;
                end
                
                @(posedge clk);
                pixel_valid = 1'b0;
                
                repeat(2) @(posedge clk);
                
                if (pixel_out_valid) begin
                    $display("  (%d * 10) / %d = %d (expected: %d)", pixel_a, pixel_b, pixel_out, expected);
                    if (pixel_out !== expected) begin
                        $display("  ERROR: Result mismatch!");
                    end
                end
                #20;
            end
            
            $display("=== Basic arithmetic operations test completed ===");
        end
    endtask
    
    task test_image_add_operations;
        integer f_in1, f_out;
        integer width, height, max_val;
        integer i, j, pixel_val1, pixel_val2;
        reg [8*16-1:0] magic;
        integer scan_result;
        reg exit_loop;
        reg [7:0] char;
        reg [7:0] pixel_buffer [0:1];
        integer buffer_index;
        begin
            $display("=== Starting image file addition operation test ===");
            
            f_in1 = $fopen("data/gray1.pgm", "r");
            if (f_in1 == 0) begin
                $display("ERROR: Cannot open input file gray1.pgm");
                $finish;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%s", magic);
                if (scan_result == 0) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            if (magic != "P2") begin
                $display("ERROR: Only P2 format PGM files are supported");
                $fclose(f_in1);
                $finish;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d %d", width, height);
                if (scan_result != 2) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d", max_val);
                if (scan_result != 1) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            $display("Image dimensions: %dx%d, maximum pixel value: %d", width, height, max_val);
            
            f_out = $fopen("output/out_arithmetic_add_output.pgm", "w");
            $fdisplay(f_out, "P2");
            $fdisplay(f_out, "%d %d", width, height);
            $fdisplay(f_out, "255");
            
            operation = 2'b00;
            
            @(posedge clk);
            rst_n = 1'b0;
            pixel_valid = 1'b0;
            pixel_a = 0;
            pixel_b = 0;
            buffer_index = 0;
            @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            
            pixel_valid = 1'b1;
            
            for (i = 0; i < height; i = i + 1) begin
                for (j = 0; j < width; j = j + 1) begin
                    scan_result = $fscanf(f_in1, "%d", pixel_val1);
                    if (scan_result != 1) begin
                        $display("ERROR: File ended at pixel(%d,%d), but more data was expected", i, j);
                        $fclose(f_in1);
                        $fclose(f_out);
                        $finish;
                    end
                    
                    if (max_val != 255) begin
                        pixel_val1 = (pixel_val1 * 255) / max_val;
                        if (pixel_val1 < 0) pixel_val1 = 0;
                        if (pixel_val1 > 255) pixel_val1 = 255;
                    end
                    
                    pixel_val2 = 50;
                    
                    pixel_a = pixel_val1[7:0];
                    pixel_b = pixel_val2[7:0];
                    
                    pixel_buffer[buffer_index] = pixel_val1[7:0];
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                            
                            if (((i * width + j) % 100 == 0) && (j >= 2)) begin
                                $display("Addition operation - Processing pixel (%d,%d): A=%d, B=%d -> Result=%d", 
                                        i, j-2, pixel_buffer[(buffer_index + 1) % 2], pixel_val2, pixel_out);
                            end
                        end else begin
                            $display("WARNING: Pixel(%d,%d) output invalid, using original value", i, j-2);
                            $fwrite(f_out, "%d ", pixel_buffer[(buffer_index + 1) % 2]);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                for (j = width; j < width + 2; j = j + 1) begin
                    pixel_a = 0;
                    pixel_b = 0;
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                        end else begin
                            $display("WARNING: Row %d last pixel output invalid, using default value", i);
                            $fwrite(f_out, "%d ", 0);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                $fwrite(f_out, "\n");
            end
            
            pixel_valid = 1'b0;
            
            $fclose(f_in1);
            $fclose(f_out);
            
            $display("Addition operation image processing completed. Result saved to arithmetic_add_output.pgm");
        end
    endtask

    task test_image_sub_operations;
        integer f_in1, f_out;
        integer width, height, max_val;
        integer i, j, pixel_val1, pixel_val2;
        reg [8*16-1:0] magic;
        integer scan_result;
        reg exit_loop;
        reg [7:0] char;
        reg [7:0] pixel_buffer [0:1];
        integer buffer_index;
        begin
            $display("=== Starting image file subtraction operation test ===");
            
            f_in1 = $fopen("data/gray1.pgm", "r");
            if (f_in1 == 0) begin
                $display("ERROR: Cannot open input file gray1.pgm");
                $finish;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%s", magic);
                if (scan_result == 0) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d %d", width, height);
                if (scan_result != 2) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d", max_val);
                if (scan_result != 1) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            f_out = $fopen("output/out_arithmetic_sub_output.pgm", "w");
            $fdisplay(f_out, "P2");
            $fdisplay(f_out, "%d %d", width, height);
            $fdisplay(f_out, "255");
            
            operation = 2'b01;
            
            @(posedge clk);
            rst_n = 1'b0;
            pixel_valid = 1'b0;
            pixel_a = 0;
            pixel_b = 0;
            buffer_index = 0;
            @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            
            pixel_valid = 1'b1;
            
            for (i = 0; i < height; i = i + 1) begin
                for (j = 0; j < width; j = j + 1) begin
                    scan_result = $fscanf(f_in1, "%d", pixel_val1);
                    if (scan_result != 1) begin
                        $display("ERROR: File ended at pixel(%d,%d), but more data was expected", i, j);
                        $fclose(f_in1);
                        $fclose(f_out);
                        $finish;
                    end
                    
                    if (max_val != 255) begin
                        pixel_val1 = (pixel_val1 * 255) / max_val;
                        if (pixel_val1 < 0) pixel_val1 = 0;
                        if (pixel_val1 > 255) pixel_val1 = 255;
                    end
                    
                    pixel_val2 = 30;
                    
                    pixel_a = pixel_val1[7:0];
                    pixel_b = pixel_val2[7:0];
                    
                    pixel_buffer[buffer_index] = pixel_val1[7:0];
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                            
                            if (((i * width + j) % 100 == 0) && (j >= 2)) begin
                                $display("Subtraction operation - Processing pixel (%d,%d): A=%d, B=%d -> Result=%d", 
                                        i, j-2, pixel_buffer[(buffer_index + 1) % 2], pixel_val2, pixel_out);
                            end
                        end else begin
                            $display("WARNING: Pixel(%d,%d) output invalid, using original value", i, j-2);
                            $fwrite(f_out, "%d ", pixel_buffer[(buffer_index + 1) % 2]);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                for (j = width; j < width + 2; j = j + 1) begin
                    pixel_a = 0;
                    pixel_b = 0;
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                        end else begin
                            $display("WARNING: Row %d last pixel output invalid, using default value", i);
                            $fwrite(f_out, "%d ", 0);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                $fwrite(f_out, "\n");
            end
            
            pixel_valid = 1'b0;
            
            $fclose(f_in1);
            $fclose(f_out);
            
            $display("Subtraction operation image processing completed. Result saved to arithmetic_sub_output.pgm");
        end
    endtask

    task test_image_mul_operations;
        integer f_in1, f_out;
        integer width, height, max_val;
        integer i, j, pixel_val1, pixel_val2;
        reg [8*16-1:0] magic;
        integer scan_result;
        reg exit_loop;
        reg [7:0] char;
        reg [7:0] pixel_buffer [0:1];
        integer buffer_index;
        begin
            $display("=== Starting image file multiplication operation test ===");
            
            f_in1 = $fopen("data/gray1.pgm", "r");
            if (f_in1 == 0) begin
                $display("ERROR: Cannot open input file gray1.pgm");
                $finish;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%s", magic);
                if (scan_result == 0) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d %d", width, height);
                if (scan_result != 2) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d", max_val);
                if (scan_result != 1) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            f_out = $fopen("output/out_arithmetic_mul_output.pgm", "w");
            $fdisplay(f_out, "P2");
            $fdisplay(f_out, "%d %d", width, height);
            $fdisplay(f_out, "255");
            
            operation = 2'b10;
            
            @(posedge clk);
            rst_n = 1'b0;
            pixel_valid = 1'b0;
            pixel_a = 0;
            pixel_b = 0;
            buffer_index = 0;
            @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            
            pixel_valid = 1'b1;
            
            for (i = 0; i < height; i = i + 1) begin
                for (j = 0; j < width; j = j + 1) begin
                    scan_result = $fscanf(f_in1, "%d", pixel_val1);
                    if (scan_result != 1) begin
                        $display("ERROR: File ended at pixel(%d,%d), but more data was expected", i, j);
                        $fclose(f_in1);
                        $fclose(f_out);
                        $finish;
                    end
                    
                    if (max_val != 255) begin
                        pixel_val1 = (pixel_val1 * 255) / max_val;
                        if (pixel_val1 < 0) pixel_val1 = 0;
                        if (pixel_val1 > 255) pixel_val1 = 255;
                    end
                    
                    pixel_val2 = 5;
                    
                    pixel_a = pixel_val1[7:0];
                    pixel_b = pixel_val2[7:0];
                    
                    pixel_buffer[buffer_index] = pixel_val1[7:0];
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                            
                            if (((i * width + j) % 100 == 0) && (j >= 2)) begin
                                $display("Multiplication operation - Processing pixel (%d,%d): A=%d, B=%d -> Result=%d", 
                                        i, j-2, pixel_buffer[(buffer_index + 1) % 2], pixel_val2, pixel_out);
                            end
                        end else begin
                            $display("WARNING: Pixel(%d,%d) output invalid, using original value", i, j-2);
                            $fwrite(f_out, "%d ", pixel_buffer[(buffer_index + 1) % 2]);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                for (j = width; j < width + 2; j = j + 1) begin
                    pixel_a = 0;
                    pixel_b = 0;
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                        end else begin
                            $display("WARNING: Row %d last pixel output invalid, using default value", i);
                            $fwrite(f_out, "%d ", 0);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                $fwrite(f_out, "\n");
            end
            
            pixel_valid = 1'b0;
            
            $fclose(f_in1);
            $fclose(f_out);
            
            $display("Multiplication operation image processing completed. Result saved to arithmetic_mul_output.pgm");
        end
    endtask

    task test_image_div_operations;
        integer f_in1, f_out;
        integer width, height, max_val;
        integer i, j, pixel_val1, pixel_val2;
        reg [8*16-1:0] magic;
        integer scan_result;
        reg exit_loop;
        reg [7:0] char;
        reg [7:0] pixel_buffer [0:1];
        integer buffer_index;
        begin
            $display("=== Starting image file division operation test ===");
            
            f_in1 = $fopen("data/gray1.pgm", "r");
            if (f_in1 == 0) begin
                $display("ERROR: Cannot open input file gray1.pgm");
                $finish;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%s", magic);
                if (scan_result == 0) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d %d", width, height);
                if (scan_result != 2) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d", max_val);
                if (scan_result != 1) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            f_out = $fopen("output/out_arithmetic_div_output.pgm", "w");
            $fdisplay(f_out, "P2");
            $fdisplay(f_out, "%d %d", width, height);
            $fdisplay(f_out, "255");
            
            operation = 2'b11;
            
            @(posedge clk);
            rst_n = 1'b0;
            pixel_valid = 1'b0;
            pixel_a = 0;
            pixel_b = 0;
            buffer_index = 0;
            @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            
            pixel_valid = 1'b1;
            
            for (i = 0; i < height; i = i + 1) begin
                for (j = 0; j < width; j = j + 1) begin
                    scan_result = $fscanf(f_in1, "%d", pixel_val1);
                    if (scan_result != 1) begin
                        $display("ERROR: File ended at pixel(%d,%d), but more data was expected", i, j);
                        $fclose(f_in1);
                        $fclose(f_out);
                        $finish;
                    end
                    
                    if (max_val != 255) begin
                        pixel_val1 = (pixel_val1 * 255) / max_val;
                        if (pixel_val1 < 0) pixel_val1 = 0;
                        if (pixel_val1 > 255) pixel_val1 = 255;
                    end
                    
                    pixel_val2 = (pixel_val1 > 0) ? 10 : 1;
                    
                    pixel_a = pixel_val1[7:0];
                    pixel_b = pixel_val2[7:0];
                    
                    pixel_buffer[buffer_index] = pixel_val1[7:0];
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                            
                            if (((i * width + j) % 100 == 0) && (j >= 2)) begin
                                $display("Division operation - Processing pixel (%d,%d): A=%d, B=%d -> Result=%d", 
                                        i, j-2, pixel_buffer[(buffer_index + 1) % 2], pixel_val2, pixel_out);
                            end
                        end else begin
                            $display("WARNING: Pixel(%d,%d) output invalid, using original value", i, j-2);
                            $fwrite(f_out, "%d ", pixel_buffer[(buffer_index + 1) % 2]);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                for (j = width; j < width + 2; j = j + 1) begin
                    pixel_a = 0;
                    pixel_b = 1;
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                        end else begin
                            $display("WARNING: Row %d last pixel output invalid, using default value", i);
                            $fwrite(f_out, "%d ", 0);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                $fwrite(f_out, "\n");
            end
            
            pixel_valid = 1'b0;
            
            $fclose(f_in1);
            $fclose(f_out);
            
            $display("Division operation image processing completed. Result saved to arithmetic_div_output.pgm");
        end
    endtask

    task test_image_operations;
        integer f_in1, f_out;
        integer width, height, max_val;
        integer i, j, pixel_val1, pixel_val2;
        reg [8*16-1:0] magic;
        integer scan_result;
        reg exit_loop;
        reg [7:0] char;
        reg [7:0] pixel_buffer [0:1];
        integer buffer_index;
        begin
            $display("=== Starting image file processing test ===");
            
            f_in1 = $fopen("data/gray1.pgm", "r");
            if (f_in1 == 0) begin
                $display("ERROR: Cannot open input file gray1.pgm");
                $finish;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%s", magic);
                if (scan_result == 0) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            if (magic != "P2") begin
                $display("ERROR: Only P2 format PGM files are supported");
                $fclose(f_in1);
                $finish;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d %d", width, height);
                if (scan_result != 2) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            exit_loop = 0;
            while (!exit_loop) begin
                scan_result = $fscanf(f_in1, "%d", max_val);
                if (scan_result != 1) begin
                    char = $fgetc(f_in1);
                    if (char == "#") while ($fgetc(f_in1) != "\n") ;
                end else exit_loop = 1;
            end
            
            $display("Image dimensions: %dx%d, maximum pixel value: %d", width, height, max_val);
            
            f_out = $fopen("output/out_arithmetic_add_output.pgm", "w");
            $fdisplay(f_out, "P2");
            $fdisplay(f_out, "%d %d", width, height);
            $fdisplay(f_out, "255");
            
            operation = 2'b00;
            
            @(posedge clk);
            rst_n = 1'b0;
            pixel_valid = 1'b0;
            pixel_a = 0;
            pixel_b = 0;
            buffer_index = 0;
            @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            
            pixel_valid = 1'b1;
            
            for (i = 0; i < height; i = i + 1) begin
                for (j = 0; j < width; j = j + 1) begin
                    scan_result = $fscanf(f_in1, "%d", pixel_val1);
                    if (scan_result != 1) begin
                        $display("ERROR: File ended at pixel(%d,%d), but more data was expected", i, j);
                        $fclose(f_in1);
                        $fclose(f_out);
                        $finish;
                    end
                    
                    if (max_val != 255) begin
                        pixel_val1 = (pixel_val1 * 255) / max_val;
                        if (pixel_val1 < 0) pixel_val1 = 0;
                        if (pixel_val1 > 255) pixel_val1 = 255;
                    end
                    
                    pixel_val2 = 100;
                    
                    pixel_a = pixel_val1[7:0];
                    pixel_b = pixel_val2[7:0];
                    
                    pixel_buffer[buffer_index] = pixel_val1[7:0];
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                            
                            if (((i * width + j) % 100 == 0) && (j >= 2)) begin
                                $display("Processing pixel (%d,%d): A=%d, B=%d -> Result=%d", 
                                        i, j-2, pixel_buffer[(buffer_index + 1) % 2], pixel_val2, pixel_out);
                            end
                        end else begin
                            $display("WARNING: Pixel(%d,%d) output invalid, using original value", i, j-2);
                            $fwrite(f_out, "%d ", pixel_buffer[(buffer_index + 1) % 2]);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                for (j = width; j < width + 2; j = j + 1) begin
                    pixel_a = 0;
                    pixel_b = 0;
                    
                    @(posedge clk);
                    
                    if (j >= 2) begin
                        if (pixel_out_valid) begin
                            $fwrite(f_out, "%d ", pixel_out);
                        end else begin
                            $display("WARNING: Row %d last pixel output invalid, using default value", i);
                            $fwrite(f_out, "%d ", 0);
                        end
                    end
                    
                    buffer_index = (buffer_index + 1) % 2;
                end
                
                $fwrite(f_out, "\n");
            end
            
            pixel_valid = 1'b0;
            
            $fclose(f_in1);
            $fclose(f_out);
            
            $display("Image processing completed. Result saved to arithmetic_add_output.pgm");
            $display("=== Image file processing test completed ===");
        end
    endtask
    
    initial begin
        $dumpfile("image_arithmetic.vcd");
        $dumpvars(0, tb_image_arithmetic);
    end

endmodule