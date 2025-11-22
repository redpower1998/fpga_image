`timescale 1ns / 1ps
module tb_canny_baby;
    parameter TCLK = 10;
    localparam IMAGE_WIDTH = 320;
    localparam OUTBUF_SIZE = 2000000;

    reg clk = 0;
    reg rst = 1;

    reg [7:0] gray_in = 0;
    reg       gray_valid = 0;

    wire       nms_valid;
    wire [11:0] nms_mag;
    wire [31:0] center_row;
    wire [31:0] center_col;

    canny_nms #(.IMAGE_WIDTH(IMAGE_WIDTH)) dut (
        .clk(clk),
        .rst(rst),
        .gray_valid(gray_valid),
        .gray(gray_in),
        .nms_valid(nms_valid),
        .nms_mag(nms_mag),
        .center_row(center_row),
        .center_col(center_col)
    );

    initial forever #(TCLK/2) clk = ~clk;
    initial begin rst = 1; # (10*TCLK); rst = 0; end

    integer f_in, f_out;
    integer i, j;
    integer scanned;
    integer width, height, maxv;
    reg [8*16-1:0] magic;
    integer r_val;
    integer OUT_MAX;
    reg [11:0] magbuf [0:OUTBUF_SIZE-1];
    reg have_mag [0:OUTBUF_SIZE-1];
    integer captured;
    integer idx;
    integer tmp;
    integer timeout;

    integer HIGH_THRESH = 300;
    integer LOW_THRESH  = 150;

    reg strong_flag [0:OUTBUF_SIZE-1];
    reg weak_flag   [0:OUTBUF_SIZE-1];

    integer r, c, nx, ny, nidx;
    integer changed;

    initial begin
        f_in = $fopen("data/gray1.pgm", "r");
        if (f_in == 0) begin $display("ERROR: cannot open baby.pgm"); $finish; end

        scanned = $fscanf(f_in, "%s", magic);
        if ((scanned != 1) || (magic != "P2")) begin $display("ERROR: need P2 PGM"); $finish; end

        scanned = 0;
        while (scanned != 2) begin
            scanned = $fscanf(f_in, "%d %d", width, height);
            if (scanned != 2) begin
                tmp = $fgetc(f_in);
                if (tmp == "#") begin tmp = $fgetc(f_in); while (tmp != 10) tmp = $fgetc(f_in); end
            end
        end

        scanned = 0;
        while (scanned != 1) begin
            scanned = $fscanf(f_in, "%d", maxv);
            if (scanned != 1) begin
                tmp = $fgetc(f_in);
                if (tmp == "#") begin tmp = $fgetc(f_in); while (tmp != 10) tmp = $fgetc(f_in); end
            end
        end

        if (width != IMAGE_WIDTH) begin $display("ERROR: width mismatch (%0d vs %0d)", width, IMAGE_WIDTH); $finish; end

        OUT_MAX = width * height;
        if (OUT_MAX > OUTBUF_SIZE) begin $display("ERROR: OUTBUF_SIZE too small"); $finish; end

        for (i=0; i<OUT_MAX; i=i+1) begin
            magbuf[i] = 0;
            have_mag[i] = 0;
            strong_flag[i] = 0;
            weak_flag[i] = 0;
        end
        captured = 0;

        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                scanned = $fscanf(f_in, "%d", r_val);
                if (scanned != 1) r_val = 0;
                if (maxv != 0) r_val = (r_val * 255) / maxv;
                if (r_val < 0) r_val = 0; if (r_val > 255) r_val = 255;

                gray_in = r_val[7:0];
                gray_valid = 1;
                @(posedge clk);
                gray_valid = 0;

                repeat (6) begin
                    @(posedge clk);
                    if (nms_valid) begin
                        if ((center_row < height) && (center_col < width)) begin
                            idx = center_row * width + center_col;
                            if (!have_mag[idx]) begin
                                magbuf[idx] = nms_mag;
                                have_mag[idx] = 1;
                                captured = captured + 1;
                            end
                        end
                    end
                end
            end
        end

        timeout = 0;
        while ((captured < OUT_MAX) && (timeout < 500000)) begin
            @(posedge clk);
            if (nms_valid) begin
                if ((center_row < height) && (center_col < width)) begin
                    idx = center_row * width + center_col;
                    if (!have_mag[idx]) begin
                        magbuf[idx] = nms_mag;
                        have_mag[idx] = 1;
                        captured = captured + 1;
                    end
                end
            end
            timeout = timeout + 1;
        end

        $display("Captured %0d/%0d NMS mags", captured, OUT_MAX);
        $fclose(f_in);

        for (i=0;i<OUT_MAX;i=i+1) begin
            strong_flag[i] = 0;
            weak_flag[i]   = 0;
            if (have_mag[i]) begin
                if (magbuf[i] >= HIGH_THRESH) strong_flag[i] = 1;
                else if (magbuf[i] >= LOW_THRESH) weak_flag[i] = 1;
            end
        end

        changed = 1;
        while (changed) begin
            changed = 0;
            for (r=0; r<height; r=r+1) begin
                for (c=0; c<width; c=c+1) begin
                    idx = r*width + c;
                    if (weak_flag[idx]) begin
                        for (ny = (r>0? r-1: r); ny <= (r+1<height? r+1: r); ny=ny+1) begin
                            for (nx = (c>0? c-1: c); nx <= (c+1<width? c+1: c); nx=nx+1) begin
                                nidx = ny*width + nx;
                                if (strong_flag[nidx]) begin
                                    strong_flag[idx] = 1;
                                    weak_flag[idx] = 0;
                                    changed = 1;
                                end
                            end
                        end
                    end
                end
            end
        end

        f_out = $fopen("output/out_canny_baby.pgm", "w");
        if (f_out == 0) begin $display("ERROR: cannot open output file"); $finish; end
        $fdisplay(f_out, "P2");
        $fdisplay(f_out, "%0d %0d", width, height);
        $fdisplay(f_out, "255");
        for (r=0; r<height; r=r+1) begin
            for (c=0; c<width; c=c+1) begin
                idx = r*width + c;
                if (strong_flag[idx]) $fwrite(f_out, "%0d ", 255);
                else $fwrite(f_out, "%0d ", 0);
            end
            $fwrite(f_out, "\n");
        end
        $fclose(f_out);

        $display("Wrote output/out_canny_baby.pgm");
        #1000 $finish;
    end

    initial begin
        $dumpfile("tb_canny_baby.vcd");
        $dumpvars(0, tb_canny_baby.dut, tb_canny_baby.clk, tb_canny_baby.rst);
    end

endmodule