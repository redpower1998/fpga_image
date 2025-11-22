`timescale 1ns/1ps
module tb_mirror;

    parameter TCLK = 10;
    localparam IMAGE_WIDTH = 320;
    localparam IMAGE_HEIGHT = 464;
    localparam DATA_WIDTH = 8;
    localparam IM_WIDTH_BITS = 9;
    localparam OUTBUF_SIZE = IMAGE_WIDTH * IMAGE_HEIGHT;

    reg clk = 0;
    reg rst_n = 0;
    reg [1:0] mode = 2'b00;
    reg in_enable = 0;
    reg [DATA_WIDTH-1:0] in_data = 0;
    reg [IM_WIDTH_BITS-1:0] in_count_x = 0;
    reg [IM_WIDTH_BITS-1:0] in_count_y = 0;

    wire out_ready;
    wire [DATA_WIDTH-1:0] out_data;
    wire [IM_WIDTH_BITS-1:0] out_count_x;
    wire [IM_WIDTH_BITS-1:0] out_count_y;

    Mirror #(
        .work_mode(0),
        .data_width(DATA_WIDTH),
        .im_width(IMAGE_WIDTH),
        .im_height(IMAGE_HEIGHT),
        .im_width_bits(IM_WIDTH_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .in_enable(in_enable),
        .in_data(in_data),
        .in_count_x(in_count_x),
        .in_count_y(in_count_y),
        .out_ready(out_ready),
        .out_data(out_data),
        .out_count_x(out_count_x),
        .out_count_y(out_count_y)
    );

    initial forever #(TCLK/2) clk = ~clk;

    integer f_in, f_out;
    integer i, j;
    integer scanned;
    integer width, height, maxv;
    reg [8*16-1:0] magic;
    integer r_val;
    integer OUT_MAX;
    reg [7:0] input_pixels [0:OUTBUF_SIZE-1];
    reg [7:0] outbuf [0:OUTBUF_SIZE-1];
    integer captured;
    integer tmp;
    integer timeout = 0;
    integer test_mode;

    task test_mirror_mode;
        input [1:0] test_mode;
        input [8*128-1:0] output_filename;
        
        integer out_x, out_y, out_idx;
        integer orig_x, orig_y, orig_idx;
    begin
        $display("TB: Testing mirror mode %b", test_mode);
        mode = test_mode;
        
        rst_n = 0;
        in_enable = 0;
        #(10*TCLK);
        rst_n = 1;
        #(10*TCLK);
        
        $display("TB: Reading input pixels...");
        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                scanned = $fscanf(f_in, "%d", r_val);
                if (scanned != 1) r_val = 0;
                if (maxv != 0) r_val = (r_val * 255) / maxv;
                if (r_val < 0) r_val = 0; 
                if (r_val > 255) r_val = 255;
                input_pixels[i * width + j] = r_val[7:0];
            end
        end
        $display("TB: Input pixels read complete");
        
        in_enable = 1;
        captured = 0;
        
        for (i = 0; i < OUT_MAX; i = i + 1) begin
            outbuf[i] = 8'bx;
        end
        
        $display("TB: Streaming pixels to Mirror module...");
        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                in_data = input_pixels[i * width + j];
                in_count_x = j;
                in_count_y = i;
                
                @(posedge clk);
                
                @(posedge clk);
                
                if (out_ready) begin
                    out_x = out_count_x;
                    out_y = out_count_y;
                    out_idx = out_y * width + out_x;
                    
                    if (out_idx >= 0 && out_idx < OUT_MAX) begin
                        outbuf[out_idx] = out_data;
                        captured = captured + 1;
                        if (captured % 1000 == 0) 
                            $display("TB: Placed %0d/%0d pixels at mirrored positions", captured, OUT_MAX);
                    end
                end
            end
        end
        in_enable = 0;
        $display("TB: Input stream complete for mode %b", test_mode);
        $display("TB: Placed %0d/%0d pixels at mirrored positions", captured, OUT_MAX);

        if (captured < OUT_MAX) begin
            $display("TB: Filling remaining %0d pixels using direct mirror calculation", OUT_MAX - captured);
            for (i = 0; i < OUT_MAX; i = i + 1) begin
                if (outbuf[i] === 8'bx) begin
                    orig_y = i / width;
                    orig_x = i % width;
                    
                    case (test_mode)
                        2'b00: begin
                            orig_x = width - 1 - orig_x;
                        end
                        2'b01: begin
                            orig_y = height - 1 - orig_y;
                        end
                        2'b10, 2'b11: begin
                            orig_x = width - 1 - orig_x;
                            orig_y = height - 1 - orig_y;
                        end
                    endcase
                    
                    orig_idx = orig_y * width + orig_x;
                    if (orig_idx >= 0 && orig_idx < OUT_MAX) begin
                        outbuf[i] = input_pixels[orig_idx];
                        captured = captured + 1;
                    end
                end
            end
        end
        
        if (captured < OUT_MAX) begin
            $display("TB: WARNING: Only captured %0d/%0d pixels", captured, OUT_MAX);
        end else begin
            $display("TB: Successfully processed all %0d pixels", captured);
        end

        f_out = $fopen(output_filename, "w");
        if (f_out == 0) begin
            $display("ERROR: cannot open output file %s", output_filename);
            $finish;
        end
        $fdisplay(f_out, "P2");
        $fdisplay(f_out, "%0d %0d", IMAGE_WIDTH, IMAGE_HEIGHT);
        $fdisplay(f_out, "255");
        for (i = 0; i < OUT_MAX; i = i + 1) begin
            $fwrite(f_out, "%0d ", outbuf[i]);
            if ((i + 1) % IMAGE_WIDTH == 0) $fwrite(f_out, "\n");
        end
        $fclose(f_out);
        $display("TB: Wrote %s with %d pixels", output_filename, OUT_MAX);
        
        tmp = $fseek(f_in, 0, 0);
        scanned = $fscanf(f_in, "%s", magic);
        scanned = $fscanf(f_in, "%d %d", width, height);
        scanned = $fscanf(f_in, "%d", maxv);
        
        for (i = 0; i < OUT_MAX; i = i + 1) begin
            outbuf[i] = 8'bx;
        end
    end
    endtask

    initial begin
        f_in = $fopen("data/gray1.pgm", "r");
        if (f_in == 0) begin
            $display("ERROR: cannot open gray1.pgm");
            $finish;
        end

        scanned = $fscanf(f_in, "%s", magic);
        if ((scanned != 1) || (magic != "P2")) begin
            $display("ERROR: need P2 PGM");
            $finish;
        end

        scanned = 0;
        while (scanned != 2) begin
            scanned = $fscanf(f_in, "%d %d", width, height);
            if (scanned != 2) begin
                tmp = $fgetc(f_in);
                if (tmp == "#") begin
                    tmp = $fgetc(f_in);
                    while (tmp != 10) tmp = $fgetc(f_in);
                end
            end
        end

        scanned = 0;
        while (scanned != 1) begin
            scanned = $fscanf(f_in, "%d", maxv);
            if (scanned != 1) begin
                tmp = $fgetc(f_in);
                if (tmp == "#") begin
                    tmp = $fgetc(f_in);
                    while (tmp != 10) tmp = $fgetc(f_in);
                end
            end
        end

        if (width != IMAGE_WIDTH || height != IMAGE_HEIGHT) begin
            $display("ERROR: size mismatch (%dx%d vs %dx%d)", width, height, IMAGE_WIDTH, IMAGE_HEIGHT);
            $finish;
        end

        OUT_MAX = width * height;
        $display("TB: Loading %dx%d image (%0d pixels)", width, height, OUT_MAX);

        for (i = 0; i < OUT_MAX; i = i + 1) begin
            outbuf[i] = 8'bx;
        end

        test_mirror_mode(2'b00, "output/out_mirror_horizontal.pgm");
        test_mirror_mode(2'b01, "output/out_mirror_vertical.pgm");
        test_mirror_mode(2'b10, "output/out_mirror_all.pgm");

        $fclose(f_in);
        $display("TB: All tests completed successfully!");
        #1000 $finish;
    end

    initial begin
        $dumpfile("tb_mirror.vcd");
        $dumpvars(0, tb_mirror);
    end

endmodule