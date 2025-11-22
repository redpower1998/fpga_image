`timescale 1ns/1ps
module tb_rgb2gray_high_perf;

reg         clk;
reg         rst_n;
reg         data_valid;
reg [7:0]   r, g, b;
wire        gray_valid;
wire [7:0]  gray;

rgb2gray_high_perf u_rgb2gray_high_perf (
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
    forever #5 clk = ~clk;
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

    $display("=== Start High-Performance Module Function Verification ===");
    test_pixel(255, 0, 0, 76);
    test_pixel(0, 255, 0, 150);
    test_pixel(0, 0, 255, 29);
    test_pixel(255, 255, 255, 255);
    test_pixel(0, 0, 0, 0);
    $display("=== Function Verification Completed ===");
    #100;

    read_ppm_write_pgm(
        "data/rgb1.ppm",
        "output/output_high_perf.pgm"
    );
    $display("Image Conversion Completed");
    
    repeat(3) @(posedge clk);
    $finish;
end

task test_pixel;
    input [7:0] r_in, g_in, b_in;
    input [7:0] exp_gray;
    integer     wait_cnt;
begin
    @(posedge clk);
    data_valid <= 1'b1;
    r <= r_in;
    g <= g_in;
    b <= b_in;

    @(posedge clk);
    data_valid <= 1'b0;

    wait_cnt = 0;
    while (wait_cnt < 3) begin
        @(posedge clk);
        wait_cnt = wait_cnt + 1;
    end

    $display("Test RGB=(%3d,%3d,%3d) -> Actual=%3d, Expected=%3d, Valid=%b", 
             r_in, g_in, b_in, gray, exp_gray, gray_valid);
    
    if (!gray_valid) begin
        $display("ERROR: gray_valid inactive (pipeline delay mismatch)");
    end else if ((gray > exp_gray + 1) || (gray < exp_gray - 1)) begin
        $display("ERROR: Gray deviation (Actual=%3d, Expected=%3d)", gray, exp_gray);
    end
end
endtask

task read_ppm_write_pgm;
    input [80*8-1:0] ppm_filename;
    input [80*8-1:0] pgm_filename;
    integer ppm_file, pgm_file;
    integer width, height, max_val;
    integer i, j, r_val, g_val, b_val, scan_result, pixel_cnt;
    integer wait_cnt;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop, file_end_flag;
begin
    ppm_file = $fopen(ppm_filename, "r");
    if (ppm_file == 0) begin
        $display("ERROR: Cannot open input file %s", ppm_filename);
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
        $display("ERROR: Only P3 PPM supported (current: %s)", magic);
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
    $display("Image Params: Width=%d, Height=%d", width, height);
    if (height > 464) height = 464;

    exit_loop = 1'b0;
    while (!exit_loop) begin
        scan_result = $fscanf(ppm_file, "%d", max_val);
        if (scan_result != 1) begin
            char = $fgetc(ppm_file);
            if (char == "#") while ($fgetc(ppm_file) != "\n") begin end
        end else exit_loop = 1'b1;
    end

    pgm_file = $fopen(pgm_filename, "w");
    if (pgm_file == 0) begin
        $display("ERROR: Cannot create output file %s", pgm_filename);
        $fclose(ppm_file);
        $finish;
    end
    $fdisplay(pgm_file, "P2");
    $fdisplay(pgm_file, "%d %d", width, height);
    $fdisplay(pgm_file, "%d", max_val);

    file_end_flag = 1'b0;
    pixel_cnt = 0;
    for (i = 0; i < height && !file_end_flag; i = i + 1) begin
        for (j = 0; j < width && !file_end_flag; j = j + 1) begin
            scan_result = $fscanf(ppm_file, "%d %d %d", r_val, g_val, b_val);
            if (scan_result != 3) begin
                $display("WARNING: End of file at Pixel(%d,%d)", i, j);
                file_end_flag = 1'b1;
                r_val = 0; g_val = 0; b_val = 0;
            end else begin
                $display("Pixel(%d,%d): R=%3d, G=%3d, B=%3d", i, j, r_val, g_val, b_val);
            end

            @(posedge clk);
            data_valid <= (file_end_flag) ? 1'b0 : 1'b1;
            r <= r_val[7:0];
            g <= g_val[7:0];
            b <= b_val[7:0];

            @(posedge clk);
            data_valid <= 1'b0;

            wait_cnt = 0;
            while (wait_cnt < 3) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
            end

            if (gray_valid && !file_end_flag) begin
                $fwrite(pgm_file, "%d ", gray);
                $display("Pixel(%d,%d): Output Gray=%3d", i, j, gray);
            end else if (!file_end_flag) begin
                $fwrite(pgm_file, "%d ", gray);
                $display("ERROR: gray_valid inactive at Pixel(%d,%d)", i, j);
            end
        end
        $fwrite(pgm_file, "\n");
    end

    $fclose(ppm_file);
    $fclose(pgm_file);
end
endtask

initial begin
    $dumpfile("tb_rgb2gray_high_perf.vcd");
    $dumpvars(0, tb_rgb2gray_high_perf);
end

endmodule