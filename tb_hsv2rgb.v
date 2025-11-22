`timescale 1ns/1ps
module tb_hsv2rgb;

reg         clk_Image_Process;
reg         Rst;
reg [8:0]   HSV_Data_H;
reg [7:0]   HSV_Data_S;
reg [7:0]   HSV_Data_V;
wire [7:0]  RGB_Data_R;
wire [7:0]  RGB_Data_G;
wire [7:0]  RGB_Data_B;
wire [2:0]  Delay_Num;

hsv2rgb u_hsv2rgb (
    .clk_Image_Process (clk_Image_Process),
    .Rst               (Rst),
    .HSV_Data_H        (HSV_Data_H),
    .HSV_Data_S        (HSV_Data_S),
    .HSV_Data_V        (HSV_Data_V),
    .RGB_Data_R        (RGB_Data_R),
    .RGB_Data_G        (RGB_Data_G),
    .RGB_Data_B        (RGB_Data_B),
    .Delay_Num         (Delay_Num)
);

initial begin
    clk_Image_Process = 1'b0;
    forever #10 clk_Image_Process = ~clk_Image_Process;
end

initial begin
    Rst = 1'b0;
    HSV_Data_H = 9'd0;
    HSV_Data_S = 8'd0;
    HSV_Data_V = 8'd0;
    #100;
    Rst = 1'b1;
    #100;

    $display("=== Starting HSV2RGB module functional verification ===");
    test_pixel(0, 255, 255);
    test_pixel(60, 255, 255);
    test_pixel(120, 255, 255);
    test_pixel(180, 255, 255);
    test_pixel(240, 255, 255);
    test_pixel(300, 255, 255);
    test_pixel(0, 0, 255);
    test_pixel(0, 0, 0);
    $display("=== HSV2RGB module functional verification completed ===");
    #100;

    read_ppm_write_ppm("output/out_rgb2hsv.ppm", 
                       "output/out_hsv2rgb.ppm");
    $display("HSV2RGB Conversion completed");
    #1000;
    $finish;
end

task test_pixel;
    input [8:0] h_in;
    input [7:0] s_in, v_in;
    begin
        @(posedge clk_Image_Process);
        HSV_Data_H <= h_in;
        HSV_Data_S <= s_in;
        HSV_Data_V <= v_in;

        repeat(3) @(posedge clk_Image_Process);
        
        $display("Test HSV=(%d,%d,%d) -> RGB=(%d,%d,%d), delay_num=%d", 
                 h_in, s_in, v_in, RGB_Data_R, RGB_Data_G, RGB_Data_B, Delay_Num);
    end
endtask

task read_ppm_write_ppm;
    input [80*8-1:0] input_filename;
    input [80*8-1:0] output_filename;
    integer input_file, output_file;
    integer width, height, max_val;
    integer i, j, h_val, s_val, v_val, scan_result;
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
                    scan_result = $fscanf(input_file, "%d %d %d", h_val, s_val, v_val);
                    if (scan_result != 3) begin
                        char = $fgetc(input_file);
                        if (char == "#") while ($fgetc(input_file) != "\n") begin end
                    end else exit_loop = 1'b1;
                end

                @(posedge clk_Image_Process);
                HSV_Data_H <= h_val[8:0];
                HSV_Data_S <= s_val[7:0];
                HSV_Data_V <= v_val[7:0];

                repeat(3) @(posedge clk_Image_Process);
                
                $fwrite(output_file, "%d %d %d ", RGB_Data_R, RGB_Data_G, RGB_Data_B);
                
                if ((i < 2 && j < 2) || (i % 100 == 0 && j == 0)) begin
                    $display("Pixel(%d,%d): HSV=(%d,%d,%d) -> RGB=(%d,%d,%d)", 
                             i, j, h_val, s_val, v_val, RGB_Data_R, RGB_Data_G, RGB_Data_B);
                end
            end
            $fwrite(output_file, "\n");
        end

        $fclose(input_file);
        $fclose(output_file);
    end
endtask

initial begin
    $dumpfile("hsv2rgb.vcd");
    $dumpvars(0, tb_hsv2rgb);
end

endmodule