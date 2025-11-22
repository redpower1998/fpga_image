`timescale 1ns/1ps

module tb_histogram_rgb;
    parameter DATA_WIDTH = 8;
    parameter HIST_BINS = 256;
    parameter HIST_WIDTH = 18;
    parameter CLK_PERIOD = 10;
    
    reg clk;
    reg rst_n;
    reg data_valid;
    reg [DATA_WIDTH-1:0] r_data;
    reg [DATA_WIDTH-1:0] g_data;
    reg [DATA_WIDTH-1:0] b_data;
    reg clear_hist;
    reg enable_hist;
    
    wire hist_ready;
    wire [HIST_WIDTH-1:0] r_hist_value;
    wire [HIST_WIDTH-1:0] g_hist_value;
    wire [HIST_WIDTH-1:0] b_hist_value;
    wire [DATA_WIDTH-1:0] hist_bin;
    wire hist_valid;
    wire [1:0] channel_sel;
    
    integer i, j;
    integer r_bin_count, g_bin_count, b_bin_count;
    integer total_pixels = 1000;
    
    integer ppm_file;
    integer width, height, max_value;
    integer pixel_count;
    reg [7:0] r_pixel, g_pixel, b_pixel;
    integer pixel_index;
    
    integer hist_r_file, hist_g_file, hist_b_file;
    integer hist_combined_file;
    
    reg [HIST_WIDTH-1:0] r_hist_data [0:HIST_BINS-1];
    reg [HIST_WIDTH-1:0] g_hist_data [0:HIST_BINS-1];
    reg [HIST_WIDTH-1:0] b_hist_data [0:HIST_BINS-1];
    integer current_bin_capture;
    integer max_r_value, max_g_value, max_b_value;
    
    integer bin_value, scaled_value;
    integer ret;
    reg [255:0] line_buffer;
    integer capture_count, timeout_counter;
    integer found_non_comment;
    reg [15:0] magic;
    reg [7:0] char;
    reg exit_loop;
    integer r_scaled, g_scaled, b_scaled;

    histogram_rgb #(
        .DATA_WIDTH(DATA_WIDTH),
        .HIST_BINS(HIST_BINS),
        .HIST_WIDTH(HIST_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(data_valid),
        .r_data(r_data),
        .g_data(g_data),
        .b_data(b_data),
        .clear_hist(clear_hist),
        .enable_hist(enable_hist),
        .hist_ready(hist_ready),
        .r_hist_value(r_hist_value),
        .g_hist_value(g_hist_value),
        .b_hist_value(b_hist_value),
        .hist_bin(hist_bin),
        .hist_valid(hist_valid),
        .channel_sel(channel_sel)
    );
    
    always #(CLK_PERIOD/2) clk = ~clk;
    
    initial begin
        clk = 0;
        rst_n = 0;
        data_valid = 0;
        r_data = 0;
        g_data = 0;
        b_data = 0;
        clear_hist = 0;
        enable_hist = 0;
        pixel_index = 0;
        bin_value = 0;
        scaled_value = 0;
        capture_count = 0;
        timeout_counter = 0;
        found_non_comment = 0;

        for (i = 0; i < HIST_BINS; i = i + 1) begin
            r_hist_data[i] = 0;
            g_hist_data[i] = 0;
            b_hist_data[i] = 0;
        end
        
        #(CLK_PERIOD*2);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        $display("=== Test 1: Read input from PPM file ===");
        test_ppm_input();
        
        $display("=== Test 2: Output histogram as image files ===");
        output_histogram_images();
        
        $display("=== Test 3: Basic functionality test ===");
        test_basic_functionality();
        
        $display("=== All tests completed ===");
        $finish;
    end
    
    task test_ppm_input;
    begin
        
        ppm_file = $fopen("data/color.ppm", "r");
        if (ppm_file == 0) begin
            $display("Error: Cannot open color.ppm file");
            $finish;
        end
        
        exit_loop = 0;
        while (!exit_loop) begin
            ret = $fscanf(ppm_file, "%s", magic);
            if (ret == 0) begin
                char = $fgetc(ppm_file);
                if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
            end else exit_loop = 1;
        end
        
        if (magic != "P3") begin
            $display("Error: Expected P3 format, actually got %s", magic);
            $fclose(ppm_file);
            $finish;
        end
        
        exit_loop = 0;
        while (!exit_loop) begin
            ret = $fscanf(ppm_file, "%d %d", width, height);
            if (ret != 2) begin
                char = $fgetc(ppm_file);
                if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
            end else exit_loop = 1;
        end
        
        exit_loop = 0;
        while (!exit_loop) begin
            ret = $fscanf(ppm_file, "%d", max_value);
            if (ret != 1) begin
                char = $fgetc(ppm_file);
                if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
            end else exit_loop = 1;
        end
        
        $display("PPM file info: width=%d, height=%d, max value=%d", width, height, max_value);
        pixel_count = width * height;
        
        enable_hist = 1;
        pixel_index = 0;
        
        for (i = 0; i < pixel_count; i = i + 1) begin
            @(posedge clk);
            ret = $fscanf(ppm_file, "%d %d %d", r_pixel, g_pixel, b_pixel);
            
            if (ret != 3) begin
                $display("Error: Failed to read pixel data, expected 3 values, actually read %d", ret);
                $fclose(ppm_file);
                $finish;
            end
            
            data_valid = 1;
            r_data = r_pixel;
            g_data = g_pixel;
            b_data = b_pixel;
            
            pixel_index = pixel_index + 1;
            if (pixel_index % 1000 == 0) begin
                $display("Processed %d/%d pixels", pixel_index, pixel_count);
            end
        end
        
        @(posedge clk);
        data_valid = 0;
        enable_hist = 0;
        
        $fclose(ppm_file);
        
        wait(hist_ready);
        #(CLK_PERIOD*10);
        
        $display("✓ PPM file input completed, total processed %d pixels", pixel_count);
    end
    endtask
    
    task output_histogram_images;
    begin
        wait(hist_ready);
        #(CLK_PERIOD*100);
        
        $display("Starting histogram data capture...");
        
        max_r_value = 0;
        max_g_value = 0;
        max_b_value = 0;
        
        for (i = 0; i < HIST_BINS; i = i + 1) begin
            r_hist_data[i] = 0;
            g_hist_data[i] = 0;
            b_hist_data[i] = 0;
        end
        
        fork
            begin: capture_histogram_data
                capture_count = 0;
                timeout_counter = 0;
                
                $display("Starting to monitor histogram output sequence...");
                
                while (capture_count < HIST_BINS * 3 && timeout_counter < 10000) begin
                    @(posedge clk);
                    timeout_counter = timeout_counter + 1;
                    
                    if (hist_valid) begin
                        current_bin_capture = hist_bin;
                        case (channel_sel)
                            2'b00: begin
                                r_hist_data[current_bin_capture] = r_hist_value;
                                if (current_bin_capture == HIST_BINS-1) begin
                                    $display("R channel data capture completed");
                                end
                            end
                            2'b01: begin
                                g_hist_data[current_bin_capture] = g_hist_value;
                                if (current_bin_capture == HIST_BINS-1) begin
                                    $display("G channel data capture completed");
                                end
                            end
                            2'b10: begin
                                b_hist_data[current_bin_capture] = b_hist_value;
                                if (current_bin_capture == HIST_BINS-1) begin
                                    $display("B channel data capture completed");
                                end
                            end
                        endcase
                        capture_count = capture_count + 1;
                        
                        if (capture_count % 100 == 0) begin
                            $display("Captured %d histogram data points", capture_count);
                        end
                    end
                end
                
                if (timeout_counter >= 10000) begin
                    $display("Warning: Histogram data capture timeout");
                end
                
                for (i = 0; i < HIST_BINS; i = i + 1) begin
                    if (r_hist_data[i] > max_r_value) max_r_value = r_hist_data[i];
                    if (g_hist_data[i] > max_g_value) max_g_value = g_hist_data[i];
                    if (b_hist_data[i] > max_b_value) max_b_value = b_hist_data[i];
                end
                
                $display("Histogram maximum values: R=%d, G=%d, B=%d", max_r_value, max_g_value, max_b_value);
                $display("Histogram data capture completed, starting to generate image files...");
                
                hist_r_file = $fopen("output/histogram_r_channel.pgm", "w");
                hist_g_file = $fopen("output/histogram_g_channel.pgm", "w");
                hist_b_file = $fopen("output/histogram_b_channel.pgm", "w");
                hist_combined_file = $fopen("output/histogram_combined.ppm", "w");
                
                $fdisplay(hist_r_file, "P2");
                $fdisplay(hist_r_file, "%d 256", HIST_BINS);
                $fdisplay(hist_r_file, "255");
                
                $fdisplay(hist_g_file, "P2");
                $fdisplay(hist_g_file, "%d 256", HIST_BINS);
                $fdisplay(hist_g_file, "255");
                
                $fdisplay(hist_b_file, "P2");
                $fdisplay(hist_b_file, "%d 256", HIST_BINS);
                $fdisplay(hist_b_file, "255");
                
                $fdisplay(hist_combined_file, "P3");
                $fdisplay(hist_combined_file, "%d 256", HIST_BINS);
                $fdisplay(hist_combined_file, "255");
                
                for (i = 0; i < 256; i = i + 1) begin
                    for (j = 0; j < HIST_BINS; j = j + 1) begin
                        if (max_r_value > 0) 
                            scaled_value = (r_hist_data[j] * 255) / max_r_value;
                        else
                            scaled_value = 0;
                            
                        if (i < scaled_value) 
                            $fwrite(hist_r_file, "%d ", 255);
                        else
                            $fwrite(hist_r_file, "%d ", 0);
                    end
                    $fdisplay(hist_r_file, "");
                    
                    for (j = 0; j < HIST_BINS; j = j + 1) begin
                        if (max_g_value > 0) 
                            scaled_value = (g_hist_data[j] * 255) / max_g_value;
                        else
                            scaled_value = 0;
                            
                        if (i < scaled_value) 
                            $fwrite(hist_g_file, "%d ", 255);
                        else
                            $fwrite(hist_g_file, "%d ", 0);
                    end
                    $fdisplay(hist_g_file, "");
                    
                    for (j = 0; j < HIST_BINS; j = j + 1) begin
                        if (max_b_value > 0) 
                            scaled_value = (b_hist_data[j] * 255) / max_b_value;
                        else
                            scaled_value = 0;
                            
                        if (i < scaled_value) 
                            $fwrite(hist_b_file, "%d ", 255);
                        else
                            $fwrite(hist_b_file, "%d ", 0);
                    end
                    $fdisplay(hist_b_file, "");
                    
                    for (j = 0; j < HIST_BINS; j = j + 1) begin
                        if (max_r_value > 0) 
                            r_scaled = (r_hist_data[j] * 255) / max_r_value;
                        else
                            r_scaled = 0;
                            
                        if (max_g_value > 0) 
                            g_scaled = (g_hist_data[j] * 255) / max_g_value;
                        else
                            g_scaled = 0;
                            
                        if (max_b_value > 0) 
                            b_scaled = (b_hist_data[j] * 255) / max_b_value;
                        else
                            b_scaled = 0;
                        
                        if (i == r_scaled) begin
                            $fwrite(hist_combined_file, "255 0 0 ");
                        end else if (i == g_scaled) begin
                            $fwrite(hist_combined_file, "0 255 0 ");
                        end else if (i == b_scaled) begin
                            $fwrite(hist_combined_file, "0 0 255 ");
                        end else if (i == r_scaled - 1 || i == r_scaled + 1) begin
                            $fwrite(hist_combined_file, "128 0 0 ");
                        end else if (i == g_scaled - 1 || i == g_scaled + 1) begin
                            $fwrite(hist_combined_file, "0 128 0 ");
                        end else if (i == b_scaled - 1 || i == b_scaled + 1) begin
                            $fwrite(hist_combined_file, "0 0 128 ");
                        end else begin
                            $fwrite(hist_combined_file, "0 0 0 ");
                        end
                    end
                    $fdisplay(hist_combined_file, "");
                end
                
                $fclose(hist_r_file);
                $fclose(hist_g_file);
                $fclose(hist_b_file);
                $fclose(hist_combined_file);
                
                $display("Histogram image files output completed");
                $display("   - histogram_r_channel.pgm (R channel histogram)");
                $display("   - histogram_g_channel.pgm (G channel histogram)");
                $display("   - histogram_b_channel.pgm (B channel histogram)");
                $display("   - histogram_combined.ppm (combined histogram)");
            end
        join
        
        $display("Histogram image generation task completed");
    end
    endtask
    
    task test_basic_functionality;
    begin
        enable_hist = 1;
        for (i = 0; i < total_pixels; i = i + 1) begin
            @(posedge clk);
            data_valid = 1;
            r_data = $random % HIST_BINS;
            g_data = $random % HIST_BINS;
            b_data = $random % HIST_BINS;
        end
        @(posedge clk);
        data_valid = 0;
        enable_hist = 0;
        
        wait(hist_ready);
        #(CLK_PERIOD*10);
        
        verify_output_sequence();
    end
    endtask
    
    task verify_output_sequence;
    begin
        r_bin_count = 0;
        g_bin_count = 0;
        b_bin_count = 0;
        
        fork
            begin: monitor_output
                while (1) begin
                    @(posedge clk);
                    if (hist_valid) begin
                        case (channel_sel)
                            2'b00: r_bin_count = r_bin_count + 1;
                            2'b01: g_bin_count = g_bin_count + 1;
                            2'b10: b_bin_count = b_bin_count + 1;
                        endcase
                        
                        if (r_bin_count == HIST_BINS && g_bin_count == HIST_BINS && b_bin_count == HIST_BINS) begin
                            disable monitor_output;
                        end
                    end
                end
            end
        join
        
        if (r_bin_count == HIST_BINS && g_bin_count == HIST_BINS && b_bin_count == HIST_BINS) begin
            $display("Output sequence verification successful: R=%0d, G=%0d, B=%0d", r_bin_count, g_bin_count, b_bin_count);
        end else begin
            $display("Output sequence verification failed: R=%0d, G=%0d, B=%0d", r_bin_count, g_bin_count, b_bin_count);
        end
    end
    endtask
    
    initial begin
        $dumpfile("histogram_rgb.vcd");
        $dumpvars(0, tb_histogram_rgb);
    end
    
endmodule