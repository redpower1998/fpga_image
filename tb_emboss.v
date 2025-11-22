`timescale 1ns/1ps

module tb_emboss;

    parameter CLK_PERIOD = 10;
    parameter IMAGE_WIDTH = 320;
    parameter IMAGE_HEIGHT = 464;
    
    reg clk;
    reg rst_n;
    reg pixel_valid;
    reg [7:0] pixel_in;
    
    wire pixel_out_valid;
    wire [7:0] pixel_out;
    
    integer f_gray_in, f_emboss_out;
    integer width, height, max_val;
    integer pixel_count;
    reg [7:0] source_image [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    reg [7:0] output_image [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    reg [7:0] ch;
    reg [1023:0] line_buffer;
    integer scan_result;
    integer error_flag;
    integer i, j;
    integer pixel_val;
    integer wait_count;
    integer found_non_comment;
    
    emboss #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .DATA_WIDTH(8)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .pixel_in(pixel_in),
        .pixel_out_valid(pixel_out_valid),
        .pixel_out(pixel_out)
    );
    
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        pixel_valid = 1'b0;
        pixel_in = 8'd0;
        error_flag = 0;
        found_non_comment = 0;
        
        #100;
        rst_n = 1'b1;
        #100;
        
        $display("=== Start emboss module test ===");
        
        test_emboss_image();
        
        #1000;
        $display("=== All tests completed ===");
        $finish;
    end
    
    task test_emboss_image;
        begin
            $display("Start processing PGM image file...");
            
            f_gray_in = $fopen("data/gray1.pgm", "r");
            if (f_gray_in == 0) begin
                $display("ERROR: Cannot open input file gray1.pgm");
                error_flag = 1;
            end else begin
                scan_result = $fscanf(f_gray_in, "%s", line_buffer);
                if (line_buffer != "P2") begin
                    $display("ERROR: Not a valid P2 format PGM file");
                    $fclose(f_gray_in);
                    error_flag = 1;
                end else begin
                    found_non_comment = 0;
                    while (!$feof(f_gray_in) && !found_non_comment) begin
                        scan_result = $fscanf(f_gray_in, "%s", line_buffer);
                        if (line_buffer[0] == "#") begin
                            scan_result = $fgets(line_buffer, f_gray_in);
                        end else begin
                            scan_result = $sscanf(line_buffer, "%d", width);
                            scan_result = $fscanf(f_gray_in, "%d", height);
                            if (width != IMAGE_WIDTH || height != IMAGE_HEIGHT) begin
                                $display("ERROR: Image size mismatch: %d x %d (expected: %d x %d)", 
                                        width, height, IMAGE_WIDTH, IMAGE_HEIGHT);
                                error_flag = 1;
                            end
                            found_non_comment = 1;
                        end
                    end
                    
                    if (!error_flag) begin
                        scan_result = $fscanf(f_gray_in, "%d", max_val);
                        if (max_val != 255) begin
                            $display("WARNING: Max value is not 255: %d", max_val);
                        end
                        
                        $display("Read PGM file: width=%d, height=%d, max_val=%d", width, height, max_val);
                        
                        pixel_count = 0;
                        for (j = 0; j < height; j = j + 1) begin
                            for (i = 0; i < width; i = i + 1) begin
                                if ($feof(f_gray_in)) begin
                                    $display("ERROR: File ended prematurely");
                                    error_flag = 1;
                                    j = height;
                                    i = width;
                                end else begin
                                    scan_result = $fscanf(f_gray_in, "%d", pixel_val);
                                    if (scan_result != 1) begin
                                        $display("ERROR: Failed to read pixel data");
                                        error_flag = 1;
                                        j = height;
                                        i = width;
                                    end else begin
                                        source_image[j * width + i] = pixel_val;
                                        pixel_count = pixel_count + 1;
                                    end
                                end
                            end
                        end
                        
                        if (!error_flag) begin
                            $display("Successfully read %d pixels", pixel_count);
                            $fclose(f_gray_in);
                            
                            f_emboss_out = $fopen("output/emboss_output.pgm", "w");
                            if (f_emboss_out == 0) begin
                                $display("ERROR: Cannot create output file");
                                error_flag = 1;
                            end else begin
                                $fdisplay(f_emboss_out, "P2");
                                $fdisplay(f_emboss_out, "# Emboss processed image");
                                $fdisplay(f_emboss_out, "%d %d", width, height);
                                $fdisplay(f_emboss_out, "%d", 255);
                                
                                $display("Start emboss processing...");
                                
                                rst_n = 1'b0;
                                #100;
                                rst_n = 1'b1;
                                #100;
                                
                                pixel_count = 0;
                                for (j = 0; j < height; j = j + 1) begin
                                    for (i = 0; i < width; i = i + 1) begin
                                        @(posedge clk);
                                        pixel_valid = 1'b1;
                                        pixel_in = source_image[j * width + i];
                                        @(posedge clk);
                                        pixel_valid = 1'b0;
                                        pixel_in = 8'd0;
                                        
                                        wait_count = 0;
                                        while (!pixel_out_valid && wait_count < 100) begin
                                            @(posedge clk);
                                            wait_count = wait_count + 1;
                                        end
                                        
                                        if (pixel_out_valid) begin
                                            output_image[j * width + i] = pixel_out;
                                            pixel_count = pixel_count + 1;
                                        end else begin
                                            $display("WARNING: Pixel(%d,%d) output timeout", i, j);
                                        end
                                    end
                                end
                                
                                $display("Emboss processing completed, processed %d pixels", pixel_count);
                                
                                $display("Writing output file...");
                                for (j = 0; j < height; j = j + 1) begin
                                    for (i = 0; i < width; i = i + 1) begin
                                        if (i % 20 == 0 && i > 0) begin
                                            $fdisplay(f_emboss_out, "");
                                        end
                                        $fwrite(f_emboss_out, "%d ", output_image[j * width + i]);
                                    end
                                    $fdisplay(f_emboss_out, "");
                                end
                                
                                $fclose(f_emboss_out);
                                $display("Emboss image saved as emboss_output.pgm");
                            end
                        end
                    end
                end
            end
        end
    endtask
    
    initial begin
        $dumpfile("emboss.vcd");
        $dumpvars(0, tb_emboss);
    end

endmodule