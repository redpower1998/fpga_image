`timescale 1ns/1ps

module tb_histogram;
    parameter HIST_BINS = 256;
    parameter HIST_WIDTH = 18;
    parameter IMAGE_WIDTH = 320;
    parameter IMAGE_HEIGHT = 464;

    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 8;
    parameter TEST_IMAGE_WIDTH = 320;
    parameter TEST_IMAGE_HEIGHT = 464;
    
    reg clk;
    reg rst_n;
    
    reg data_valid;
    reg [DATA_WIDTH-1:0] pixel_data;
    reg clear_hist;
    reg enable_hist;
    
    wire hist_ready;
    wire [HIST_WIDTH-1:0] hist_value;
    wire [DATA_WIDTH-1:0] hist_bin;
    wire hist_valid;
    
    integer test_count;
    integer error_count;
    integer total_pixels;
    integer golden_hist [0:HIST_BINS-1];
    
    integer f_gray_in, f_histogram_out;
    integer width, height, max_val;
    
    reg [7:0] source_image [0:TEST_IMAGE_WIDTH*TEST_IMAGE_HEIGHT-1];
    
    integer i, j, bin, pixel_val;
    reg [15:0] magic;
    integer scan_result;
    integer read_success;
    integer hw_hist [0:HIST_BINS-1];
    integer mismatch_count;
    integer f_histogram_out_local;
    integer start_time, end_time;
    integer scaled_value, max_hw_hist;
    real scale_factor;
    integer total_golden, total_hw, max_golden, max_hw, max_bin_golden, max_bin_hw;

            
    histogram #(
.DATA_WIDTH(DATA_WIDTH),
        .HIST_BINS(HIST_BINS),
        .HIST_WIDTH(HIST_WIDTH)
    ) u_histogram (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(data_valid),
        .pixel_data(pixel_data),
        .clear_hist(clear_hist),
        .enable_hist(enable_hist),
        .hist_ready(hist_ready),
        .hist_value(hist_value),
        .hist_bin(hist_bin),
        .hist_valid(hist_valid),
        .state_out(state_out)
    );
    
    wire [1:0] state_out;
    
    always #(CLK_PERIOD/2) clk = ~clk;
    task initialize;
        begin
            clk = 1'b0;
            rst_n = 1'b0;
            data_valid = 1'b0;
            pixel_data = {DATA_WIDTH{1'b0}};
            clear_hist = 1'b0;
            enable_hist = 1'b0;
            test_count = 0;
            error_count = 0;
            total_pixels = 0;
            
            for (i = 0; i < HIST_BINS; i = i + 1) begin
                golden_hist[i] = 0;
            end
        end
    endtask
    
    task reset_system;
        begin
            rst_n = 1'b0;
            repeat(5) @(posedge clk);
            rst_n = 1'b1;
            repeat(2) @(posedge clk);
        end
    endtask
    
    task read_pgm_image;
        input [8192:0] filename;
        output integer success;
        begin
            f_gray_in = $fopen(filename, "r");
if (f_gray_in == 0) begin
                $display("ERROR: Cannot open file %s", filename);
                success = 0;
                disable read_pgm_image;
            end
            
            scan_result = $fscanf(f_gray_in, "%s", magic);
            if (magic != "P2" && magic != "P5") begin
                $display("ERROR: Not a valid PGM file, expected P2 or P5 format, actually got: %s", magic);
                success = 0;
                $fclose(f_gray_in);
disable read_pgm_image;
            end
            
            scan_result = $fscanf(f_gray_in, "%d %d", width, height);
scan_result = $fscanf(f_gray_in, "%d", max_val);
            
$display("Reading image: %s, format: %s, size: %dx%d, max value: %d", 
                     filename, magic, width, height, max_val);
            
            if (magic == "P2") begin
                for (i = 0; i < height; i = i + 1) begin
                    for (j = 0; j < width; j = j + 1) begin
                        scan_result = $fscanf(f_gray_in, "%d", pixel_val);
                        if (scan_result != 1) begin
                            $display("ERROR: File format error, cannot read pixel value (i=%d, j=%d)", i, j);
success = 0;
                            $fclose(f_gray_in);
                            disable read_pgm_image;
                        end
                        
if (pixel_val < 0 || pixel_val > 255) begin
$display("ERROR: Pixel value out of range: %d (i=%d, j=%d)", pixel_val, i, j);
success = 0;
                            $fclose(f_gray_in);
                            disable read_pgm_image;
                        end
                        
                        source_image[i * width + j] = pixel_val;
                        golden_hist[pixel_val] = golden_hist[pixel_val] + 1;
end
end
            end else begin
                for (i = 0; i < height; i = i + 1) begin
                    for (j = 0; j < width; j = j + 1) begin
                        pixel_val = $fgetc(f_gray_in);
                        if (pixel_val == -1) begin
                            $display("ERROR: File ended prematurely");
                            success = 0;
                            $fclose(f_gray_in);
                            disable read_pgm_image;
                        end
                        source_image[i * width + j] = pixel_val;
                        golden_hist[pixel_val] = golden_hist[pixel_val] + 1;
                    end
                end
            end
            
            total_pixels = width * height;
            $fclose(f_gray_in);
            $display("Successfully read %d pixels", total_pixels);
success = 1;
        end
    endtask
    
    task test_basic_functionality;
        begin
            $display("=== Test 1: Basic functionality test ===");
            test_count = test_count + 1;
            
reset_system();
            
            if (!hist_ready) begin
                $display("ERROR: hist_ready should be high after reset");
                error_count = error_count + 1;
end
            
            clear_hist = 1'b1;
            @(posedge clk);
            clear_hist = 1'b0;
            @(posedge clk);
            
            enable_hist = 1'b1;
            for (i = 0; i < 10; i = i + 1) begin
                data_valid = 1'b1;
                pixel_data = i * 25;
                @(posedge clk);
            end
            data_valid = 1'b0;
enable_hist = 1'b0;
            
            wait(hist_ready);
            $display("PASS: Basic functionality test completed");
        end
    endtask
    
    task test_image_histogram;
        input [4096:0] image_filename;
        begin
            mismatch_count = 0;
            $display("=== Test 2: Image histogram statistics test (%s) ===", image_filename);
            test_count = test_count + 1;
            
            read_pgm_image(image_filename, read_success);
            if (!read_success) begin
                error_count = error_count + 1;
                disable test_image_histogram;
            end
            
reset_system();
            clear_hist = 1'b1;
            @(posedge clk);
            clear_hist = 1'b0;
            @(posedge clk);
            
            enable_hist = 1'b1;
            enable_hist = 1'b1;
            
            data_valid = 1'b0;
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            
            for (i = 0; i < 256; i = i + 1) begin
                for (j = 0; j < golden_hist[i]; j = j + 1) begin
                    data_valid = 1'b1;
                    pixel_data = i;
                    @(posedge clk);
                end
            end
            data_valid = 1'b0;
            
            repeat(20) @(posedge clk);
            
            enable_hist = 1'b0;
            @(posedge clk);
            
            wait(hist_valid);
            @(posedge clk);
            
            for (bin = 0; bin < HIST_BINS; bin = bin + 1) begin
                hw_hist[bin] = hist_value;
                $display("DEBUG: bin[%d] = %d", bin, hw_hist[bin]);
                
                if (bin < HIST_BINS - 1) begin
                    @(posedge clk);
                end
            end
            
            mismatch_count = 0;
            for (bin = 0; bin < HIST_BINS; bin = bin + 1) begin
                if (hw_hist[bin] != golden_hist[bin]) begin
                    if (mismatch_count < 10) begin
                        $display("ERROR: bin %d mismatch - expected: %d, actual: %d", 
                                bin, golden_hist[bin], hw_hist[bin]);
                    end
                    mismatch_count = mismatch_count + 1;
                end
            end
            
            if (mismatch_count == 0) begin
                $display("PASS: Image histogram statistics test successful");
            end else begin
                $display("FAIL: Found %d mismatched bins", mismatch_count);
                error_count = error_count + 1;
            end
            
            $display("\n=== Detailed histogram analysis ===");
            total_golden = 0;
            total_hw = 0;
            max_golden = 0;
            max_hw = 0;
            max_bin_golden = 0;
max_bin_hw = 0;
            
            for (bin = 0; bin < HIST_BINS; bin = bin + 1) begin
                total_golden = total_golden + golden_hist[bin];
                total_hw = total_hw + hw_hist[bin];
                
                if (golden_hist[bin] > max_golden) begin
                    max_golden = golden_hist[bin];
                    max_bin_golden = bin;
end
                if (hw_hist[bin] > max_hw) begin
                    max_hw = hw_hist[bin];
                    max_bin_hw = bin;
                end
            end
            
            $display("Reference histogram: total pixels=%d, max value=%d (bin[%d])", total_golden, max_golden, max_bin_golden);
            $display("Hardware histogram: total pixels=%d, max value=%d (bin[%d])", total_hw, max_hw, max_bin_hw);
            $display("Pixel statistics difference: %d", total_golden - total_hw);
            
            $display("\nDetailed comparison of first 30 bins:");
            for (bin = 0; bin < 30; bin = bin + 1) begin
                $display("bin[%3d]: reference=%5d, hardware=%5d, difference=%3d, status=%s", 
                        bin, golden_hist[bin], hw_hist[bin],
                        golden_hist[bin] - hw_hist[bin],
                        (golden_hist[bin] == hw_hist[bin]) ? "PASS" : "FAIL");
            end
            
            f_histogram_out_local = $fopen("output/histogram_output.pgm", "w");
            if (f_histogram_out_local == 0) begin
                $display("WARNING: Cannot create histogram output file");
            end else begin
                $fwrite(f_histogram_out_local, "P2\n");
                $fwrite(f_histogram_out_local, "%d %d\n", HIST_BINS + 50, 150);
                $fwrite(f_histogram_out_local, "255\n");
                
                max_hw_hist = 0;
                for (bin = 0; bin < HIST_BINS; bin = bin + 1) begin
                    if (hw_hist[bin] > max_hw_hist) begin
                        max_hw_hist = hw_hist[bin];
                    end
                end
                $display("Debug: Hardware histogram maximum value = %d", max_hw_hist);
                
                if (max_hw_hist > 0) begin
                    scale_factor = 100.0 / max_hw_hist;
                end else begin
                    scale_factor = 0;
                end
                
                for (i = 0; i < 150; i = i + 1) begin
                    for (j = 0; j < HIST_BINS + 50; j = j + 1) begin
                        if (i >= 130 && i < 135) begin
                            $fwrite(f_histogram_out_local, "%d ", 128);
                        end else if (j >= 5 && j < 10) begin
                            $fwrite(f_histogram_out_local, "%d ", 128);
                        end else if (j >= 10 && j < HIST_BINS + 10) begin
                            if (max_hw_hist > 0) begin
                                scaled_value = $rtoi(hw_hist[j-10] * scale_factor);
                                if (scaled_value > 100) scaled_value = 100;
                                if (scaled_value < 0) scaled_value = 0;
                            end else begin
                                scaled_value = 0;
                            end
                            
                            if ((129 - i) < scaled_value && (129 - i) >= 0) begin
                                $fwrite(f_histogram_out_local, "%d ", 255);
                            end else begin
                                $fwrite(f_histogram_out_local, "%d ", 0);
                            end
                        end else begin
                            $fwrite(f_histogram_out_local, "%d ", 64);
                        end
                    end
                    $fwrite(f_histogram_out_local, "\n");
                end
                $fclose(f_histogram_out_local);
                $display("Histogram visualization saved to histogram_output.pgm");
                $display("Scale factor: %f", scale_factor);
                $display("Histogram size: %dx%d", HIST_BINS + 50, 150);
            end
        end
    endtask
    
    task test_known_histogram;
        integer i, j, bin;
        integer mismatch_count;
        real scale_factor;
        integer scaled_value;
        integer max_hw_hist;
        integer f_histogram_out_local;
        begin
            $display("=== Test 2: Known histogram verification test ===");
            test_count = test_count + 1;
            
            reset_system();
            
            for (bin = 0; bin < HIST_BINS; bin = bin + 1) begin
                if (bin < 128) begin
                    golden_hist[bin] = bin + 1;
                end else begin
                    golden_hist[bin] = 256 - bin;
                end
            end
            
            clear_hist = 1'b1;
            @(posedge clk);
            clear_hist = 1'b0;
            @(posedge clk);
            
            enable_hist = 1'b1;
            data_valid = 1'b0;
            
            wait(state_out == 2'b01);
            @(posedge clk);
            
            for (i = 0; i < 256; i = i + 1) begin
                for (j = 0; j < golden_hist[i]; j = j + 1) begin
                    data_valid = 1'b1;
                    pixel_data = i;
                    @(posedge clk);
                end
            end
            
            data_valid = 1'b0;
            enable_hist = 1'b0;
            
            wait(state_out == 2'b10);
            @(posedge clk);
            
            for (bin = 0; bin < HIST_BINS; bin = bin + 1) begin
                @(posedge clk);
                hw_hist[bin] = hist_value;
            end
            
            wait(state_out == 2'b00);
            @(posedge clk);
            
            mismatch_count = 0;
            for (bin = 0; bin < HIST_BINS; bin = bin + 1) begin
                if (hw_hist[bin] != golden_hist[bin]) begin
                    if (mismatch_count < 10) begin
                        $display("ERROR: bin %d mismatch - expected: %d, actual: %d", 
                                bin, golden_hist[bin], hw_hist[bin]);
                    end
                    mismatch_count = mismatch_count + 1;
                end
            end
            
            if (mismatch_count == 0) begin
                $display("PASS: Known histogram verification test successful");
            end else begin
                $display("FAIL: Found %d mismatched bins", mismatch_count);
                error_count = error_count + 1;
            end
            
            f_histogram_out_local = $fopen("known_histogram_output.pgm", "w");
            if (f_histogram_out_local == 0) begin
                $display("WARNING: Cannot create known histogram output file");
            end else begin
                $fwrite(f_histogram_out_local, "P2\n");
                $fwrite(f_histogram_out_local, "%d %d\n", HIST_BINS + 20, 150);
                $fwrite(f_histogram_out_local, "255\n");
                
                for (i = 0; i < 150; i = i + 1) begin
                    for (j = 0; j < HIST_BINS + 20; j = j + 1) begin
                        if (i >= 140 && i < 145) begin
                            $fwrite(f_histogram_out_local, "%d ", 128);
                        end else if (j >= 10 && j < 15) begin
                            $fwrite(f_histogram_out_local, "%d ", 128);
                        end else if (j >= 15 && j < HIST_BINS + 15) begin
                            if (max_hw_hist > 0) begin
                                scaled_value = $rtoi(hw_hist[j-15] * scale_factor);
                                if (scaled_value > 100) scaled_value = 100;
                                if (scaled_value < 0) scaled_value = 0;
                            end else begin
                                scaled_value = 0;
                            end
                            
                            if ((139 - i) < scaled_value && (139 - i) >= 0) begin
                                if (j % 2 == 0) begin
                                    $fwrite(f_histogram_out_local, "%d ", 255);
                                end else begin
                                    $fwrite(f_histogram_out_local, "%d ", 0);
                                end
                            end else begin
                                $fwrite(f_histogram_out_local, "%d ", 0);
                            end
                        end else begin
                            $fwrite(f_histogram_out_local, "%d ", 64);
                        end
                    end
                    $fwrite(f_histogram_out_local, "\n");
                end
                $fclose(f_histogram_out_local);
                $display("Known histogram visualization saved to known_histogram_output.pgm");
                $display("Expected result: triangular wave distribution (high in the middle, low at both ends)");
            end
        end
    endtask
    
    task test_boundary_conditions;
        begin
            $display("=== Test 3: Boundary conditions test ===");
            test_count = test_count + 1;
            
            reset_system();
            clear_hist = 1'b1;
            @(posedge clk);
            clear_hist = 1'b0;
            @(posedge clk);
            
            enable_hist = 1'b1;
            data_valid = 1'b1;
            pixel_data = 8'h00;
            @(posedge clk);
            pixel_data = 8'hFF;
            @(posedge clk);
            pixel_data = 8'h7F;
            @(posedge clk);
            data_valid = 1'b0;
            enable_hist = 1'b0;
            
            wait(hist_ready);
            $display("PASS: Boundary conditions test completed");
        end
    endtask
    
    task test_performance;
        begin
            $display("=== Test 4: Performance test ===");
            test_count = test_count + 1;
            
            reset_system();
            clear_hist = 1'b1;
            @(posedge clk);
            clear_hist = 1'b0;
            @(posedge clk);
            
            start_time = $time;
            enable_hist = 1'b1;
            
            for (i = 0; i < 1000; i = i + 1) begin
                data_valid = 1'b1;
                pixel_data = i % HIST_BINS;
                @(posedge clk);
            end
            data_valid = 1'b0;
            enable_hist = 1'b0;
            
            wait(hist_ready);
            end_time = $time;
            
            $display("Performance test completed in %d ns", end_time - start_time);
            $display("PASS: Performance test completed");
        end
    endtask
    
    initial begin
        initialize();
        
        $display("=== Starting histogram statistics module test ===");
        
        test_basic_functionality();
        test_image_histogram("data/baby.pgm");
        test_known_histogram();
        test_boundary_conditions();
        test_performance();
        
        $display("\n=== Test summary ===");
        $display("Total tests: %d", test_count);
        $display("Errors: %d", error_count);
        
        if (error_count == 0) begin
            $display("PASS: All tests passed successfully!");
        end else begin
            $display("FAIL: %d test(s) failed", error_count);
        end
        
        $display("Simulation completed at time %0d", $time);
        
        $dumpfile("histogram.vcd");
        $dumpvars(0, tb_histogram);
        
        #1000;
        $finish;
    end
endmodule