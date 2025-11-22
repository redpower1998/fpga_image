`timescale 1ns/1ps
module tb_sobel_basic;

reg clk;
reg rst;
reg pixel_in_valid;
reg [7:0] pixel_in;
wire pixel_out_valid;
wire [7:0] pixel_out;

localparam SIM_IMAGE_WIDTH = 320;
sobel_basic #(
    .IMAGE_WIDTH(SIM_IMAGE_WIDTH)
) uut (
    .clk            (clk),
    .rst            (rst),
    .pixel_in_valid (pixel_in_valid),
    .pixel_in       (pixel_in),
    .pixel_out_valid(pixel_out_valid),
    .pixel_out      (pixel_out)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst = 1'b1;
    pixel_in_valid = 1'b0;
    pixel_in = 8'd0;
    #200;
    rst = 1'b0;
    #100;

    drive_pgm(
        "data/gray1.pgm",
        "output/sobel_output.pgm"
    );

    #2000;
    $display("Testbench finished.");
    $finish;
end

task drive_pgm;
    input [8*256-1:0] infile;
    input [8*256-1:0] outfile;
    integer f_in, f_out;
    integer width, height, maxval;
    integer scan_res;
    integer i, j;
    integer pix;
    reg [7:0] ch;
    reg [16*8-1:0] magic;
    reg skip;

    integer OUT_MAX;
    reg [7:0] outbuf [0:655360];
    integer out_cnt;
    integer timeout_cnt;
    integer idx;
    integer r, c;
begin
    f_in = $fopen(infile, "r");
    if (f_in == 0) begin
        $display("ERROR: Cannot open input file %s", infile);
        $finish;
    end

    skip = 0;
    while (!skip) begin
        scan_res = $fscanf(f_in, "%s", magic);
        if (scan_res != 1) begin
            ch = $fgetc(f_in);
            if (ch == "#") begin
                while ($fgetc(f_in) != "\n") ;
            end
        end else skip = 1;
    end
    if (magic != "P2") begin
        $display("ERROR: Only ASCII PGM (P2) supported (got %s)", magic);
        $fclose(f_in);
        $finish;
    end

    skip = 0;
    while (!skip) begin
        scan_res = $fscanf(f_in, "%d %d", width, height);
        if (scan_res != 2) begin
            ch = $fgetc(f_in);
            if (ch == "#") while ($fgetc(f_in) != "\n") ;
        end else skip = 1;
    end

    skip = 0;
    while (!skip) begin
        scan_res = $fscanf(f_in, "%d", maxval);
        if (scan_res != 1) begin
            ch = $fgetc(f_in);
            if (ch == "#") while ($fgetc(f_in) != "\n") ;
        end else skip = 1;
    end

    OUT_MAX = width * height;
    if (OUT_MAX > 655360) begin
        $display("ERROR: image too large for testbench buffer (%0d pixels). Increase outbuf size.", OUT_MAX);
        $fclose(f_in);
        $finish;
    end

    for (i = 0; i < OUT_MAX; i = i + 1) outbuf[i] = 8'd0;
    out_cnt = 0;

    for (i = 0; i < height; i = i + 1) begin
        for (j = 0; j < width; j = j + 1) begin
            scan_res = $fscanf(f_in, "%d", pix);
            if (scan_res != 1) pix = 0;
            if (maxval != 0) pix = (pix * 255) / maxval;
            if (pix < 0) pix = 0;
            if (pix > 255) pix = 255;

            @(posedge clk);
            pixel_in <= pix[7:0];
            pixel_in_valid <= 1'b1;
            @(posedge clk);
            pixel_in_valid <= 1'b0;

            repeat (3) begin
                @(posedge clk);
                if (uut.pixel_out_valid) begin
                    r = uut.center_row_s1;
                    c = uut.center_col_s1;
                    if ((r >= 0) && (c >= 0) && (r < height) && (c < width)) begin
                        idx = r * width + c;
                        outbuf[idx] = uut.pixel_out;
                        out_cnt = out_cnt + 1;
                    end
                end
            end
        end
    end

    timeout_cnt = 0;
    while ((out_cnt < OUT_MAX) && (timeout_cnt < 200000)) begin
        @(posedge clk);
        if (uut.pixel_out_valid) begin
            r = uut.center_row_s1;
            c = uut.center_col_s1;
            if ((r >= 0) && (c >= 0) && (r < height) && (c < width)) begin
                idx = r * width + c;
                outbuf[idx] = uut.pixel_out;
                out_cnt = out_cnt + 1;
            end
        end
        timeout_cnt = timeout_cnt + 1;
    end
    if (out_cnt < OUT_MAX) $display("WARNING: captured %0d/%0d outputs", out_cnt, OUT_MAX);

    f_out = $fopen(outfile, "w");
    if (f_out == 0) begin
        $display("ERROR: Cannot open output file %s", outfile);
        $fclose(f_in);
        $finish;
    end
    $fdisplay(f_out, "P2");
    $fdisplay(f_out, "%0d %0d", width, height);
    $fdisplay(f_out, "255");
    for (i = 0; i < height; i = i + 1) begin
        for (j = 0; j < width; j = j + 1) begin
            $fwrite(f_out, "%0d ", outbuf[i*width + j]);
        end
        $fwrite(f_out, "\n");
    end

    $fclose(f_in);
    $fclose(f_out);
    $display("PGM processed: %0dx%0d -> %s  (captured %0d outputs)", width, height, outfile, out_cnt);
end
endtask

initial begin
    $dumpfile("tb_sobel_basic.vcd");
    $dumpvars(0, tb_sobel_basic);
end

integer dbg_cnt;
initial begin
    dbg_cnt = 0;
    $display(">>>>>>>>>>>>>>>>>>>>>>>>>>>Starting debug monitor: printing every 100 cycles (adjust as needed)");
end


always @(posedge clk) begin
    dbg_cnt = dbg_cnt + 1;
    if (dbg_cnt < 5000) begin
        $display("T=%0t in_v=%b in=%0d out_v=%b out=%0d col=%0d row=%0d top_r=%0d mid_r=%0d bot_r=%0d",
                 $time,
                 pixel_in_valid, pixel_in,
                 pixel_out_valid, pixel_out,
                 uut.col_ptr, uut.row_cnt,
                 uut.top_r, uut.mid_r, uut.bot_r);
    end
    if (dbg_cnt == 5000) $display("Debug monitor reached 5000 cycles; stop printing.");
end

endmodule