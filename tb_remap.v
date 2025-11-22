`timescale 1ns/1ps
module tb_remap;
    parameter TCLK = 10;
    parameter IMAGE_WIDTH  = 640;
    parameter IMAGE_HEIGHT = 480;
    parameter FRAC = 12;
    
    reg clk = 0;
    reg rst = 1;

    reg                 mem_wr_en = 0;
    reg  [31:0]         mem_wr_addr = 0;
    reg  [7:0]          mem_wr_data = 0;
    reg                 map_valid = 0;
    reg  [23:0]         map_x = 0;
    reg  [23:0]         map_y = 0;
    wire                map_ready;
    wire                out_valid;
    wire [7:0]          out_pixel;

    remap #(.IMAGE_WIDTH(IMAGE_WIDTH), .IMAGE_HEIGHT(IMAGE_HEIGHT), .FRAC(FRAC)) dut (
        .clk(clk), .rst(rst),
        .mem_wr_en(mem_wr_en), .mem_wr_addr(mem_wr_addr), .mem_wr_data(mem_wr_data),
        .map_valid(map_valid), .map_x(map_x), .map_y(map_y), .map_ready(map_ready),
        .out_valid(out_valid), .out_pixel(out_pixel)
    );

    initial forever #(TCLK/2) clk = ~clk;
    initial begin rst = 1; # (20*TCLK); rst = 0; end

    real fx = 5.3591573396163199e+02;
    real fy = 5.3591573396163199e+02;
    real cx = 3.4228315473308373e+02;
    real cy = 2.3557082909788173e+02;
    real k1 = -2.6637260909660682e-01;
    real k2 = -3.8588898922304653e-02;
    real p1 =  1.7831947042852964e-03;
    real p2 = -2.8122100441115472e-04;
    real k3 =  2.3839153080878486e-01;

    integer f_in, f_out;
    integer scanned;
    integer width, height, maxv;
    integer i, idx;
    integer pix;
    integer OUT_MAX;
    reg [8*16-1:0] magic;
    reg [7:0] srcbuf [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    reg [7:0] outbuf [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];

    integer r, c;
    real x, y, x0, y0, r2, radial, dx, dy;
    integer sx, sy;
    integer iter;
    real ux, uy;

    integer DEBUG_PIXELS;
    integer mapped_count;
    integer total_map;
    integer src_idx;
    integer wait_cycles;
    integer t;
    integer ix_test, iy_test, exp_idx;
    reg [7:0] read_val;

    initial begin
        f_in = $fopen("data/left01.pgm","r");
        if (f_in == 0) begin
            $display("TB: Cannot open left01.pgm, using synthetic gradient");
            OUT_MAX = IMAGE_WIDTH * IMAGE_HEIGHT;
            for (i=0;i<OUT_MAX;i=i+1) begin
                srcbuf[i] = i % 256;
                outbuf[i] = 0;
            end
        end else begin
            scanned = $fscanf(f_in, "%s", magic);
            scanned = $fscanf(f_in, "%d %d", width, height);
            scanned = $fscanf(f_in, "%d", maxv);
            if (scanned < 1 || width != IMAGE_WIDTH || height != IMAGE_HEIGHT) begin
                $display("TB: bad PGM or size mismatch (%dx%d vs %dx%d), using synthetic", width, height, IMAGE_WIDTH, IMAGE_HEIGHT);
                OUT_MAX = IMAGE_WIDTH * IMAGE_HEIGHT;
                for (i=0;i<OUT_MAX;i=i+1) begin
                    srcbuf[i] = i % 256;
                    outbuf[i] = 0;
                end
                $fclose(f_in);
            end else begin
                OUT_MAX = width * height;
                for (i=0;i<OUT_MAX;i=i+1) begin
                    scanned = $fscanf(f_in, "%d", pix);
                    if (scanned != 1) pix = 0;
                    if (maxv != 255) pix = (pix * 255) / maxv;
                    if (pix < 0) pix = 0; if (pix > 255) pix = 255;
                    srcbuf[i] = pix[7:0];
                    outbuf[i] = 8'd0;
                end
                $fclose(f_in);
                $display("TB: loaded left01.pgm %dx%d maxval=%d", width, height, maxv);
            end
        end

        for (i=0;i<OUT_MAX;i=i+1) begin
            @(posedge clk);
            mem_wr_addr <= i;
            mem_wr_data <= srcbuf[i];
            mem_wr_en <= 1;
            @(posedge clk);
            mem_wr_en <= 0;
            if ((i & 16383) == 0) $display("TB: preload %0d/%0d", i, OUT_MAX);
        end
        @(posedge clk);
        $display("TB: preload complete");

        for (t = 0; t < 5; t = t + 1) begin
            ix_test = (t * (IMAGE_WIDTH-1)) / 4;
            iy_test = (t * (IMAGE_HEIGHT-1)) / 4;
            exp_idx = iy_test * IMAGE_WIDTH + ix_test;
            
            sx = ix_test << FRAC;
            sy = iy_test << FRAC;

            while (!map_ready) @(posedge clk);
            @(posedge clk);
            map_valid <= 1;
            map_x <= sx[23:0];
            map_y <= sy[23:0];
            @(posedge clk);
            map_valid <= 0;

            wait_cycles = 0;
            while (!out_valid) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
                if (wait_cycles > 2000) begin
                    $display("VERIFY TIMEOUT: t=%0d ix=%0d iy=%0d addr=%0d expected_val=%0d", t, ix_test, iy_test, exp_idx, srcbuf[exp_idx]);
                    $finish;
                end
            end
            @(posedge clk);
            read_val = out_pixel;

            if (read_val !== srcbuf[exp_idx]) begin
                $display("VERIFY FAIL: t=%0d ix=%0d iy=%0d addr=%0d | got=%0d (0x%02h) expected=%0d (0x%02h)", 
                    t, ix_test, iy_test, exp_idx, read_val, read_val, srcbuf[exp_idx], srcbuf[exp_idx]);
                $finish;
            end else begin
                $display("VERIFY PASS: t=%0d ix=%0d iy=%0d addr=%0d val=%0d (0x%02h)", t, ix_test, iy_test, exp_idx, read_val, read_val);
            end
        end
        $display("TB: all verification tests PASSED!");

        DEBUG_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT;
        total_map = (DEBUG_PIXELS > OUT_MAX) ? OUT_MAX : DEBUG_PIXELS;
        mapped_count = 0;

        for (src_idx = 0; src_idx < total_map; src_idx = src_idx + 1) begin
            r = src_idx / IMAGE_WIDTH;
            c = src_idx % IMAGE_WIDTH;

            x = (c - cx) / fx;
            y = (r - cy) / fy;
            x0 = x; y0 = y;
            for (iter=0; iter<5; iter=iter+1) begin
                r2 = x0*x0 + y0*y0;
                radial = 1.0 + k1*r2 + k2*r2*r2 + k3*r2*r2*r2;
                dx = 2.0*p1*x0*y0 + p2*(r2 + 2.0*x0*x0);
                dy = p1*(r2 + 2.0*y0*y0) + 2.0*p2*x0*y0;
                x0 = (x - dx) / radial;
                y0 = (y - dy) / radial;
            end
            ux = x0*fx + cx;
            uy = y0*fy + cy;

            sx = $rtoi(ux * (1<<FRAC) + 0.5);
            sy = $rtoi(uy * (1<<FRAC) + 0.5);

            while (!map_ready) @(posedge clk);
            @(posedge clk);
            map_valid <= 1;
            map_x <= sx[23:0];
            map_y <= sy[23:0];
            @(posedge clk);
            map_valid <= 0;

            wait_cycles = 0;
            while (!out_valid) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
                if (wait_cycles > 2000) begin
                    $display("ERROR: remap timeout at idx=%0d (r=%0d c=%0d)", src_idx, r, c);
                    $finish;
                end
            end
            @(posedge clk);
            outbuf[r*IMAGE_WIDTH + c] = out_pixel;
            mapped_count = mapped_count + 1;

            if ((mapped_count % 32768) == 0)
                $display("TB: remap %0d/%0d pixels", mapped_count, total_map);
        end

        $display("TB: remap complete, writing output...");

        f_out = $fopen("output/out_remap_left01.pgm","w");
        if (f_out == 0) begin
            $display("TB: ERROR opening output file");
        end else begin
            $fdisplay(f_out, "P2");
            $fdisplay(f_out, "%0d %0d", IMAGE_WIDTH, IMAGE_HEIGHT);
            $fdisplay(f_out, "255");
            for (r=0; r<IMAGE_HEIGHT; r=r+1) begin
                for (c=0; c<IMAGE_WIDTH; c=c+1) begin
                    idx = r*IMAGE_WIDTH + c;
                    $fwrite(f_out, "%0d ", outbuf[idx]);
                end
                $fwrite(f_out, "\n");
            end
            $fclose(f_out);
            $display("TB: wrote output/out_remap_left01.pgm");
        end

        #1000 $finish;
    end

    initial begin
        $dumpfile("tb_remap_debug.vcd");
        $dumpvars(0, tb_remap);
    end

endmodule