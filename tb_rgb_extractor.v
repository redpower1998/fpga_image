`timescale 1ns/1ps

module tb_rgb_extractor;

reg         clk;
reg         rst_n;
reg         data_valid;
reg [7:0]   r, g, b;
reg [1:0]   channel_select;
wire        data_out_valid;
wire [7:0]  channel_out;

rgb_extractor u_rgb_extractor (
    .clk           (clk),
    .rst_n         (rst_n),
    .r_in          (r),
    .g_in          (g),
    .b_in          (b),
    .data_valid    (data_valid),
    .channel_select(channel_select),
    .channel_out   (channel_out),
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
    channel_select = 2'b00;
    #100;
    rst_n = 1'b1;
    #100;

    $display("=== Starting module functionality verification ===");
    test_pixel(255, 128, 64, 2'b00);
    test_pixel(255, 128, 64, 2'b01);
    test_pixel(255, 128, 64, 2'b10);
    test_pixel(255, 128, 64, 2'b11);
    $display("=== Module functionality verification completed ===");
    #100;

    $display("=== Starting R channel extraction ===");
    channel_select = 2'b00;
    read_ppm_write_pgm("data/rgb1.ppm", 
                       "output/output_r.pgm");
    #100;

    $display("=== Starting G channel extraction ===");
    channel_select = 2'b01;
    read_ppm_write_pgm("data/rgb1.ppm", 
                       "output/output_g.pgm");
    #100;

    $display("=== Starting B channel extraction ===");
    channel_select = 2'b10;
    read_ppm_write_pgm("data/rgb1.ppm", 
                       "output/output_b.pgm");
    #100;

    $display("=== All channel extractions completed ===");
    #1000;
    $finish;
end

task test_pixel;
    input [7:0] r_in, g_in, b_in;
    input [1:0] ch_select;
    reg [7:0] expected;
    begin
        @(posedge clk);
        data_valid <= 1'b1;
        r <= r_in;
        g <= g_in;
        b <= b_in;
        channel_select <= ch_select;

        @(posedge clk);
        data_valid <= 1'b0;

        wait(data_out_valid);
        @(posedge clk);

        case (ch_select)
            2'b00: expected = r_in;
            2'b01: expected = g_in;
            2'b10: expected = b_in;
            default: expected = 8'b0;
        endcase

        $display("Test RGB=(%d,%d,%d), Channel=%b  out=%d, expected=%d, valid=%b", 
                 r_in, g_in, b_in, ch_select, channel_out, expected, data_out_valid);
        
        if (channel_out !== expected) begin
            $display("ERROR: Output mismatch! Expected: %d, Got: %d", expected, channel_out);
        end
    end
endtask

task read_ppm_write_pgm;
    input [80*8-1:0] ppm_filename;
    input [80*8-1:0] pgm_filename;
    integer ppm_file, pgm_file;
    integer width, height, max_val;
    integer i, j, r_val, g_val, b_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop;
    integer pixel_count;

    begin
        ppm_file = $fopen(ppm_filename, "r");
        if (ppm_file == 0) begin
            $display("Error: Cannot open input file %s", ppm_filename);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file, "%s", magic);
            if (scan_result == 0) begin
                char = $fgetc(ppm_file);
                if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        if (magic != "P3") begin
            $display("Error: Expected P3 format, got %s", magic);
            $fclose(ppm_file);
            $finish;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file, "%d %d", width, height);
            if (scan_result != 2) begin
                char = $fgetc(ppm_file);
                if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end

        exit_loop = 1'b0;
        while (!exit_loop) begin
            scan_result = $fscanf(ppm_file, "%d", max_val);
            if (scan_result != 1) begin
                char = $fgetc(ppm_file);
                if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
            end else exit_loop = 1'b1;
        end
        $display("Image parameters: width=%d, height=%d, max_value=%d", width, height, max_val);

        pgm_file = $fopen(pgm_filename, "w");
        if (pgm_file == 0) begin
            $display("Error: Cannot create output file %s", pgm_filename);
            $fclose(ppm_file);
            $finish;
        end

        $fdisplay(pgm_file, "P2");
        $fdisplay(pgm_file, "%d %d", width, height);
        $fdisplay(pgm_file, "%d", max_val);

        pixel_count = 0;

        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                exit_loop = 1'b0;
                while (!exit_loop) begin
                    scan_result = $fscanf(ppm_file, "%d %d %d", r_val, g_val, b_val);
                    if (scan_result != 3) begin
                        char = $fgetc(ppm_file);
                        if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
                    end else exit_loop = 1'b1;
                end

                @(posedge clk);
                data_valid <= 1'b1;
                r <= r_val[7:0];
                g <= g_val[7:0];
                b <= b_val[7:0];

                @(posedge clk);
                data_valid <= 1'b0;

                wait(data_out_valid);
                @(posedge clk);

                $fwrite(pgm_file, "%d ", channel_out);
                pixel_count = pixel_count + 1;

                if (pixel_count % 100 == 0) begin
                    $display("Processed %d pixels...", pixel_count);
                end
            end
            $fwrite(pgm_file, "\n");
        end

        $fclose(ppm_file);
        $fclose(pgm_file);
        $display("File conversion completed: %s -> %s", ppm_filename, pgm_filename);
        $display("Total pixels processed: %d", pixel_count);
    end
endtask

initial begin
    $dumpfile("rgb_extractor.vcd");
    $dumpvars(0, tb_rgb_extractor);
end

endmodule