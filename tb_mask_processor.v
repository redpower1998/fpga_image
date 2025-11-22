`timescale 1ns/1ps

module tb_mask_processor;

    reg clk;
    reg rst_n;
    
    reg pixel_valid;
    reg [7:0] pixel_data;
    reg [7:0] mask_value;
    reg [2:0] operation;
    
    wire pixel_out_valid;
    wire [7:0] pixel_out;
    
    mask_processor #(
        .DATA_WIDTH(8),
        .OPERATION_WIDTH(3),
        .MASK_WIDTH(8)
    ) u_mask_processor (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .pixel_data(pixel_data),
        .mask_value(mask_value),
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
        pixel_data = 8'd0;
        mask_value = 8'd0;
        operation = 3'b000;
        
        #200;
        rst_n = 1'b1;
        #100;
        
        $display("=== Starting mask processor module test ===");
        
        test_basic_operations();
        #100;
        
        test_pgm_image();
        #100;
        
        $display("=== All tests completed ===");
        $finish;
    end
    
    task test_basic_operations;
        integer i;
        reg [7:0] expected;
        begin
            $display("=== Basic mask operation test ===");
            
            operation = 3'b000;
            $display("Testing AND operation:");
            for (i = 0; i < 5; i = i + 1) begin
                mask_value = 8'b10101010;
                @(posedge clk);
                @(posedge clk);
                pixel_valid = 1'b1;
                pixel_data = i * 25 + 100;
                expected = pixel_data & mask_value;
                
                repeat(2) @(posedge clk);
                
                if (pixel_out_valid) begin
                    $display("  %d & %d = %d (expected: %d)", pixel_data, mask_value, pixel_out, expected);
                end else begin
                    $display("  ERROR: Output invalid (time: %0d)", $time);
                end
                
                pixel_valid = 1'b0;
                pixel_data = 8'd0;
                
                #20;
            end
            
            operation = 3'b001;
            $display("Testing OR operation:");
            for (i = 0; i < 5; i = i + 1) begin
                mask_value = 8'b01010101;
                @(posedge clk);
                @(posedge clk);
                pixel_valid = 1'b1;
                pixel_data = i * 20 + 50;
                expected = pixel_data | mask_value;
                
                repeat(2) @(posedge clk);
                
                if (pixel_out_valid) begin
                    $display("  %d | %d = %d (expected: %d)", pixel_data, mask_value, pixel_out, expected);
                end else begin
                    $display("  ERROR: Output invalid (time: %0d)", $time);
                end
                
                pixel_valid = 1'b0;
                pixel_data = 8'd0;
                
                #20;
            end
            
            operation = 3'b010;
            $display("Testing XOR operation:");
            for (i = 0; i < 5; i = i + 1) begin
                mask_value = 8'b11110000;
                @(posedge clk);
                @(posedge clk);
                pixel_valid = 1'b1;
                pixel_data = i * 15 + 75;
                expected = pixel_data ^ mask_value;
                
                repeat(2) @(posedge clk);
                
                if (pixel_out_valid) begin
                    $display("  %d ^ %d = %d (expected: %d)", pixel_data, mask_value, pixel_out, expected);
                end else begin
                    $display("  ERROR: Output invalid (time: %0d)", $time);
                end
                
                pixel_valid = 1'b0;
                pixel_data = 8'd0;
                
                #20;
            end
            
            $display("Basic operation test completed");
        end
    endtask
    
    task test_pgm_image;
        integer f_in, f_mask, f_out_and, f_out_or, f_out_xor, f_out_threshold;
        integer width, height, max_val;
        integer i, j;
        reg [7:0] pixel_val, mask_val;
        integer temp_result;
        integer pixel_count;
        reg error_flag;
        reg exit_loop;
        reg [7:0] char_val;
        reg [15:0] magic;
        begin
            $display("=== Starting PGM image file processing test ===");
            error_flag = 1'b0;
            
            f_in = $fopen("data/baby.pgm", "r");
            if (f_in == 0) begin
                $display("ERROR: Cannot open input file baby.pgm");
                disable test_pgm_image;
            end
            
            temp_result = $fscanf(f_in, "%s", magic);
            if (temp_result != 1 || magic != "P2") begin
                $display("ERROR: Not a valid PGM file format, expected P2, actual: %s", magic);
                $fclose(f_in);
                disable test_pgm_image;
            end
            
            exit_loop = 1'b0;
            while (!exit_loop) begin
                temp_result = $fscanf(f_in, "%d %d", width, height);
                if (temp_result == 2) begin
                    exit_loop = 1'b1;
                end else begin
                    char_val = $fgetc(f_in);
                    if (char_val == "#") begin
                        while ($fgetc(f_in) != "\n") begin end
                    end
                end
            end
            
            temp_result = $fscanf(f_in, "%d", max_val);
            if (temp_result != 1) begin
                $display("ERROR: Cannot read maximum pixel value");
                $fclose(f_in);
                disable test_pgm_image;
            end
            
            $display("Image size: %d x %d, max value: %d", width, height, max_val);
            
            create_mask_image(width, height);
            
            f_mask = $fopen("output/out_mask_rectangle.pgm", "r");
            if (f_mask == 0) begin
                $display("ERROR: Cannot open mask file mask_rectangle.pgm");
                $fclose(f_in);
                disable test_pgm_image;
            end
            
            temp_result = $fscanf(f_mask, "%s", magic);
            if (temp_result != 1 || magic != "P2") begin
                $display("ERROR: Mask file format error");
                $fclose(f_in);
                $fclose(f_mask);
                disable test_pgm_image;
            end
            
            exit_loop = 1'b0;
            while (!exit_loop) begin
                temp_result = $fscanf(f_mask, "%d %d", width, height);
                if (temp_result == 2) begin
                    exit_loop = 1'b1;
                end else begin
                    char_val = $fgetc(f_mask);
                    if (char_val == "#") begin
                        while ($fgetc(f_mask) != "\n") begin end
                    end
                end
            end
            
            temp_result = $fscanf(f_mask, "%d", max_val);
            if (temp_result != 1) begin
                $display("ERROR: Cannot read maximum pixel value from mask file");
                $fclose(f_in);
                $fclose(f_mask);
                disable test_pgm_image;
            end
            
            f_out_and = $fopen("output/out_mask_and_output.pgm", "w");
            f_out_or = $fopen("output/out_mask_or_output.pgm", "w");
            f_out_xor = $fopen("output/out_mask_xor_output.pgm", "w");
            f_out_threshold = $fopen("output/out_mask_threshold_output.pgm", "w");
            
            $fdisplay(f_out_and, "P2");
            $fdisplay(f_out_and, "%d %d", width, height);
            $fdisplay(f_out_and, "%d", 255);
            
            $fdisplay(f_out_or, "P2");
            $fdisplay(f_out_or, "%d %d", width, height);
            $fdisplay(f_out_or, "%d", 255);
            
            $fdisplay(f_out_xor, "P2");
            $fdisplay(f_out_xor, "%d %d", width, height);
            $fdisplay(f_out_xor, "%d", 255);
            
            $fdisplay(f_out_threshold, "P2");
            $fdisplay(f_out_threshold, "%d %d", width, height);
            $fdisplay(f_out_threshold, "%d", 255);
            
            pixel_count = 0;
            $display("Starting pixel processing...");
            
            for (j = 0; j < height; j = j + 1) begin
                for (i = 0; i < width; i = i + 1) begin
                    exit_loop = 1'b0;
                    while (!exit_loop) begin
                        temp_result = $fscanf(f_in, "%d", pixel_val);
                        if (temp_result == 1) begin
                            exit_loop = 1'b1;
                        end else begin
                            if ($feof(f_in)) begin
                                $display("WARNING: Premature end of file");
                                j = height;
                                i = width;
                                exit_loop = 1'b1;
                            end else begin
                                char_val = $fgetc(f_in);
                                if (char_val == "#") begin
                                    while ($fgetc(f_in) != "\n") begin end
                                end
                            end
                        end
                    end
                    
                    exit_loop = 1'b0;
                    while (!exit_loop) begin
                        temp_result = $fscanf(f_mask, "%d", mask_val);
                        if (temp_result == 1) begin
                            exit_loop = 1'b1;
                        end else begin
                            if ($feof(f_mask)) begin
                                $display("WARNING: Premature end of mask file");
                                j = height;
                                i = width;
                                exit_loop = 1'b1;
                            end else begin
                                char_val = $fgetc(f_mask);
                                if (char_val == "#") begin
                                    while ($fgetc(f_mask) != "\n") begin end
                                end
                            end
                        end
                    end
                    
                    if (j >= height || i >= width) begin
                        j = height;
                        i = width;
                    end else begin
                        if (max_val != 255) begin
                            pixel_val = (pixel_val * 255) / max_val;
                            mask_val = (mask_val * 255) / max_val;
                        end
                        
                        mask_value = mask_val;
                        
                        operation = 3'b000;
                        @(posedge clk);
                        @(posedge clk);
                        pixel_valid = 1'b1;
                        pixel_data = pixel_val;
                        
                        @(posedge clk);
                        @(posedge clk);
                        
                        if (pixel_out_valid) begin
                            $fwrite(f_out_and, "%d ", pixel_out);
                        end else begin
                            $fwrite(f_out_and, "%d ", pixel_val);
                        end
                        
                        @(posedge clk);
                        pixel_valid = 1'b0;
                        pixel_data = 8'd0;
                        
                        operation = 3'b001;
                        @(posedge clk);
                        pixel_valid = 1'b1;
                        pixel_data = pixel_val;
                        
                        @(posedge clk);
                        @(posedge clk);
                        
                        if (pixel_out_valid) begin
                            $fwrite(f_out_or, "%d ", pixel_out);
                        end else begin
                            $fwrite(f_out_or, "%d ", pixel_val);
                        end
                        
                        @(posedge clk);
                        pixel_valid = 1'b0;
                        pixel_data = 8'd0;
                        
                        operation = 3'b010;
                        @(posedge clk);
                        pixel_valid = 1'b1;
                        pixel_data = pixel_val;
                        
                        @(posedge clk);
                        @(posedge clk);
                        
                        if (pixel_out_valid) begin
                            $fwrite(f_out_xor, "%d ", pixel_out);
                        end else begin
                            $fwrite(f_out_xor, "%d ", pixel_val);
                        end
                        
                        @(posedge clk);
                        pixel_valid = 1'b0;
                        pixel_data = 8'd0;
                        
                        operation = 3'b110;
                        @(posedge clk);
                        pixel_valid = 1'b1;
                        pixel_data = pixel_val;
                        
                        @(posedge clk);
                        @(posedge clk);
                        
                        if (pixel_out_valid) begin
                            $fwrite(f_out_threshold, "%d ", pixel_out);
                        end else begin
                            $fwrite(f_out_threshold, "%d ", pixel_val);
                        end
                        
                        @(posedge clk);
                        pixel_valid = 1'b0;
                        pixel_data = 8'd0;
                        
                        pixel_count = pixel_count + 1;
                        
                        if (pixel_count % 1000 == 0) begin
                            $display("Processing progress: %0d/%0d", pixel_count, width * height);
                        end
                    end
                end
                
                if (j < height) begin
                    $fdisplay(f_out_and, "");
                    $fdisplay(f_out_or, "");
                    $fdisplay(f_out_xor, "");
                    $fdisplay(f_out_threshold, "");
                end
            end
            
            $fclose(f_in);
            $fclose(f_mask);
            $fclose(f_out_and);
            $fclose(f_out_or);
            $fclose(f_out_xor);
            $fclose(f_out_threshold);
            
            $display("Image processing completed, processed %d pixels", pixel_count);
        end
    endtask
    
    task create_mask_image;
        input integer width;
        input integer height;
        integer f_mask, f_mask_simple;
        integer i, j;
        reg [7:0] mask_val;
        begin
            $display("Creating mask image file...");
            
            f_mask = $fopen("output/out_mask_rectangle.pgm", "w");
            if (f_mask == 0) begin
                $display("ERROR: Cannot create mask file");
                disable create_mask_image;
            end
            
            $fdisplay(f_mask, "P2");
            $fdisplay(f_mask, "%d %d", width, height);
            $fdisplay(f_mask, "255");
            
            for (j = 0; j < height; j = j + 1) begin
                for (i = 0; i < width; i = i + 1) begin
                    if (i >= width/3 && i < 2*width/3 && j >= height/3 && j < 2*height/3) begin
                        mask_val = 8'd0;
                    end else begin
                        mask_val = 8'd255;
                    end
                    
                    $fwrite(f_mask, "%d ", mask_val);
                end
                $fdisplay(f_mask, "");
            end
            
            $fclose(f_mask);
            $display("Mask image file created: mask_rectangle.pgm");
            
            f_mask_simple = $fopen("output/out_mask_example.pgm", "w");
            if (f_mask_simple == 0) begin
                $display("ERROR: Cannot create example mask file");
                disable create_mask_image;
            end
            
            $fdisplay(f_mask_simple, "P2");
            $fdisplay(f_mask_simple, "10 10");
            $fdisplay(f_mask_simple, "255");
            
            for (j = 0; j < 10; j = j + 1) begin
                for (i = 0; i < 10; i = i + 1) begin
                    if (i >= 3 && i < 7 && j >= 3 && j < 7) begin
                        mask_val = 8'd0;
                    end else begin
                        mask_val = 8'd255;
                    end
                    
                    $fwrite(f_mask_simple, "%d ", mask_val);
                end
                $fdisplay(f_mask_simple, "");
            end
            
            $fclose(f_mask_simple);
            $display("Example mask image file created: mask_example.pgm");
        end
    endtask

endmodule