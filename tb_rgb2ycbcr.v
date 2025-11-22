`timescale 1ns/1ps

module tb_rgb2ycbcr;

    parameter CLK_PERIOD = 10;
    parameter IMAGE_WIDTH = 320;
    parameter IMAGE_HEIGHT = 466;
    
    reg clk;
    reg rst_n;
    
    reg data_valid;
    reg [7:0] r_in;
    reg [7:0] g_in;
    reg [7:0] b_in;
    
    wire data_out_valid;
    wire [7:0] y_out;
    wire [7:0] cb_out;
    wire [7:0] cr_out;
    
    reg ycbcr_data_valid;
    reg [7:0] y_in_recon;
    reg [7:0] cb_in_recon;
    reg [7:0] cr_in_recon;
    wire rgb_recon_data_out_valid;
    wire [7:0] r_out_recon;
    wire [7:0] g_out_recon;
    wire [7:0] b_out_recon;
    
    integer error_count;
    integer test_count;
    integer pixel_count;
    integer output_count;
integer timeout_count;
    integer recon_count;
    
    integer f_rgb_in, f_y_out, f_cb_out, f_cr_out, f_rgb_recon;
    integer width, height, max_val;
    
    integer width_cb, height_cb, max_val_cb;
    integer width_cr, height_cr, max_val_cr;
    
    reg [7:0] source_r [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    reg [7:0] source_g [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    reg [7:0] source_b [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    
    reg [7:0] recon_r [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    reg [7:0] recon_g [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    reg [7:0] recon_b [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    
    reg [7:0] y_data [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    reg [7:0] cb_data [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    reg [7:0] cr_data [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    
    integer i, j;
    integer pixel_val;
    integer scan_result;
    reg [1023:0] line_buffer;
    integer tmp_char;
    integer unget_result;

    rgb2ycbcr dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(data_valid),
        .r_in(r_in),
        .g_in(g_in),
        .b_in(b_in),
        .data_out_valid(data_out_valid),
        .y_out(y_out),
        .cb_out(cb_out),
        .cr_out(cr_out)
    );
    
    ycbcr2rgb dut_recon (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(ycbcr_data_valid),
        .y_in(y_in_recon),
        .cb_in(cb_in_recon),
        .cr_in(cr_in_recon),
        .data_out_valid(rgb_recon_data_out_valid),
        .r_out(r_out_recon),
        .g_out(g_out_recon),
        .b_out(b_out_recon)
    );
    
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        data_valid = 1'b0;
        r_in = 8'd0;
        g_in = 8'd0;
        b_in = 8'd0;
ycbcr_data_valid = 1'b0;
        y_in_recon = 8'd0;
        cb_in_recon = 8'd0;
        cr_in_recon = 8'd0;
        error_count = 0;
        test_count = 0;
        pixel_count = 0;
        recon_count = 0;
        
        #100;
        rst_n = 1'b1;
        #100;
        
        $display("=== Starting RGB to YCbCr module test ===");
        
        test_rgb2ycbcr_image();
        
        test_ycbcr2rgb_recon();
        
        #1000;
        $display("=== All tests completed ===");
        $display("Total test pixels: %d", test_count);
$display("Reconstructed pixels: %d", recon_count);
$display("Error count: %d", error_count);
        $finish;
    end
    
    task test_rgb2ycbcr_image;
        begin
            $display("Starting RGB image file processing...");
            
            f_rgb_in = $fopen("data/rgb1.ppm", "r");
            if (f_rgb_in == 0) begin
                $display("ERROR: Cannot open input file rgb1.ppm");
                error_count = error_count + 1;
            end else begin
                scan_result = $fscanf(f_rgb_in, "%s", line_buffer);
                if (line_buffer != "P3") begin
                    $display("ERROR: Not a valid P3 format PPM file");
error_count = error_count + 1;
                    $fclose(f_rgb_in);
                end else begin
scan_result = 0;
                    while (scan_result != 2) begin
                        scan_result = $fscanf(f_rgb_in, "%d %d", width, height);
                        if (scan_result != 2) begin
                            tmp_char = $fgetc(f_rgb_in);
                            if (tmp_char == "#") begin
                                tmp_char = $fgetc(f_rgb_in);
                                while (tmp_char != 10 && tmp_char != -1) begin
                                    tmp_char = $fgetc(f_rgb_in);
                                end
                            end
                        end
                    end
                    
if (error_count == 0) begin
                        if (width != IMAGE_WIDTH || height != IMAGE_HEIGHT) begin
                            $display("WARNING: Image dimensions mismatch: %d x %d (expected: %d x %d)", 
                                    width, height, IMAGE_WIDTH, IMAGE_HEIGHT);
                            $display("INFO: Using actual image dimensions %d x %d for processing", width, height);
                        end
                        
                        scan_result = 0;
                        while (scan_result != 1) begin
                            scan_result = $fscanf(f_rgb_in, "%d", max_val);
                            if (scan_result != 1) begin
                                tmp_char = $fgetc(f_rgb_in);
                                if (tmp_char == "#") begin
                                    tmp_char = $fgetc(f_rgb_in);
                                    while (tmp_char != 10 && tmp_char != -1) begin
                                        tmp_char = $fgetc(f_rgb_in);
                                    end
                                end
                            end
                        end
                        
                        if (max_val != 255) begin
                            $display("WARNING: Maximum value is not 255: %d", max_val);
                        end
                        
                        $display("Reading PPM file: width=%d, height=%d, max_val=%d", width, height, max_val);
                        
                        if (width * height > IMAGE_WIDTH * IMAGE_HEIGHT) begin
                            $display("ERROR: Image size exceeds expectation, cannot process");
                            error_count = error_count + 1;
                            $fclose(f_rgb_in);
                        end else begin
                            pixel_count = 0;
                            for (j = 0; j < height; j = j + 1) begin
                                for (i = 0; i < width; i = i + 1) begin
                                    if ($feof(f_rgb_in)) begin
                                        $display("ERROR: File ended prematurely");
                                        error_count = error_count + 1;
                                        j = height;
                                        i = width;
                                    end else begin
                                        scan_result = $fscanf(f_rgb_in, "%d", pixel_val);
                                        if (scan_result != 1) begin
                                            $display("ERROR: Failed to read R component");
                                            error_count = error_count + 1;
                                            j = height;
                                            i = width;
                                        end else begin
                                            source_r[j * width + i] = pixel_val;
                                            
                                            scan_result = $fscanf(f_rgb_in, "%d", pixel_val);
                                            if (scan_result != 1) begin
                                                $display("ERROR: Failed to read G component");
                                                error_count = error_count + 1;
                                                j = height;
                                                i = width;
                                            end else begin
                                                source_g[j * width + i] = pixel_val;
                                                
                                                scan_result = $fscanf(f_rgb_in, "%d", pixel_val);
                                                if (scan_result != 1) begin
                                                    $display("ERROR: Failed to read B component");
                                                    error_count = error_count + 1;
                                                    j = height;
                                                    i = width;
                                                end else begin
                                                    source_b[j * width + i] = pixel_val;
                                                    pixel_count = pixel_count + 1;
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            
                            if (error_count == 0) begin
                                $display("Successfully read %d RGB pixels", pixel_count);
                                $fclose(f_rgb_in);
                                
                                f_y_out = $fopen("output/out_y_output.pgm", "w");
                                f_cb_out = $fopen("output/out_cb_output.pgm", "w");
                                f_cr_out = $fopen("output/out_cr_output.pgm", "w");
                                
                                if (f_y_out == 0 || f_cb_out == 0 || f_cr_out == 0) begin
                                    $display("ERROR: Cannot create output files");
                                    error_count = error_count + 1;
                                end else begin
                                    $fdisplay(f_y_out, "P2");
                                    $fdisplay(f_y_out, "%d %d", width, height);
                                    $fdisplay(f_y_out, "%d", 255);
                                    
                                    $fdisplay(f_cb_out, "P2");
                                    $fdisplay(f_cb_out, "%d %d", width, height);
                                    $fdisplay(f_cb_out, "%d", 255);
                                    
                                    $fdisplay(f_cr_out, "P2");
                                    $fdisplay(f_cr_out, "%d %d", width, height);
                                    $fdisplay(f_cr_out, "%d", 255);
                                    
                                    $display("Starting RGB to YCbCr processing...");
                                    
                                    test_count = 0;
                                    output_count = 0;
                                    
                                    for (j = 0; j < height; j = j + 1) begin
                                        for (i = 0; i < width; i = i + 1) begin
                                            @(posedge clk);
                                            data_valid = 1'b1;
                                            r_in = source_r[j * width + i];
                                            g_in = source_g[j * width + i];
                                            b_in = source_b[j * width + i];
                                            test_count = test_count + 1;
repeat(3) @(posedge clk);
                                            
                                            if (data_out_valid) begin
                                                output_count = output_count + 1;
                                                
                                                if (i % 20 == 0 && i > 0) begin
                                                    $fdisplay(f_y_out, "");
                                                end
                                                $fwrite(f_y_out, "%d ", y_out);
                                                
                                                if (i % 20 == 0 && i > 0) begin
                                                    $fdisplay(f_cb_out, "");
                                                end
                                                $fwrite(f_cb_out, "%d ", cb_out);
                                                
                                                if (i % 20 == 0 && i > 0) begin
                                                    $fdisplay(f_cr_out, "");
                                                end
                                                $fwrite(f_cr_out, "%d ", cr_out);
                                            end
                                            
                                            @(posedge clk);
                                            data_valid = 1'b0;
                                            r_in = 8'd0;
                                            g_in = 8'd0;
                                            b_in = 8'd0;
                                        end
                                        $fdisplay(f_y_out, "");
                                        $fdisplay(f_cb_out, "");
                                        $fdisplay(f_cr_out, "");
end
                                    
                                    timeout_count = 0;
while (output_count < test_count && timeout_count < 1000) begin
                                        @(posedge clk);
                                        timeout_count = timeout_count + 1;
                                        
                                        if (data_out_valid) begin
                                            output_count = output_count + 1;
                                            
                                            $fwrite(f_y_out, "%d ", y_out);
                                            
                                            $fwrite(f_cb_out, "%d ", cb_out);
                                            
                                            $fwrite(f_cr_out, "%d ", cr_out);
                                        end
                                    end
                                    
                                    $fdisplay(f_y_out, "");
                                    $fdisplay(f_cb_out, "");
                                    $fdisplay(f_cr_out, "");
                                    
                                    $display("RGB to YCbCr processing completed, sent %d pixels, collected %d outputs", test_count, output_count);
                                    $fclose(f_y_out);
                                    $fclose(f_cb_out);
                                    $fclose(f_cr_out);
                                    $display("YCbCr components saved as y_output.pgm, cb_output.pgm, cr_output.pgm");
                                end
                            end
                        end
                    end
                end
            end
        end
    endtask
    
    task test_ycbcr2rgb_recon;
        begin
             $display("=== Starting YCbCr to RGB reconstruction test ===");
            $display("Reading YCbCr component files and reconstructing RGB image...");
            
            f_y_out = $fopen("output/out_y_output.pgm", "r");
            f_cb_out = $fopen("output/out_cb_output.pgm", "r");
            f_cr_out = $fopen("output/out_cr_output.pgm", "r");
            
            if (f_y_out == 0 || f_cb_out == 0 || f_cr_out == 0) begin
                $display("ERROR: Cannot open YCbCr component files");
                error_count = error_count + 1;
            end else begin
                scan_result = $fscanf(f_y_out, "%s", line_buffer);
                if (line_buffer != "P2") begin
                    $display("ERROR: Not a valid P2 format PGM file (Y component)");
                    error_count = error_count + 1;
                end else begin
                    scan_result = $fscanf(f_y_out, "%d %d", width, height);
                    if (scan_result != 2) begin
                        $display("ERROR: Cannot read Y component dimensions (scan_result=%d)", scan_result);
                        error_count = error_count + 1;
                    end else begin
                        scan_result = $fscanf(f_y_out, "%d", max_val);
                        if (scan_result != 1) begin
                            $display("ERROR: Cannot read Y component max value");
                            error_count = error_count + 1;
                        end else begin
                            $display("Reading Y component file: width=%d, height=%d, max_val=%d", width, height, max_val);
                            
                            scan_result = $fscanf(f_cb_out, "%s", line_buffer);
                            if (line_buffer != "P2") begin
                                $display("ERROR: Not a valid P2 format PGM file (Cb component)");
                                error_count = error_count + 1;
                            end else begin
                                scan_result = $fscanf(f_cb_out, "%d %d", width_cb, height_cb);
                                if (scan_result != 2) begin
                                    $display("ERROR: Cannot read Cb component dimensions (scan_result=%d)", scan_result);
                                    error_count = error_count + 1;
                                end else begin
                                    scan_result = $fscanf(f_cb_out, "%d", max_val_cb);
                                    if (scan_result != 1) begin
                                        $display("ERROR: Cannot read Cb component max value");
                                        error_count = error_count + 1;
                                    end else begin
                                        $display("Reading Cb component file: width=%d, height=%d, max_val=%d", width_cb, height_cb, max_val_cb);
                                        
                                        scan_result = $fscanf(f_cr_out, "%s", line_buffer);
                                        if (line_buffer != "P2") begin
                                            $display("ERROR: Not a valid P2 format PGM file (Cr component)");
                                            error_count = error_count + 1;
                                        end else begin
                                            scan_result = $fscanf(f_cr_out, "%d %d", width_cr, height_cr);
                                            if (scan_result != 2) begin
                                                $display("ERROR: Cannot read Cr component dimensions (scan_result=%d)", scan_result);
                                                error_count = error_count + 1;
                                            end else begin
                                                scan_result = $fscanf(f_cr_out, "%d", max_val_cr);
                                                if (scan_result != 1) begin
                                                    $display("ERROR: Cannot read Cr component max value");
                                                    error_count = error_count + 1;
                                                end else begin
                                                    $display("Reading Cr component file: width=%d, height=%d, max_val=%d", width_cr, height_cr, max_val_cr);
                                                    
                                                    for (j = 0; j < height; j = j + 1) begin
                                                        for (i = 0; i < width; i = i + 1) begin
                                                            if ($feof(f_y_out)) begin
                                                                $display("ERROR: Y component file ended prematurely");
                                                                error_count = error_count + 1;
                                                                j = height;
                                                                i = width;
                                                            end else begin
                                                                scan_result = $fscanf(f_y_out, "%d", pixel_val);
                                                                if (scan_result != 1) begin
                                                                    $display("ERROR: Failed to read Y component data");
                                                                    error_count = error_count + 1;
                                                                    j = height;
                                                                    i = width;
                                                                end else begin
                                                                    y_data[j * width + i] = pixel_val;
                                                                end
                                                            end
                                                            
                                                            if ($feof(f_cb_out)) begin
                                                                $display("ERROR: Cb component file ended prematurely");
                                                                error_count = error_count + 1;
                                                                j = height;
                                                                i = width;
                                                            end else begin
                                                                scan_result = $fscanf(f_cb_out, "%d", pixel_val);
                                                                if (scan_result != 1) begin
                                                                    $display("ERROR: Failed to read Cb component data");
                                                                    error_count = error_count + 1;
                                                                    j = height;
                                                                    i = width;
                                                                end else begin
                                                                    cb_data[j * width + i] = pixel_val;
                                                                end
                                                            end
                                                            
                                                            if ($feof(f_cr_out)) begin
                                                                $display("ERROR: Cr component file ended prematurely");
                                                                error_count = error_count + 1;
                                                                j = height;
                                                                i = width;
                                                            end else begin
                                                                scan_result = $fscanf(f_cr_out, "%d", pixel_val);
                                                                if (scan_result != 1) begin
                                                                    $display("ERROR: Failed to read Cr component data");
                                                                    error_count = error_count + 1;
                                                                    j = height;
                                                                    i = width;
                                                                end else begin
                                                                    cr_data[j * width + i] = pixel_val;
                                                                end
                                                            end
                                                        end
                                                    end
                                                    
                                                    if (error_count == 0) begin
                                                        $display("Successfully read YCbCr component data, total %d pixels", width * height);
                                                        $fclose(f_y_out);
                                                        $fclose(f_cb_out);
                                                        $fclose(f_cr_out);
                                                        
                                                        f_rgb_recon = $fopen("output/out_rgb_reconstructed.ppm", "w");
                                                        
                                                        if (f_rgb_recon == 0) begin
                                                            $display("ERROR: Cannot create reconstructed RGB output file");
                                                            error_count = error_count + 1;
                                                        end else begin
                                                            $fdisplay(f_rgb_recon, "P3");
                                                            $fdisplay(f_rgb_recon, "# Reconstructed RGB image");
                                                            $fdisplay(f_rgb_recon, "%d %d", width, height);
                                                            $fdisplay(f_rgb_recon, "%d", 255);
                                                            
                                                            $display("Starting YCbCr to RGB reconstruction processing...");
                                                            
                                                            recon_count = 0;
                                                            
                                                            for (j = 0; j < height; j = j + 1) begin
                                                                for (i = 0; i < width; i = i + 1) begin
                                                                    @(posedge clk);
                                                                    ycbcr_data_valid = 1'b1;
                                                                    y_in_recon = y_data[j * width + i];
                                                                    cb_in_recon = cb_data[j * width + i];
                                                                    cr_in_recon = cr_data[j * width + i];
                                                                    
                                                                    repeat(3) @(posedge clk);
                                                                    
                                                                    if (rgb_recon_data_out_valid) begin
                                                                        recon_count = recon_count + 1;
                                                                        
                                                                        recon_r[j * width + i] = r_out_recon;
                                                                        recon_g[j * width + i] = g_out_recon;
                                                                        recon_b[j * width + i] = b_out_recon;
                                                                        
                                                                        if (i % 5 == 0 && i > 0) begin
                                                                            $fdisplay(f_rgb_recon, "");
                                                                        end
                                                                        $fwrite(f_rgb_recon, "%d %d %d ", 
                                                                               r_out_recon, g_out_recon, b_out_recon);
                                                                    end
                                                                    
                                                                    @(posedge clk);
                                                                    ycbcr_data_valid = 1'b0;
                                                                    y_in_recon = 8'd0;
                                                                    cb_in_recon = 8'd0;
                                                                    cr_in_recon = 8'd0;
                                                                end
                                                                $fdisplay(f_rgb_recon, "");
                                                            end
                                                            
                                                            timeout_count = 0;
                                                            while (recon_count < width * height && timeout_count < 1000) begin
                                                                @(posedge clk);
                                                                timeout_count = timeout_count + 1;
                                                                
                                                                if (rgb_recon_data_out_valid) begin
                                                                    recon_count = recon_count + 1;
                                                                    
                                                                    $fwrite(f_rgb_recon, "%d %d %d ", 
                                                                           r_out_recon, g_out_recon, b_out_recon);
                                                                end
                                                            end
                                                            
                                                            $fdisplay(f_rgb_recon, "");
                                                            
                                                            $display("YCbCr to RGB reconstruction processing completed, reconstructed %d pixels", recon_count);
                                                            $fclose(f_rgb_recon);
                                                            $display("Reconstructed RGB image saved as rgb_reconstructed.ppm");
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    endtask
    
    initial begin
        $dumpfile("rgb2ycbcr.vcd");
        $dumpvars(0, tb_rgb2ycbcr);
    end

endmodule