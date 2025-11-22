`timescale 1ns/1ps
module tb_dilation;

    parameter TCLK = 10;
    localparam IMAGE_WIDTH = 320;
    localparam IMAGE_HEIGHT = 464;
    localparam DATA_WIDTH = 8;
    localparam OUTBUF_SIZE = IMAGE_WIDTH * IMAGE_HEIGHT;

    reg clk = 0;
    reg rst_n = 0;
    reg gray_valid = 0;
    reg [DATA_WIDTH-1:0] gray_in = 0;

    wire bin_valid;
    wire [DATA_WIDTH-1:0] bin_out;
    
    wire [DATA_WIDTH-1:0] bin_inverted;
    assign bin_inverted = (bin_out == 8'd255) ? 8'd0 : 8'd255;
    
    wire pixel_out_valid_white;
    wire [DATA_WIDTH-1:0] pixel_out_white;
    
    wire pixel_out_valid_black;
    wire [DATA_WIDTH-1:0] pixel_out_black;

    binarize #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .THRESH(128)
    ) binarize_inst (
        .clk(clk),
        .rst(!rst_n),
        .gray_valid(gray_valid),
        .gray(gray_in),
        .bin_valid(bin_valid),
        .bin_out(bin_out)
    );

    Dilation #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .DATA_WIDTH(DATA_WIDTH),
        .BACKGROUND_COLOR(1)
    ) dut_white (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(bin_valid),
        .pixel_in(bin_out),
        .pixel_out_valid(pixel_out_valid_white),
        .pixel_out(pixel_out_white)
    );
    
    Dilation #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .DATA_WIDTH(DATA_WIDTH),
        .BACKGROUND_COLOR(0)
    ) dut_black (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(bin_valid),
        .pixel_in(bin_inverted),
        .pixel_out_valid(pixel_out_valid_black),
        .pixel_out(pixel_out_black)
    );

    initial forever #(TCLK/2) clk = ~clk;

    integer f_in, f_out, f_bin;
    integer i, j;
    integer scanned;
    integer width, height, maxv;
    reg [8*16-1:0] magic;
    integer r_val;
    integer OUT_MAX;
    reg [7:0] outbuf_white [0:OUTBUF_SIZE-1];
    reg [7:0] outbuf_black [0:OUTBUF_SIZE-1];
    reg [7:0] binbuf_white [0:OUTBUF_SIZE-1];
    reg [7:0] binbuf_black [0:OUTBUF_SIZE-1];
    integer out_idx_white, out_idx_black, bin_idx_white, bin_idx_black;
    integer tmp;

    task test_dilation_white;
        input [8*128-1:0] input_filename;
        input [8*128-1:0] output_filename;
        input [8*128-1:0] bin_filename;
    begin
        $display("TB: Testing white background dilation algorithm");
        
        f_in = $fopen(input_filename, "r");
        if (f_in == 0) begin
            $display("ERROR: cannot open input file %s", input_filename);
            $finish;
        end
        
        scanned = $fscanf(f_in, "%s", magic);
        if (magic != "P2") begin
            $display("ERROR: input file is not PGM P2 format");
            $fclose(f_in);
            $finish;
        end
        
        scanned = 0;
        while (scanned != 2) begin
            scanned = $fscanf(f_in, "%d %d", width, height);
            if (scanned != 2) begin
                tmp = $fgetc(f_in);
                if (tmp == "#") begin 
                    while ($fgetc(f_in) != 10) begin end 
                end
            end
        end

        scanned = 0;
        while (scanned != 1) begin
            scanned = $fscanf(f_in, "%d", maxv);
            if (scanned != 1) begin
                tmp = $fgetc(f_in);
                if (tmp == "#") begin 
                    while ($fgetc(f_in) != 10) begin end 
                end
            end
        end

        if (width != IMAGE_WIDTH) begin 
            $display("ERROR: width mismatch (%0d vs %0d)", width, IMAGE_WIDTH); 
            $finish; 
        end
        if (height != IMAGE_HEIGHT) begin 
            $display("ERROR: height mismatch (%0d vs %0d)", height, IMAGE_HEIGHT); 
            $finish; 
        end

        OUT_MAX = width * height;
        if (OUT_MAX > OUTBUF_SIZE) begin 
            $display("ERROR: OUTBUF_SIZE too small"); 
            $finish; 
        end
        
        for (i = 0; i < OUT_MAX; i = i + 1) begin 
            outbuf_white[i] = 8'd0; 
            binbuf_white[i] = 8'd0;
        end
        
        rst_n = 0;
        gray_valid = 0;
        #(10*TCLK);
        rst_n = 1;
        #(10*TCLK);
        
        $display("TB: Starting white background dilation processing...");
        out_idx_white = 0;
        bin_idx_white = 0;
        
        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                scanned = $fscanf(f_in, "%d", r_val);
                if (scanned != 1) r_val = 0;
                
                if (maxv != 0) r_val = (r_val * 255) / maxv;
                if (r_val < 0) r_val = 0;
                if (r_val > 255) r_val = 255;
                
                gray_in = r_val;
                gray_valid = 1'b1;
                
                @(posedge clk);
                
                if (bin_valid && bin_idx_white < OUT_MAX) begin
                    binbuf_white[bin_idx_white] = bin_out;
                    bin_idx_white = bin_idx_white + 1;
                end
                
                if (pixel_out_valid_white && out_idx_white < OUT_MAX) begin
                    outbuf_white[out_idx_white] = pixel_out_white;
                    out_idx_white = out_idx_white + 1;
                end
                
                if (out_idx_white % 1000 == 0) 
                    $display("TB: Processed %0d/%0d pixels", out_idx_white, OUT_MAX);
            end
        end
        
        gray_valid = 1'b0;
        
        for (i = 0; i < 10; i = i + 1) @(posedge clk);
        
        while (out_idx_white < OUT_MAX) begin
            outbuf_white[out_idx_white] = 8'd255;
            out_idx_white = out_idx_white + 1;
        end
        
        $fclose(f_in);
        $display("TB: White background dilation processing completed");
        
        f_bin = $fopen(bin_filename, "w");
        if (f_bin == 0) begin
            $display("ERROR: cannot create binarization file %s", bin_filename);
            $fclose(f_in);
            $finish;
        end
        
        $fdisplay(f_bin, "P2");
        $fdisplay(f_bin, "%0d %0d", width, height);
        $fdisplay(f_bin, "255");
        
        for (i = 0; i < OUT_MAX; i = i + 1) begin
            $fwrite(f_bin, "%0d ", binbuf_white[i]);
            if ((i + 1) % width == 0) $fwrite(f_bin, "\n");
        end
        
        $fclose(f_bin);
        $display("TB: Wrote binarization result to %s", bin_filename);
        
        f_out = $fopen(output_filename, "w");
        if (f_out == 0) begin
            $display("ERROR: cannot create output file %s", output_filename);
            $finish;
        end
        
        $fdisplay(f_out, "P2");
        $fdisplay(f_out, "%0d %0d", width, height);
        $fdisplay(f_out, "255");
        
        for (i = 0; i < OUT_MAX; i = i + 1) begin
            $fwrite(f_out, "%0d ", outbuf_white[i]);
            if ((i + 1) % width == 0) $fwrite(f_out, "\n");
        end
        
        $fclose(f_out);
        $display("TB: Wrote white background dilation result to %s", output_filename);
        
        $display("TB: White background dilation test completed successfully");
    end
    endtask

    task test_dilation_black;
        input [8*128-1:0] input_filename;
        input [8*128-1:0] output_filename;
        input [8*128-1:0] bin_filename;
    begin
        $display("TB: Testing black background dilation algorithm");
        
        f_in = $fopen(input_filename, "r");
        if (f_in == 0) begin
            $display("ERROR: cannot open input file %s", input_filename);
            $finish;
        end
        
        scanned = $fscanf(f_in, "%s", magic);
        if (magic != "P2") begin
            $display("ERROR: input file is not PGM P2 format");
            $fclose(f_in);
            $finish;
        end
        
        scanned = 0;
        while (scanned != 2) begin
            scanned = $fscanf(f_in, "%d %d", width, height);
            if (scanned != 2) begin
                tmp = $fgetc(f_in);
                if (tmp == "#") begin 
                    while ($fgetc(f_in) != 10) begin end 
                end
            end
        end

        scanned = 0;
        while (scanned != 1) begin
            scanned = $fscanf(f_in, "%d", maxv);
            if (scanned != 1) begin
                tmp = $fgetc(f_in);
                if (tmp == "#") begin 
                    while ($fgetc(f_in) != 10) begin end 
                end
            end
        end

        if (width != IMAGE_WIDTH) begin 
            $display("ERROR: width mismatch (%0d vs %0d)", width, IMAGE_WIDTH); 
            $finish; 
        end
        if (height != IMAGE_HEIGHT) begin 
            $display("ERROR: height mismatch (%0d vs %0d)", height, IMAGE_HEIGHT); 
            $finish; 
        end

        OUT_MAX = width * height;
        if (OUT_MAX > OUTBUF_SIZE) begin 
            $display("ERROR: OUTBUF_SIZE too small"); 
            $finish; 
        end
        
        for (i = 0; i < OUT_MAX; i = i + 1) begin 
            outbuf_black[i] = 8'd0; 
            binbuf_black[i] = 8'd0;
        end
        
        rst_n = 0;
        gray_valid = 0;
        #(10*TCLK);
        rst_n = 1;
        #(10*TCLK);
        
        $display("TB: Starting black background dilation processing...");
        out_idx_black = 0;
        bin_idx_black = 0;
        
        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                scanned = $fscanf(f_in, "%d", r_val);
                if (scanned != 1) r_val = 0;
                
                if (maxv != 0) r_val = (r_val * 255) / maxv;
                if (r_val < 0) r_val = 0;
                if (r_val > 255) r_val = 255;
                
                gray_in = r_val;
                gray_valid = 1'b1;
                
                @(posedge clk);
                
                if (bin_valid && bin_idx_black < OUT_MAX) begin
                    binbuf_black[bin_idx_black] = bin_inverted;
                    bin_idx_black = bin_idx_black + 1;
                end
                
                if (pixel_out_valid_black && out_idx_black < OUT_MAX) begin
                    outbuf_black[out_idx_black] = pixel_out_black;
                    out_idx_black = out_idx_black + 1;
                end
                
                if (out_idx_black % 1000 == 0) 
                    $display("TB: Processed %0d/%0d pixels", out_idx_black, OUT_MAX);
            end
        end
        
        gray_valid = 1'b0;
        
        for (i = 0; i < 10; i = i + 1) @(posedge clk);
        
        while (out_idx_black < OUT_MAX) begin
            outbuf_black[out_idx_black] = 8'd0;
            out_idx_black = out_idx_black + 1;
        end
        
        $fclose(f_in);
        $display("TB: Black background dilation processing completed");
        
        f_bin = $fopen(bin_filename, "w");
        if (f_bin == 0) begin
            $display("ERROR: cannot create binarization file %s", bin_filename);
            $fclose(f_in);
            $finish;
        end
        
        $fdisplay(f_bin, "P2");
        $fdisplay(f_bin, "%0d %0d", width, height);
        $fdisplay(f_bin, "255");
        
        for (i = 0; i < OUT_MAX; i = i + 1) begin
            $fwrite(f_bin, "%0d ", binbuf_black[i]);
            if ((i + 1) % width == 0) $fwrite(f_bin, "\n");
        end
        
        $fclose(f_bin);
        $display("TB: Wrote binarization result to %s", bin_filename);
        
        f_out = $fopen(output_filename, "w");
        if (f_out == 0) begin
            $display("ERROR: cannot create output file %s", output_filename);
            $finish;
        end
        
        $fdisplay(f_out, "P2");
        $fdisplay(f_out, "%0d %0d", width, height);
        $fdisplay(f_out, "255");
        
        for (i = 0; i < OUT_MAX; i = i + 1) begin
            $fwrite(f_out, "%0d ", outbuf_black[i]);
            if ((i + 1) % width == 0) $fwrite(f_out, "\n");
        end
        
        $fclose(f_out);
        $display("TB: Wrote black background dilation result to %s", output_filename);
        
        $display("TB: Black background dilation test completed successfully");
    end
    endtask

    initial begin
        #100;
        
        test_dilation_white("data/gray1.pgm", 
                          "output/out_dilation_white.pgm",
                          "output/out_binarize_whitebg_dilation.pgm");
        
        #100;
        
        test_dilation_black("data/gray1.pgm", 
                          "output/out_dilation_black.pgm",
                          "output/out_binarize_blackbg_dilation.pgm");
        
        $display("TB: Dilation test completed successfully");
        #100;
        $finish;
    end

endmodule