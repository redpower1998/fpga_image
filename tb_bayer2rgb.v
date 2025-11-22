`timescale 1ns/1ps

module tb_bayer2rgb;

parameter CLK_PERIOD = 10;
parameter IMG_WIDTH = 320;
parameter IMG_HEIGHT = 466;
parameter IMG_SIZE = IMG_WIDTH * IMG_HEIGHT;

reg clk;
reg rst_n;

reg data_valid;
reg [7:0] bayer_data;
reg [1:0] pattern_select;

wire data_out_valid;
wire [7:0] r_out;
wire [7:0] g_out;
wire [7:0] b_out;

integer bayer_file;
integer ppm_file;

integer input_pixel_count;
integer output_pixel_count;
integer timeout_counter;
parameter TIMEOUT_LIMIT = 1000000;

bayer2rgb dut (
    .clk(clk),
    .rst_n(rst_n),
    .data_valid(data_valid),
    .bayer_data(bayer_data),
    .pattern_select(pattern_select),
    .data_out_valid(data_out_valid),
    .r_out(r_out),
    .g_out(g_out),
    .b_out(b_out)
);

always #(CLK_PERIOD/2) clk = ~clk;

always @(posedge clk) begin
    if (data_out_valid && ppm_file) begin
        write_ppm_pixel(r_out, g_out, b_out);
        output_pixel_count = output_pixel_count + 1;
        
        if (output_pixel_count % 10000 == 0) begin
            $display("Output progress: %0d/%0d pixels", output_pixel_count, IMG_SIZE);
        end
    end
end

initial begin
    test_bayer_pattern("data/color2_bayer_rggb.raw", "output/color2_320x466_bayer_rggb_new.ppm", 2'b00, "RGGB");
    
    test_bayer_pattern("data/color2_bayer_bggr.raw", "output/color2_320x466_bayer_bggr_new.ppm", 2'b01, "BGGR");
    
    test_bayer_pattern("data/color2_bayer_grbg.raw", "output/color2_320x466_bayer_grbg_new.ppm", 2'b10, "GRBG");
    
    test_bayer_pattern("data/color2_bayer_gbrg.raw", "output/color2_320x466_bayer_gbrg_new.ppm", 2'b11, "GBRG");
    
    $display("All Bayer pattern tests completed!");
    $finish;
end

task test_bayer_pattern;
    input [2550:0] input_file;
    input [2550:0] output_file;
    input [1:0] pattern;
    input [2550:0] pattern_name;
    integer i;
    reg [7:0] temp_byte;
    reg error_flag;
    
    begin
        $display("Starting Bayer pattern test: %s", pattern_name);
        
        clk = 0;
        rst_n = 0;
        data_valid = 0;
        bayer_data = 8'd0;
        pattern_select = pattern;
        input_pixel_count = 0;
        output_pixel_count = 0;
        timeout_counter = 0;
        error_flag = 0;
        
        bayer_file = $fopen(input_file, "rb");
        if (bayer_file == 0) begin
            $display("Error: Cannot open Bayer file %s", input_file);
            error_flag = 1;
            disable test_bayer_pattern;
        end
        
        ppm_file = $fopen(output_file, "wb");
        if (ppm_file == 0) begin
            $display("Error: Cannot create PPM file %s", output_file);
            $fclose(bayer_file);
            error_flag = 1;
            disable test_bayer_pattern;
        end
        
        $fwrite(ppm_file, "P6\n%d %d\n255\n", IMG_WIDTH, IMG_HEIGHT);
        
        #(CLK_PERIOD*2);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        $display("Starting Bayer to RGB conversion test...");
        
        for (i = 0; i < IMG_SIZE && !error_flag; i = i + 1) begin
            if ($fread(temp_byte, bayer_file) != 1) begin
                $display("Error: Bayer data read failed at position %d", i);
                error_flag = 1;
                disable test_bayer_pattern;
            end
            
            bayer_data = temp_byte;
            data_valid = 1;
            
            #(CLK_PERIOD);
            
            input_pixel_count = input_pixel_count + 1;
            
            if (input_pixel_count % 10000 == 0) begin
                $display("Input progress: %0d/%0d pixels", input_pixel_count, IMG_SIZE);
            end
        end
        
        data_valid = 0;
        
        wait_for_completion();
        
        #(CLK_PERIOD * 100);
        
        $fclose(bayer_file);
        $fclose(ppm_file);
        
        if (!error_flag) begin
            $display("Bayer to RGB test completed! Output file: %s", output_file);
            $display("Input pixels: %0d, Output pixels: %0d", input_pixel_count, output_pixel_count);
        end else begin
            $display("Bayer to RGB test failed!");
        end
    end
endtask

task write_ppm_pixel;
    input [7:0] r, g, b;
    begin
        $fwrite(ppm_file, "%c%c%c", r, g, b);
    end
endtask

task wait_for_completion;
    begin
        timeout_counter = 0;
        
        #(CLK_PERIOD * (2 * IMG_WIDTH + 100));
        
        while (output_pixel_count < IMG_SIZE && timeout_counter < TIMEOUT_LIMIT) begin
            #(CLK_PERIOD);
            timeout_counter = timeout_counter + 1;
            
            if (timeout_counter % 10000 == 0) begin
                $display("Waiting for processing completion... Output pixels: %0d/%0d, Wait count: %0d", 
                         output_pixel_count, IMG_SIZE, timeout_counter);
            end
        end
        
        if (timeout_counter >= TIMEOUT_LIMIT) begin
            $display("Error: Processing timeout, Output pixels: %0d/%0d", output_pixel_count, IMG_SIZE);
        end else begin
            $display("Processing completed, Output pixels: %0d/%0d", output_pixel_count, IMG_SIZE);
        end
    end
endtask

always @(posedge clk) begin
    if (timeout_counter >= TIMEOUT_LIMIT) begin
        $display("Error: Test timeout");
        if (bayer_file) $fclose(bayer_file);
        if (ppm_file) $fclose(ppm_file);
        $finish;
    end
end

endmodule