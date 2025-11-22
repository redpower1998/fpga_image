`timescale 1ns / 1ps
module tb_rgb2gray_sobel;

    parameter TCLK = 10;
    localparam SOBEL_IMAGE_WIDTH = 320;
    localparam OUTBUF_SIZE = 2000000;

    reg clk = 0;
    reg rst = 1;
    reg rst_n = 0;

    reg [7:0] pixel_r = 0;
    reg [7:0] pixel_g = 0;
    reg [7:0] pixel_b = 0;
    reg       pixel_in_valid = 0;

    wire [7:0] gray_pixel_wire;
    wire       gray_valid_wire;
    reg [7:0] gray_reg = 0;
    reg       gray_valid_reg = 0;

    wire [7:0] sobel_pixel_wire;
    wire       sobel_valid_wire;

    rgb2gray rgb2gray_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .data_valid(pixel_in_valid),
        .r         (pixel_r),
        .g         (pixel_g),
        .b         (pixel_b),
        .gray_valid(gray_valid_wire),
        .gray      (gray_pixel_wire)
    );

    sobel_basic #(.IMAGE_WIDTH(SOBEL_IMAGE_WIDTH)) sobel_basic_inst (
        .clk            (clk),
        .rst            (rst),
        .pixel_in_valid (gray_valid_reg),
        .pixel_in       (gray_reg),
        .pixel_out_valid(sobel_valid_wire),
        .pixel_out      (sobel_pixel_wire)
    );

    initial forever #(TCLK/2) clk = ~clk;

    initial begin
        rst = 1; rst_n = 0;
        # (10 * TCLK);
        rst = 0; rst_n = 1;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            gray_reg <= 8'd0;
            gray_valid_reg <= 1'b0;
        end else begin
            gray_reg <= gray_pixel_wire;
            gray_valid_reg <= gray_valid_wire;
        end
    end

    integer f_in;
    integer f_out;
    integer i, j;
    integer r_byte;
    integer scanned;
    integer width, height, maxv;
    reg [8*16-1:0] magic;
    integer OUT_MAX;
    reg [7:0] outbuf [0:OUTBUF_SIZE-1];
    reg got [0:OUTBUF_SIZE-1];
    integer out_cnt;
    integer idx;
    integer center_r, center_c;
    integer timeout;
    integer rr, gg, bb;
    integer tmp;
    reg isP6;

    initial begin
        f_in = $fopen("data/rgb1.ppm", "r");
        if (f_in == 0) begin
            $display("ERROR: cannot open input file rgb1.ppm");
            $finish;
        end

        scanned = $fscanf(f_in, "%s", magic);
        if (scanned != 1) begin $display("Bad file (no magic)"); $finish; end
        if (magic == "P6") isP6 = 1; else if (magic == "P3") isP6 = 0; else begin
            $display("ERROR: unsupported ppm magic: %s", magic);
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

        if (width != SOBEL_IMAGE_WIDTH) begin
            $display("ERROR: PPM width (%0d) != sobel IMAGE_WIDTH (%0d). Edit tb.", width, SOBEL_IMAGE_WIDTH);
            $finish;
        end

        if (isP6) begin
            tmp = $fgetc(f_in);
        end

        OUT_MAX = width * height;
        if (OUT_MAX > OUTBUF_SIZE) begin
            $display("ERROR: image too large for outbuf (%0d). Increase OUTBUF_SIZE.", OUT_MAX);
            $finish;
        end

        for (i = 0; i < OUT_MAX; i = i + 1) begin
            outbuf[i] = 8'd0;
            got[i] = 1'b0;
        end
        out_cnt = 0;

        if (isP6) begin
            for (i = 0; i < height; i = i + 1) begin
                for (j = 0; j < width; j = j + 1) begin
                    r_byte = $fgetc(f_in); pixel_r = r_byte;
                    r_byte = $fgetc(f_in); pixel_g = r_byte;
                    r_byte = $fgetc(f_in); pixel_b = r_byte;

                    pixel_in_valid = 1'b1;
                    @(posedge clk);
                    pixel_in_valid = 1'b0;

                    repeat (4) begin
                        @(posedge clk);
                        if (sobel_valid_wire) begin
                            center_r = sobel_basic_inst.center_row_s1;
                            center_c = sobel_basic_inst.center_col_s1;
                            if ((center_r >= 0) && (center_c >= 0) && (center_r < height) && (center_c < width)) begin
                                idx = center_r * width + center_c;
                                if (!got[idx]) begin
                                    outbuf[idx] = sobel_pixel_wire;
                                    got[idx] = 1'b1;
                                    out_cnt = out_cnt + 1;
                                end
                            end
                        end
                    end
                end
            end
        end else begin
            for (i = 0; i < height; i = i + 1) begin
                for (j = 0; j < width; j = j + 1) begin
                    scanned = $fscanf(f_in, "%d", rr);
                    if (scanned != 1) rr = 0;
                    scanned = $fscanf(f_in, "%d", gg);
                    if (scanned != 1) gg = 0;
                    scanned = $fscanf(f_in, "%d", bb);
                    if (scanned != 1) bb = 0;
                    pixel_r = rr[7:0];
                    pixel_g = gg[7:0];
                    pixel_b = bb[7:0];

                    pixel_in_valid = 1'b1;
                    @(posedge clk);
                    pixel_in_valid = 1'b0;

                    repeat (4) begin
                        @(posedge clk);
                        if (sobel_valid_wire) begin
                            center_r = sobel_basic_inst.center_row_s1;
                            center_c = sobel_basic_inst.center_col_s1;
                            if ((center_r >= 0) && (center_c >= 0) && (center_r < height) && (center_c < width)) begin
                                idx = center_r * width + center_c;
                                if (!got[idx]) begin
                                    outbuf[idx] = sobel_pixel_wire;
                                    got[idx] = 1'b1;
                                    out_cnt = out_cnt + 1;
                                end
                            end
                        end
                    end
                end
            end
        end

        timeout = 0;
        while ((out_cnt < OUT_MAX) && (timeout < 300000)) begin
            @(posedge clk);
            if (sobel_valid_wire) begin
                center_r = sobel_basic_inst.center_row_s1;
                center_c = sobel_basic_inst.center_col_s1;
                if ((center_r >= 0) && (center_c >= 0) && (center_r < height) && (center_c < width)) begin
                    idx = center_r * width + center_c;
                    if (!got[idx]) begin
                        outbuf[idx] = sobel_pixel_wire;
                        got[idx] = 1'b1;
                        out_cnt = out_cnt + 1;
                    end
                end
            end
            timeout = timeout + 1;
        end

        if (out_cnt < OUT_MAX) $display("WARNING: captured %0d/%0d outputs", out_cnt, OUT_MAX);

        f_out = $fopen("output/out_sobel1.pgm", "w");
        if (f_out == 0) begin $display("ERROR: cannot open output file"); $finish; end
        $fdisplay(f_out, "P2");
        $fdisplay(f_out, "%0d %0d", width, height);
        $fdisplay(f_out, "255");
        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                $fwrite(f_out, "%0d ", outbuf[i*width + j]);
            end
            $fwrite(f_out, "\n");
        end
        $fclose(f_out);
        $fclose(f_in);

        $display("Done. wrote out_sobel1.pgm captured=%0d expected=%0d", out_cnt, OUT_MAX);
        #1000;
        $finish;
    end

    initial begin
        $dumpfile("tb_rgb2gray_sobel.vcd");
        $dumpvars(0, tb_rgb2gray_sobel.rgb2gray_inst, tb_rgb2gray_sobel.sobel_basic_inst, tb_rgb2gray_sobel.clk, tb_rgb2gray_sobel.rst);
    end

endmodule