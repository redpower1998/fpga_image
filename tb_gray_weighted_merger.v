`timescale 1ns/1ps

module tb_gray_weighted_merger;

reg         clk;
reg         rst_n;
reg         data1_valid;
reg [7:0]   gray1;
reg         data2_valid;
reg [7:0]   gray2;
reg [7:0]   weight1, weight2;
wire        data_out_valid;
wire [7:0]  gray_out;

gray_weighted_merger u_gray_weighted_merger (
    .clk           (clk),
    .rst_n         (rst_n),
    .gray1_in      (gray1),
    .data1_valid   (data1_valid),
    .gray2_in      (gray2),
    .data2_valid   (data2_valid),
    .weight1       (weight1),
    .weight2       (weight2),
    .gray_out      (gray_out),
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
    gray1 = 8'd0;
    gray2 = 8'd0;
    weight1 = 8'd128;
    weight2 = 8'd128;
    #100;
    rst_n = 1'b1;
    #100;

    $display("=== Starting Module Function Verification ===");
    test_weighted_merge(255, 64, 128, 128);
    test_weighted_merge(255, 64, 200, 56);
    test_weighted_merge(255, 64, 255, 1);
    test_weighted_merge(255, 64, 1, 255);
    $display("=== Module Function Verification Completed ===");
    #100;

    $display("=== Starting Image File Merging (50%% Weight) ===");
    weight1 = 8'd128;
    weight2 = 8'd128;
    merge_pgm_files("data/gray1.pgm",
                    "data/baby.pgm",
                    "output/merged_gray_50_50.pgm");
    #100;

    $display("=== Starting Image File Merging (70%%/30%% Weight) ===");
    weight1 = 8'd179;
    weight2 = 8'd77;
    merge_pgm_files("data/gray1.pgm",
                    "data/baby.pgm",
                    "output/merged_gray_70_30.pgm");
    #100;

    $display("=== Starting Image File Merging (30%%/70%% Weight) ===");
    weight1 = 8'd77;
    weight2 = 8'd179;
    merge_pgm_files("data/gray1.pgm",
                    "data/baby.pgm",
                    "output/merged_gray_30_70.pgm");
    #100;

    $display("=== All Merging Tests Completed ===");
    #1000;
    $finish;
end

task test_weighted_merge;
    input [7:0] gray1_in, gray2_in;
    input [7:0] w1, w2;
    reg [15:0] expected_gray;
    reg [7:0] calc_gray;
    begin
        @(posedge clk);
        data1_valid <= 1'b1;
        data2_valid <= 1'b1;
        gray1 <= gray1_in;
        gray2 <= gray2_in;
        weight1 <= w1;
        weight2 <= w2;

        @(posedge clk);
        data1_valid <= 1'b0;
        data2_valid <= 1'b0;

        wait(data_out_valid);
        @(posedge clk);

        if (w1 + w2 > 0) begin
            expected_gray = (gray1_in * w1 + gray2_in * w2) / (w1 + w2);
            calc_gray = expected_gray;
        end else begin
            calc_gray = 8'b0;
        end

        $display("Test: Gray1=%d, Gray2=%d, Weights=(%d,%d)", 
                 gray1_in, gray2_in, w1, w2);
        $display("      -> Output=%d, Expected=%d, valid=%b", 
                 gray_out, calc_gray, data_out_valid);
        
        if (gray_out !== calc_gray) begin
            $display("ERROR: Output mismatch!");
        end
    end
endtask

task merge_pgm_files;
    input [80*8-1:0] pgm_filename1;
    input [80*8-1:0] pgm_filename2;
    input [80*8-1:0] output_filename;
    integer pgm_file1, pgm_file2, output_file;
    integer width1, height1, max_val1;
    integer width2, height2, max_val2;
    integer i, j, gray1_val, gray2_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic1, magic2;
    reg exit_loop;
    integer pixel_count;
    reg file_end;
    integer timeout_counter;

    begin
        pgm_file1 = $fopen(pgm_filename1, "r");
        if (pgm_file1 == 0) begin
            $display("Error: Cannot open input file %s", pgm_filename1);
            $finish;
        end

        pgm_file2 = $fopen(pgm_filename2, "r");
        if (pgm_file2 == 0) begin
            $display("Error: Cannot open input file %s", pgm_filename2);
            $fclose(pgm_file1);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file1, "%s", magic1);
            if (scan_result == 0) begin
                char = $fgetc(pgm_file1);
                if (char == "#") while ($fgetc(pgm_file1) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        if (magic1 != "P2") begin
            $display("Error: File1 expected P2 format, got %s", magic1);
            $fclose(pgm_file1);
            $fclose(pgm_file2);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file2, "%s", magic2);
            if (scan_result == 0) begin
                char = $fgetc(pgm_file2);
                if (char == "#") while ($fgetc(pgm_file2) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        if (magic2 != "P2") begin
            $display("Error: File2 expected P2 format, got %s", magic2);
            $fclose(pgm_file1);
            $fclose(pgm_file2);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file1, "%d %d", width1, height1);
            if (scan_result != 2) begin
                char = $fgetc(pgm_file1);
                if (char == "#") while ($fgetc(pgm_file1) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file1, "%d", max_val1);
            if (scan_result != 1) begin
                char = $fgetc(pgm_file1);
                if (char == "#") while ($fgetc(pgm_file1) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file2, "%d %d", width2, height2);
            if (scan_result != 2) begin
                char = $fgetc(pgm_file2);
                if (char == "#") while ($fgetc(pgm_file2) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file2, "%d", max_val2);
            if (scan_result != 1) begin
                char = $fgetc(pgm_file2);
                if (char == "#") while ($fgetc(pgm_file2) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        if (width1 != width2 || height1 != height2) begin
            $display("Error: Image dimensions mismatch: (%dx%d) vs (%dx%d)", 
                     width1, height1, width2, height2);
            $fclose(pgm_file1);
            $fclose(pgm_file2);
            $finish;
        end

        $display("Merging images: %dx%d, max_value1=%d, max_value2=%d", 
                 width1, height1, max_val1, max_val2);

        output_file = $fopen(output_filename, "w");
        if (output_file == 0) begin
            $display("Error: Cannot create output file %s", output_filename);
            $fclose(pgm_file1);
            $fclose(pgm_file2);
            $finish;
        end

        $fdisplay(output_file, "P2");
        $fdisplay(output_file, "%d %d", width1, height1);
        $fdisplay(output_file, "%d", (max_val1 > max_val2) ? max_val1 : max_val2);

        pixel_count = 0;
        file_end = 1'b0;

        for (i = 0; i < height1 && !file_end; i = i + 1) begin
            for (j = 0; j < width1 && !file_end; j = j + 1) begin
                exit_loop = 1'b0;
                while (!exit_loop && !file_end) begin
                    scan_result = $fscanf(pgm_file1, "%d", gray1_val);
                    if (scan_result == 1) begin
                        exit_loop = 1'b1;
                    end else begin
                        if ($feof(pgm_file1)) begin
                            file_end = 1'b1;
                            $display("Warning: File1 ended prematurely at pixel %d", pixel_count);
                        end else begin
                            char = $fgetc(pgm_file1);
                            if (char == "#") begin
                                while ($fgetc(pgm_file1) != "\n" && !$feof(pgm_file1)) begin end
                            end
                        end
                    end
                end

                exit_loop = 1'b0;
                while (!exit_loop && !file_end) begin
                    scan_result = $fscanf(pgm_file2, "%d", gray2_val);
                    if (scan_result == 1) begin
                        exit_loop = 1'b1;
                    end else begin
                        if ($feof(pgm_file2)) begin
                            file_end = 1'b1;
                            $display("Warning: File2 ended prematurely at pixel %d", pixel_count);
                        end else begin
                            char = $fgetc(pgm_file2);
                            if (char == "#") begin
                                while ($fgetc(pgm_file2) != "\n" && !$feof(pgm_file2)) begin end
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
                    gray1 <= gray1_val;
                    gray2 <= gray2_val;

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
                        $fwrite(output_file, "%0d\n", gray_out);

                        pixel_count = pixel_count + 1;

                        if (pixel_count % 10000 == 0) begin
                            $display("Processed %d pixels...", pixel_count);
                        end
                    end
                end
            end
        end

        $fclose(pgm_file1);
        $fclose(pgm_file2);
        $fclose(output_file);
        $display("Merged %d pixels successfully", pixel_count);
    end
endtask

initial begin
    $dumpfile("gray_weighted_merger.vcd");
    $dumpvars(0, tb_gray_weighted_merger);
end

endmodule