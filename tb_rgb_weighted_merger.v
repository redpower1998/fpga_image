`timescale 1ns/1ps

module tb_rgb_weighted_merger;

reg         clk;
reg         rst_n;
reg         data1_valid;
reg [7:0]   r1, g1, b1;
reg         data2_valid;
reg [7:0]   r2, g2, b2;
reg [7:0]   weight1, weight2;
wire        data_out_valid;
wire [7:0]  r_out, g_out, b_out;

rgb_weighted_merger u_rgb_weighted_merger (
    .clk           (clk),
    .rst_n         (rst_n),
    .r1_in         (r1),
    .g1_in         (g1),
    .b1_in         (b1),
    .data1_valid   (data1_valid),
    .r2_in         (r2),
    .g2_in         (g2),
    .b2_in         (b2),
    .data2_valid   (data2_valid),
    .weight1       (weight1),
    .weight2       (weight2),
    .r_out         (r_out),
    .g_out         (g_out),
    .b_out         (b_out),
    .data_out_valid(data_out_valid)
);

initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    data1_valid = 1'b0;
    data2_valid = 1'b0;
    r1 = 8'd0; g1 = 8'd0; b1 = 8'd0;
    r2 = 8'd0; g2 = 8'd0; b2 = 8'd0;
    weight1 = 8'd128;
    weight2 = 8'd128;
    #100;
    rst_n = 1'b1;
    #100;

    $display("=== Starting module functionality verification ===");
    test_weighted_merge(255, 128, 64, 64, 192, 255, 64, 64);
    test_weighted_merge(255, 128, 64, 64, 192, 255, 200, 56);
    test_weighted_merge(255, 128, 64, 64, 192, 255, 255, 1);
    test_weighted_merge(255, 128, 64, 64, 192, 255, 1, 255);
    $display("=== Module functionality verification completed ===");
    #100;

    $display("=== Starting image file merging (50%% weight) ===");
    weight1 = 8'd128;
    weight2 = 8'd128;
    merge_ppm_files("data/rgb1.ppm",
                    "data/love.ppm",
                    "output/out_merged_50_50.ppm");
    #100;

    $display("=== Starting image file merging (70%%/30%% weight) ===");
    weight1 = 8'd179;
    weight2 = 8'd77;
    merge_ppm_files("data/rgb1.ppm",
                    "data/love.ppm",
                    "output/out_merged_70_30.ppm");
    #100;

    $display("=== Starting image file merging (30%%/70%% weight) ===");
    weight1 = 8'd77;
    weight2 = 8'd179;
    merge_ppm_files("data/rgb1.ppm",
                    "data/love.ppm",
                    "output/out_merged_30_70.ppm");
    #100;

    $display("=== All merging tests completed ===");
    #1000;
    $finish;
end

task test_weighted_merge;
    input [7:0] r1_in, g1_in, b1_in;
    input [7:0] r2_in, g2_in, b2_in;
    input [7:0] w1, w2;
    reg [15:0] expected_r, expected_g, expected_b;
    reg [7:0] calc_r, calc_g, calc_b;
    begin
        @(posedge clk);
        data1_valid <= 1'b1;
        data2_valid <= 1'b1;
        r1 <= r1_in; g1 <= g1_in; b1 <= b1_in;
        r2 <= r2_in; g2 <= g2_in; b2 <= b2_in;
        weight1 <= w1;
        weight2 <= w2;

        @(posedge clk);
        data1_valid <= 1'b0;
        data2_valid <= 1'b0;

        wait(data_out_valid);
        @(posedge clk);

        if (w1 + w2 > 0) begin
            expected_r = (r1_in * w1 + r2_in * w2) / (w1 + w2);
            expected_g = (g1_in * w1 + g2_in * w2) / (w1 + w2);
            expected_b = (b1_in * w1 + b2_in * w2) / (w1 + w2);
            calc_r = expected_r;
            calc_g = expected_g;
            calc_b = expected_b;
        end else begin
            calc_r = 8'b0;
            calc_g = 8'b0;
            calc_b = 8'b0;
        end

        $display("Test: RGB1=(%d,%d,%d), RGB2=(%d,%d,%d), Weights=(%d,%d)", 
                 r1_in, g1_in, b1_in, r2_in, g2_in, b2_in, w1, w2);
        $display("      -> Output=(%d,%d,%d), Expected=(%d,%d,%d), valid=%b", 
                 r_out, g_out, b_out, calc_r, calc_g, calc_b, data_out_valid);
        
        if (r_out !== calc_r || g_out !== calc_g || b_out !== calc_b) begin
            $display("ERROR: Output mismatch!");
        end
    end
endtask

task merge_ppm_files;
    input [80*8-1:0] ppm_filename1;
    input [80*8-1:0] ppm_filename2;
    input [80*8-1:0] output_filename;
    integer ppm_file1, ppm_file2, output_file;
    integer width1, height1, max_val1;
    integer width2, height2, max_val2;
    integer i, j, r1_val, g1_val, b1_val, r2_val, g2_val, b2_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic1, magic2;
    reg exit_loop;
    integer pixel_count;
    reg file_end;
    integer timeout_counter;

    begin
        ppm_file1 = $fopen(ppm_filename1, "r");
        if (ppm_file1 == 0) begin
            $display("Error: Cannot open input file %s", ppm_filename1);
            $finish;
        end

        ppm_file2 = $fopen(ppm_filename2, "r");
        if (ppm_file2 == 0) begin
            $display("Error: Cannot open input file %s", ppm_filename2);
            $fclose(ppm_file1);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file1, "%s", magic1);
            if (scan_result == 0) begin
                char = $fgetc(ppm_file1);
                if (char == "#") while ($fgetc(ppm_file1) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        if (magic1 != "P3") begin
            $display("Error: File1 expected P3 format, got %s", magic1);
            $fclose(ppm_file1);
            $fclose(ppm_file2);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file2, "%s", magic2);
            if (scan_result == 0) begin
                char = $fgetc(ppm_file2);
                if (char == "#") while ($fgetc(ppm_file2) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        if (magic2 != "P3") begin
            $display("Error: File2 expected P3 format, got %s", magic2);
            $fclose(ppm_file1);
            $fclose(ppm_file2);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file1, "%d %d", width1, height1);
            if (scan_result != 2) begin
                char = $fgetc(ppm_file1);
                if (char == "#") while ($fgetc(ppm_file1) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file1, "%d", max_val1);
            if (scan_result != 1) begin
                char = $fgetc(ppm_file1);
                if (char == "#") while ($fgetc(ppm_file1) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file2, "%d %d", width2, height2);
            if (scan_result != 2) begin
                char = $fgetc(ppm_file2);
                if (char == "#") while ($fgetc(ppm_file2) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file2, "%d", max_val2);
            if (scan_result != 1) begin
                char = $fgetc(ppm_file2);
                if (char == "#") while ($fgetc(ppm_file2) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        if (width1 != width2 || height1 != height2) begin
            $display("Error: Image dimensions mismatch: (%dx%d) vs (%dx%d)", 
                     width1, height1, width2, height2);
            $fclose(ppm_file1);
            $fclose(ppm_file2);
            $finish;
        end

        $display("Merging images: %dx%d, max_value1=%d, max_value2=%d", 
                 width1, height1, max_val1, max_val2);

        output_file = $fopen(output_filename, "w");
        if (output_file == 0) begin
            $display("Error: Cannot create output file %s", output_filename);
            $fclose(ppm_file1);
            $fclose(ppm_file2);
            $finish;
        end

        $fdisplay(output_file, "P3");
        $fdisplay(output_file, "%d %d", width1, height1);
        $fdisplay(output_file, "%d", (max_val1 > max_val2) ? max_val1 : max_val2);

        pixel_count = 0;
        file_end = 1'b0;

        for (i = 0; i < height1 && !file_end; i = i + 1) begin
            for (j = 0; j < width1 && !file_end; j = j + 1) begin
                exit_loop = 1'b0;
                while (!exit_loop && !file_end) begin
                    scan_result = $fscanf(ppm_file1, "%d %d %d", r1_val, g1_val, b1_val);
                    if (scan_result == 3) begin
                        exit_loop = 1'b1;
                    end else begin
                        if ($feof(ppm_file1)) begin
                            file_end = 1'b1;
                            $display("Warning: File1 ended prematurely at pixel %d", pixel_count);
                        end else begin
                            char = $fgetc(ppm_file1);
                            if (char == "#") begin
                                while ($fgetc(ppm_file1) != "\n" && !$feof(ppm_file1)) begin end
                            end
                        end
                    end
                end

                exit_loop = 1'b0;
                while (!exit_loop && !file_end) begin
                    scan_result = $fscanf(ppm_file2, "%d %d %d", r2_val, g2_val, b2_val);
                    if (scan_result == 3) begin
                        exit_loop = 1'b1;
                    end else begin
                        if ($feof(ppm_file2)) begin
                            file_end = 1'b1;
                            $display("Warning: File2 ended prematurely at pixel %d", pixel_count);
                        end else begin
                            char = $fgetc(ppm_file2);
                            if (char == "#") begin
                                while ($fgetc(ppm_file2) != "\n" && !$feof(ppm_file2)) begin end
                            end
                        end
                    end
                end

                if (file_end) begin
                    j = width1;
                    i = height1;
                end else begin
                    @(posedge clk);
                    data1_valid <= 1'b1;
                    data2_valid <= 1'b1;
                    r1 <= r1_val; g1 <= g1_val; b1 <= b1_val;
                    r2 <= r2_val; g2 <= g2_val; b2 <= b2_val;

                    @(posedge clk);
                    data1_valid <= 1'b0;
                    data2_valid <= 1'b0;

                    timeout_counter = 0;
                    while (!data_out_valid && timeout_counter < 100) begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;
                    end

                    if (!data_out_valid) begin
                        $display("Timeout waiting for data_out_valid at pixel %d", pixel_count);
                        file_end = 1'b1;
                        j = width1;
                        i = height1;
                    end else begin
                        $fwrite(output_file, "%0d %0d %0d\n", r_out, g_out, b_out);

                        pixel_count = pixel_count + 1;

                        if (pixel_count % 10000 == 0) begin
                            $display("Processed %d pixels...", pixel_count);
                        end
                    end
                end
            end
        end

        $fclose(ppm_file1);
        $fclose(ppm_file2);
        $fclose(output_file);
        $display("Merged %d pixels successfully", pixel_count);
    end
endtask

initial begin
    $dumpfile("rgb_weighted_merger.vcd");
    $dumpvars(0, tb_rgb_weighted_merger);
end

endmodule