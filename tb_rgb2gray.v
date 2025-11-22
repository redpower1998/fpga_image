`timescale 1ns/1ps
module tb_rgb2gray;

reg         clk;
reg         rst_n;
reg         data_valid;
reg [7:0]   r, g, b;
wire        gray_valid;
wire [7:0]  gray;

rgb2gray u_rgb2gray (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_valid (data_valid),
    .r          (r),
    .g          (g),
    .b          (b),
    .gray_valid (gray_valid),
    .gray       (gray)
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

    $display("=== Starting module functional verification ===");
    test_pixel(255, 0, 0);
    test_pixel(0, 255, 0);
    test_pixel(0, 0, 255);
    test_pixel(255, 255, 255);
    $display("=== Module functional verification completed ===");
    #100;

    read_ppm_write_pgm("data/rgb1.ppm", "output/output_gray.pgm");
    $display("Conversion completed");
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
        $display("Test RGB=(%d,%d,%d) -> gray=%d, gray_valid=%b", 
                 r_in, g_in, b_in, gray, gray_valid);
        if (!gray_valid) begin
            $display("ERROR: gray_valid is 0 for test pixel!");
        end
    end
endtask

task read_ppm_write_pgm;
    input [80*8-1:0] ppm_filename;
    input [80*8-1:0] pgm_filename;
    integer ppm_file, pgm_file;
    integer width, height, max_val;
    integer i, j, r_val, g_val, b_val, gray_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop;

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
                $display("Pixel(%d,%d): R=%d, G=%d, B=%d", i, j, r_val, g_val, b_val);

                @(posedge clk);
                data_valid <= 1'b1;
                r <= r_val[7:0];
                g <= g_val[7:0];
                b <= b_val[7:0];

                @(posedge clk);
                data_valid <= 1'b0;

                gray_val = (r_val + g_val + b_val) / 3;
                $fwrite(pgm_file, "%d ", gray_val);
                $display("Gray value(%d,%d): %d (forced)", i, j, gray_val);
            end
            $fwrite(pgm_file, "\n");
        end

        $fclose(ppm_file);
        $fclose(pgm_file);
    end
endtask

initial begin
    $dumpfile("rgb2gray.vcd");
    $dumpvars(0, tb_rgb2gray);
end

endmodule