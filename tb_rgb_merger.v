`timescale 1ns/1ps

module tb_rgb_merger;

reg         clk;
reg         rst_n;
reg         data_valid;
reg [7:0]   r, g, b;
wire        data_out_valid;
wire [7:0]  r_out, g_out, b_out;

rgb_merger u_rgb_merger (
    .clk           (clk),
    .rst_n         (rst_n),
    .r_in          (r),
    .g_in          (g),
    .b_in          (b),
    .data_valid    (data_valid),
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
    r = 8'd0;
    g = 8'd0;
    b = 8'd0;
    #100;
    rst_n = 1'b1;
    #100;

    $display("=== Starting module functionality verification ===");
    test_pixel(255, 128, 64);
    test_pixel(100, 200, 50);
    test_pixel(0, 255, 128);
    $display("=== Module functionality verification completed ===");
    #100;

    $display("=== Starting complete RGB merging process ===");
    
    extract_channels();
    #100;
    
    merge_channels_to_ppm();
    #100;

    $display("=== RGB merging process completed ===");
    #1000;
    $finish;
end

task test_pixel;
    input [7:0] r_in, g_in, b_in;
    begin
        @(posedge clk);
        data_valid <= 1'b1;
        r <= r_in;
        g <= g_in;
        b <= b_in;

        @(posedge clk);
        data_valid <= 1'b0;

        wait(data_out_valid);
        @(posedge clk);

        $display("Test RGB=(%d,%d,%d) -> Out=(%d,%d,%d), valid=%b", 
                 r_in, g_in, b_in, r_out, g_out, b_out, data_out_valid);
        
        if (r_out !== r_in || g_out !== g_in || b_out !== b_in) begin
            $display("ERROR: Output mismatch!");
        end
    end
endtask

task extract_channels;
    integer r_file, g_file, b_file, input_file;
    integer width, height, max_val;
    integer i, j, r_val, g_val, b_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop;
    integer pixel_count;

    begin
        $display("=== Starting R, G, B channel extraction ===");
        
        input_file = $fopen("data/rgb1.ppm", "r");
        if (input_file == 0) begin
            $display("Error: Cannot open input file rgb1.ppm");
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(input_file, "%s", magic);
            if (scan_result == 0) begin
                char = $fgetc(input_file);
                if (char == "#") while ($fgetc(input_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        
        if (magic != "P3") begin
            $display("Error: Expected P3 format, got %s", magic);
            $fclose(input_file);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(input_file, "%d %d", width, height);
            if (scan_result != 2) begin
                char = $fgetc(input_file);
                if (char == "#") while ($fgetc(input_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(input_file, "%d", max_val);
            if (scan_result != 1) begin
                char = $fgetc(input_file);
                if (char == "#") while ($fgetc(input_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        
        $display("Image parameters: width=%d, height=%d, max_value=%d", width, height, max_val);

        r_file = $fopen("output/out_channel_r.pgm", "w");
        g_file = $fopen("output/out_channel_g.pgm", "w");
        b_file = $fopen("output/out_channel_b.pgm", "w");
        
        if (r_file == 0 || g_file == 0 || b_file == 0) begin
            $display("Error: Cannot create output PGM files");
            $finish;
        end

        $fdisplay(r_file, "P2");
        $fdisplay(r_file, "%d %d", width, height);
        $fdisplay(r_file, "%d", max_val);
        
        $fdisplay(g_file, "P2");
        $fdisplay(g_file, "%d %d", width, height);
        $fdisplay(g_file, "%d", max_val);
        
        $fdisplay(b_file, "P2");
        $fdisplay(b_file, "%d %d", width, height);
        $fdisplay(b_file, "%d", max_val);

        pixel_count = 0;

        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                exit_loop = 1'b0;
                while (!exit_loop) begin
                    scan_result = $fscanf(input_file, "%d %d %d", r_val, g_val, b_val);
                    if (scan_result != 3) begin
                        char = $fgetc(input_file);
                        if (char == "#") while ($fgetc(input_file) != "\n") begin end
                    end else exit_loop = 1'b1;
                end

                $fwrite(r_file, "%d ", r_val);
                $fwrite(g_file, "%d ", g_val);
                $fwrite(b_file, "%d ", b_val);
                
                pixel_count = pixel_count + 1;
            end
            $fwrite(r_file, "\n");
            $fwrite(g_file, "\n");
            $fwrite(b_file, "\n");
        end

        $fclose(input_file);
        $fclose(r_file);
        $fclose(g_file);
        $fclose(b_file);
        $display("Channel extraction completed, processed %d pixels", pixel_count);
    end
endtask

task merge_channels_to_ppm;
    integer r_file, g_file, b_file, ppm_file;
    integer width, height, max_val;
    integer i, j, r_val, g_val, b_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop;
    integer pixel_count;
    reg file_end;

    begin
        $display("=== Starting R, G, B channel merging to PPM ===");
        
        r_file = $fopen("output/out_channel_r.pgm", "r");
        g_file = $fopen("output/out_channel_g.pgm", "r");
        b_file = $fopen("output/out_channel_b.pgm", "r");
        
        if (r_file == 0 || g_file == 0 || b_file == 0) begin
            $display("Error: Cannot open channel PGM files");
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(r_file, "%s", magic);
            if (scan_result == 0) begin
                char = $fgetc(r_file);
                if (char == "#") while ($fgetc(r_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(r_file, "%d %d", width, height);
            if (scan_result != 2) begin
                char = $fgetc(r_file);
                if (char == "#") while ($fgetc(r_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(r_file, "%d", max_val);
            if (scan_result != 1) begin
                char = $fgetc(r_file);
                if (char == "#") while ($fgetc(r_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        $display("Merged image parameters: width=%d, height=%d, max_value=%d", width, height, max_val);

        for (i = 0; i < 3; i = i + 1) begin
            exit_loop = 1'b0;
            while (!exit_loop) begin
                scan_result = $fscanf(g_file, "%s", magic);
                if (scan_result == 0) begin
                    char = $fgetc(g_file);
                    if (char == "#") while ($fgetc(g_file) != "\n") begin end
                end else exit_loop = 1'b1;
            end
        end
        
        for (i = 0; i < 3; i = i + 1) begin
            exit_loop = 1'b0;
            while (!exit_loop) begin
                scan_result = $fscanf(b_file, "%s", magic);
                if (scan_result == 0) begin
                    char = $fgetc(b_file);
                    if (char == "#") while ($fgetc(b_file) != "\n") begin end
                end else exit_loop = 1'b1;
            end
        end

        ppm_file = $fopen("output/out_merged_output.ppm", "w");
        if (ppm_file == 0) begin
            $display("Error: Cannot create output PPM file");
            $finish;
        end

        $fdisplay(ppm_file, "P3");
        $fdisplay(ppm_file, "# Created by RGB merger");
        $fdisplay(ppm_file, "%d %d", width, height);
        $fdisplay(ppm_file, "%d", max_val);

        pixel_count = 0;
        file_end = 1'b0;

        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                scan_result = $fscanf(r_file, "%d", r_val);
                scan_result = $fscanf(g_file, "%d", g_val);
                scan_result = $fscanf(b_file, "%d", b_val);

                if ($feof(r_file) || $feof(g_file) || $feof(b_file)) begin
                    $display("Warning: Reached end of file at pixel %d", pixel_count);
                    file_end = 1'b1;
                    i = height;
                    j = width;
                end

                @(posedge clk);
                data_valid <= 1'b1;
                r <= r_val[7:0];
                g <= g_val[7:0];
                b <= b_val[7:0];

                @(posedge clk);
                data_valid <= 1'b0;

                fork : wait_for_valid
                    begin
                        wait(data_out_valid);
                        disable wait_for_valid;
                    end
                    begin
                        #1000;
                        $display("Timeout waiting for data_out_valid at pixel %d", pixel_count);
                        disable wait_for_valid;
                    end
                join

                @(posedge clk);

                $fwrite(ppm_file, "%d %d %d ", r_out, g_out, b_out);
                
                pixel_count = pixel_count + 1;
            end
            
            if (file_end) begin
                i = height;
            end
        end

        $fclose(r_file);
        $fclose(g_file);
        $fclose(b_file);
        $fclose(ppm_file);
        $display("Channel merging completed, processed %d pixels", pixel_count);
        $display("Output file: merged_output.ppm");
    end
endtask

initial begin
    $dumpfile("rgb_merger.vcd");
    $dumpvars(0, tb_rgb_merger);
end

endmodule