`timescale 1ns/1ps

module tb_gray_to_color;

reg         clk;
reg         rst_n;
reg         data_valid;
reg [7:0]   gray_in;
reg [2:0]   colormap_sel;
wire        data_out_valid;
wire [7:0]  r_out, g_out, b_out;

gray_to_color u_gray_to_color (
    .clk           (clk),
    .rst_n         (rst_n),
    .gray_in       (gray_in),
    .data_valid    (data_valid),
    .colormap_sel  (colormap_sel),
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
    data_valid = 1'b0;
    gray_in = 8'd0;
    colormap_sel = 3'b000;
    #100;
    rst_n = 1'b1;
    #100;

    $display("=== Starting Module Function Verification ===");
    test_colormap(0, 3'b000);
    test_colormap(128, 3'b000);
    test_colormap(255, 3'b000);
    test_colormap(64, 3'b001);
    test_colormap(192, 3'b001);
    test_colormap(37, 3'b010);
    test_colormap(111, 3'b010);
    test_colormap(185, 3'b010);
    $display("=== Module Function Verification Completed ===");
    #100;

    $display("=== Starting Image File Conversion (JET Colormap) ===");
    colormap_sel = 3'b000;
    convert_pgm_to_ppm("data/gray1.pgm",
                       "output/gray1_jet.ppm");
    #100;

    $display("=== Starting Image File Conversion (HSV Colormap) ===");
    colormap_sel = 3'b001;
    convert_pgm_to_ppm("data/gray1.pgm",
                       "output/gray1_hsv.ppm");
    #100;

    $display("=== Starting Image File Conversion (RAINBOW Colormap) ===");
    colormap_sel = 3'b010;
    convert_pgm_to_ppm("data/gray1.pgm",
                       "output/gray1_rainbow.ppm");
    #100;

    $display("=== Starting Image File Conversion (OCEAN Colormap) ===");
    colormap_sel = 3'b011;
    convert_pgm_to_ppm("data/gray1.pgm",
                       "output/gray1_ocean.ppm");
    #100;

    $display("=== Starting Image File Conversion (SUMMER Colormap) ===");
    colormap_sel = 3'b100;
    convert_pgm_to_ppm("data/gray1.pgm",
                       "output/gray1_summer.ppm");
    #100;

    $display("=== Starting Image File Conversion (WINTER Colormap) ===");
    colormap_sel = 3'b101;
    convert_pgm_to_ppm("data/gray1.pgm",
                       "output/gray1_winter.ppm");
    #100;

    $display("=== Starting Image File Conversion (AUTUMN Colormap) ===");
    colormap_sel = 3'b110;
    convert_pgm_to_ppm("data/gray1.pgm",
                       "output/gray1_autumn.ppm");
    #100;

    $display("=== Starting Image File Conversion (BONE Colormap) ===");
    colormap_sel = 3'b111;
    convert_pgm_to_ppm("data/gray1.pgm",
                       "output/gray1_bone.ppm");
    #100;

    $display("=== Starting Gray Stripe Image Generation ===");
    generate_gray_stripes(320, 256, "output/gray_stripes_jet.ppm", 3'b000);
    generate_gray_stripes(320, 256, "output/gray_stripes_hsv.ppm", 3'b001);
    generate_gray_stripes(320, 256, "output/gray_stripes_rainbow.ppm", 3'b010);
    generate_gray_stripes(320, 256, "output/gray_stripes_ocean.ppm", 3'b011);
    generate_gray_stripes(320, 256, "output/gray_stripes_summer.ppm", 3'b100);
    generate_gray_stripes(320, 256, "output/gray_stripes_winter.ppm", 3'b101);
    generate_gray_stripes(320, 256, "output/gray_stripes_autumn.ppm", 3'b110);
    generate_gray_stripes(320, 256, "output/gray_stripes_bone.ppm", 3'b111);

    $display("=== All Colormap Tests Completed ===");
    #1000;
    $finish;
end
task generate_gray_stripes;
    input integer width;
    input integer height;
    input [80*8-1:0] ppm_filename;
    input [2:0] map_sel;
    integer ppm_file;
    integer i, j, gray_val;
    integer stripe_height;
    integer current_stripe;
    integer pixel_count;
    integer timeout_counter;
    begin
        colormap_sel = map_sel;
        
        stripe_height = height / 256;
        if (stripe_height < 1) stripe_height = 1;
        
        $display("Generating gray stripes: %dx%d, colormap=%d, stripe_height=%d", 
                 width, height, map_sel, stripe_height);

        ppm_file = $fopen(ppm_filename, "w");
        if (ppm_file == 0) begin
            $display("Error: Cannot create output file %s", ppm_filename);
            $finish;
        end

        $fdisplay(ppm_file, "P3");
        $fdisplay(ppm_file, "%d %d", width, height);
        $fdisplay(ppm_file, "255");

        pixel_count = 0;

        for (i = 0; i < height; i = i + 1) begin
            current_stripe = i / stripe_height;
            if (current_stripe > 255) current_stripe = 255;
            gray_val = current_stripe;

            for (j = 0; j < width; j = j + 1) begin
                @(posedge clk);
                data_valid <= 1'b1;
                gray_in <= gray_val;

                @(posedge clk);
                data_valid <= 1'b0;

                timeout_counter = 0;
                while (!data_out_valid && timeout_counter < 100) begin
                    @(posedge clk);
                    timeout_counter = timeout_counter + 1;
                end

                if (!data_out_valid) begin
                    $display("Timeout waiting for data_out_valid at pixel %d", pixel_count);
                    $fclose(ppm_file);
                    $finish;
                end else begin
                    $fwrite(ppm_file, "%0d %0d %0d\n", r_out, g_out, b_out);

                    pixel_count = pixel_count + 1;

                    if (pixel_count % 10000 == 0) begin
                        $display("Processed %d pixels...", pixel_count);
                    end
                end
            end
        end

        $fclose(ppm_file);
        $display("Generated %d pixels successfully for %s", pixel_count, ppm_filename);
    end
endtask
task test_colormap;
    input [7:0] gray_val;
    input [2:0] map_sel;
    reg [7:0] expected_r, expected_g, expected_b;
    begin
        @(posedge clk);
        data_valid <= 1'b1;
        gray_in <= gray_val;
        colormap_sel <= map_sel;

        @(posedge clk);
        data_valid <= 1'b0;

        wait(data_out_valid);
        @(posedge clk);

        case (map_sel)
            3'b000: begin
                if (gray_val < 64) begin
                    expected_r = 0;
                    expected_g = 0;
                    expected_b = gray_val * 4;
                end else if (gray_val < 128) begin
                    expected_r = 0;
                    expected_g = (gray_val - 64) * 4;
                    expected_b = 255;
                end else if (gray_val < 192) begin
                    expected_r = (gray_val - 128) * 4;
                    expected_g = 255;
                    expected_b = 255 - (gray_val - 128) * 4;
                end else begin
                    expected_r = 255;
                    expected_g = 255 - (gray_val - 192) * 4;
                    expected_b = 0;
                end
            end
            
            3'b001: begin
                if (gray_val < 43) begin
                    expected_r = 255;
                    expected_g = gray_val * 6;
                    expected_b = 0;
                end else if (gray_val < 85) begin
                    expected_r = 255 - (gray_val - 43) * 6;
                    expected_g = 255;
                    expected_b = 0;
                end else if (gray_val < 128) begin
                    expected_r = 0;
                    expected_g = 255;
                    expected_b = (gray_val - 85) * 6;
                end else if (gray_val < 170) begin
                    expected_r = 0;
                    expected_g = 255 - (gray_val - 128) * 6;
                    expected_b = 255;
                end else if (gray_val < 213) begin
                    expected_r = (gray_val - 170) * 6;
                    expected_g = 0;
                    expected_b = 255;
                end else begin
                    expected_r = 255;
                    expected_g = 0;
                    expected_b = 255 - (gray_val - 213) * 6;
                end
            end
            
            3'b010: begin
                if (gray_val < 37) begin
                    expected_r = 255;
                    expected_g = 0;
                    expected_b = 0;
                end else if (gray_val < 74) begin
                    expected_r = 255;
                    expected_g = (gray_val - 37) * 7;
                    expected_b = 0;
                end else if (gray_val < 111) begin
                    expected_r = 255;
                    expected_g = 255;
                    expected_b = 0;
                end else if (gray_val < 148) begin
                    expected_r = 255 - (gray_val - 111) * 7;
                    expected_g = 255;
                    expected_b = 0;
                end else if (gray_val < 185) begin
                    expected_r = 0;
                    expected_g = 255;
                    expected_b = (gray_val - 148) * 7;
                end else if (gray_val < 222) begin
                    expected_r = 0;
                    expected_g = 255 - (gray_val - 185) * 7;
                    expected_b = 255;
                end else begin
                    expected_r = (gray_val - 222) * 8;
                    expected_g = 0;
                    expected_b = 255;
                end
            end
            
            default: begin
                expected_r = gray_val;
                expected_g = gray_val;
                expected_b = gray_val;
            end
        endcase

        $display("Test: Gray=%d, Colormap=%d", gray_val, map_sel);
        $display("      -> Output=(%d,%d,%d), Expected=(%d,%d,%d), valid=%b", 
                 r_out, g_out, b_out, expected_r, expected_g, expected_b, data_out_valid);
        
        if (r_out !== expected_r || g_out !== expected_g || b_out !== expected_b) begin
            $display("ERROR: Output mismatch!");
        end
    end
endtask

task convert_pgm_to_ppm;
    input [80*8-1:0] pgm_filename;
    input [80*8-1:0] ppm_filename;
    integer pgm_file, ppm_file;
    integer width, height, max_val;
    integer i, j, gray_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop;
    integer pixel_count;
    reg file_end;
    integer timeout_counter;

    begin
        pgm_file = $fopen(pgm_filename, "r");
        if (pgm_file == 0) begin
            $display("Error: Cannot open input file %s", pgm_filename);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file, "%s", magic);
            if (scan_result == 0) begin
                char = $fgetc(pgm_file);
                if (char == "#") while ($fgetc(pgm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        if (magic != "P2") begin
            $display("Error: File expected P2 format, got %s", magic);
            $fclose(pgm_file);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file, "%d %d", width, height);
            if (scan_result != 2) begin
                char = $fgetc(pgm_file);
                if (char == "#") while ($fgetc(pgm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(pgm_file, "%d", max_val);
            if (scan_result != 1) begin
                char = $fgetc(pgm_file);
                if (char == "#") while ($fgetc(pgm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        $display("Converting image: %dx%d, max_value=%d", width, height, max_val);

        ppm_file = $fopen(ppm_filename, "w");
        if (ppm_file == 0) begin
            $display("Error: Cannot create output file %s", ppm_filename);
            $fclose(pgm_file);
            $finish;
        end

        $fdisplay(ppm_file, "P3");
        $fdisplay(ppm_file, "%d %d", width, height);
        $fdisplay(ppm_file, "%d", max_val);

        pixel_count = 0;
        file_end = 1'b0;

        for (i = 0; i < height && !file_end; i = i + 1) begin
            for (j = 0; j < width && !file_end; j = j + 1) begin
                exit_loop = 1'b0;
                while (!exit_loop && !file_end) begin
                    scan_result = $fscanf(pgm_file, "%d", gray_val);
                    if (scan_result == 1) begin
                        exit_loop = 1'b1;
                    end else begin
                        if ($feof(pgm_file)) begin
                            file_end = 1'b1;
                            $display("Warning: File ended prematurely at pixel %d", pixel_count);
                        end else begin
                            char = $fgetc(pgm_file);
                            if (char == "#") begin
                                while ($fgetc(pgm_file) != "\n" && !$feof(pgm_file)) begin end
                            end
                        end
                    end
                end

                if (file_end) begin
                    j = width;
                    i = height;
                end else begin
                    @(posedge clk);
                    data_valid <= 1'b1;
                    gray_in <= gray_val;

                    @(posedge clk);
                    data_valid <= 1'b0;

                    timeout_counter = 0;
                    while (!data_out_valid && timeout_counter < 100) begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;
                    end

                    if (!data_out_valid) begin
                        $display("Timeout waiting for data_out_valid at pixel %d", pixel_count);
                        file_end = 1'b1;
                        j = width;
                        i = height;
                    end else begin
                        $fwrite(ppm_file, "%0d %0d %0d\n", r_out, g_out, b_out);

                        pixel_count = pixel_count + 1;

                        if (pixel_count % 10000 == 0) begin
                            $display("Processed %d pixels...", pixel_count);
                        end
                    end
                end
            end
        end

        $fclose(pgm_file);
        $fclose(ppm_file);
        $display("Converted %d pixels successfully", pixel_count);
    end
endtask

initial begin
    $dumpfile("gray_to_color.vcd");
    $dumpvars(0, tb_gray_to_color);
end

endmodule