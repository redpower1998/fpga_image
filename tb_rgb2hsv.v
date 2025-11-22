`timescale 1ns/1ps
module tb_rgb2hsv;

reg         clk;
reg         rst_n;
reg [7:0]   r, g, b;
wire [8:0]  h;
wire [7:0]  s, v;
wire [2:0]  delay_num;

rgb2hsv u_rgb2hsv (
    .clk_Image_Process (clk),
    .Rst               (rst_n),
    .RGB_Data_R        (r),
    .RGB_Data_G        (g),
    .RGB_Data_B        (b),
    .HSV_H             (h),
    .HSV_S             (s),
    .HSV_V             (v),
    .Delay_Num         (delay_num)
);

initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    r = 8'd0;
    g = 8'd0;
    b = 8'd0;
    #100;
    rst_n = 1'b1;
    #100;

    $display("=== Starting RGB2HSV module functional verification ===");
    test_pixel(255, 0, 0);
    test_pixel(0, 255, 0);
    test_pixel(0, 0, 255);
    test_pixel(255, 255, 255);
    test_pixel(0, 0, 0);
    test_pixel(255, 255, 0);
    $display("=== RGB2HSV module functional verification completed ===");
    #100;

    read_ppm_write_ppm("data/rgb1.ppm", 
                       "output/out_rgb2hsv.ppm");
    $display("RGB2HSV Conversion completed");
    #1000;
    $finish;
end

task test_pixel;
    input [7:0] r_in, g_in, b_in;
    begin
        @(posedge clk);
        r <= r_in;
        g <= g_in;
        b <= b_in;
        
        repeat(4) @(posedge clk);
        
        $display("Test RGB=(%d,%d,%d) -> HSV=(%d,%d,%d), delay_num=%d", 
                 r_in, g_in, b_in, h, s, v, delay_num);
    end
endtask

task read_ppm_write_ppm;
    input [80*8-1:0] input_filename;
    input [80*8-1:0] output_filename;
    integer input_file, output_file;
    integer width, height, max_val;
    integer i, j, r_val, g_val, b_val, scan_result;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop;

    begin
        input_file = $fopen(input_filename, "r");
        if (input_file == 0) begin
            $display("Error: Cannot open input file %s", input_filename);
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

        output_file = $fopen(output_filename, "w");
        if (output_file == 0) begin
            $display("Error: Cannot create output file %s", output_filename);
            $fclose(input_file);
            $finish;
        end

        $fdisplay(output_file, "P3");
        $fdisplay(output_file, "%d %d", width, height);
        $fdisplay(output_file, "%d", max_val);

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

                @(posedge clk);
                r <= r_val[7:0];
                g <= g_val[7:0];
                b <= b_val[7:0];

                repeat(4) @(posedge clk);
                
                $fwrite(output_file, "%d %d %d ", h, s, v);
                
                if ((i < 2 && j < 2) || (i % 100 == 0 && j == 0)) begin
                    $display("Pixel(%d,%d): RGB=(%d,%d,%d) -> HSV=(%d,%d,%d)", 
                             i, j, r_val, g_val, b_val, h, s, v);
                end
            end
            $fwrite(output_file, "\n");
        end

        $fclose(input_file);
        $fclose(output_file);
    end
endtask

initial begin
    $dumpfile("rgb2hsv.vcd");
    $dumpvars(0, tb_rgb2hsv);
end

endmodule