`timescale 1ns / 1ps
module tb_median7x7;

    parameter TCLK = 10;
    localparam IMAGE_WIDTH = 320;
    localparam OUTBUF_SIZE = 2000000;

    reg clk = 0;
    reg rst = 1;

    reg [7:0] gray_in = 0;
    reg       gray_valid = 0;

    wire       median_valid;
    wire [7:0] median_out;

    median7x7 #(.IMAGE_WIDTH(IMAGE_WIDTH)) dut (
        .clk(clk),
        .rst(rst),
        .gray_valid(gray_valid),
        .gray(gray_in),
        .median_valid(median_valid),
        .median_out(median_out),
        .center_row_s1(), 
        .center_col_s1()
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
    reg [7:0] outbuf [0:OUTBUF_SIZE-1];
    reg got [0:OUTBUF_SIZE-1];
    integer out_cnt;
    integer idx;
    integer center_r, center_c;
    integer timeout;
    integer tmp;
    integer waitk;

    initial begin
        f_in = $fopen("data/gray1.pgm", "r");
        if (f_in == 0) begin $display("ERROR: cannot open input gray1.pgm"); $finish; end

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
        for (i = 0; i < OUT_MAX; i = i + 1) begin outbuf[i] = 8'd0; got[i] = 1'b0; end
        out_cnt = 0;

        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                scanned = $fscanf(f_in, "%d", r_val);
                if (scanned != 1) r_val = 0;
                if (maxv != 0) r_val = (r_val * 255) / maxv;
                if (r_val < 0) r_val = 0;
                if (r_val > 255) r_val = 255;

                idx = i * width + j;
                outbuf[idx] = r_val[7:0];
                got[idx] = 1'b0;

                gray_in = r_val[7:0];
                gray_valid = 1'b1;
                @(posedge clk);
                gray_valid = 1'b0;

                waitk = 0;
                repeat (6) begin
                    @(posedge clk);
                    if (median_valid) begin
                        center_r = dut.center_row_s1;
                        center_c = dut.center_col_s1;
                        if ((center_r >= 0) && (center_c >= 0) && (center_r < height) && (center_c < width)) begin
                            idx = center_r * width + center_c;
                            if (!got[idx]) begin
                                outbuf[idx] = median_out;
                                got[idx] = 1'b1;
                                out_cnt = out_cnt + 1;
                            end
                        end
                    end
                end
            end
        end

        timeout = 0;
        while ((out_cnt < OUT_MAX) && (timeout < 300000)) begin
            @(posedge clk);
            if (median_valid) begin
                center_r = dut.center_row_s1;
                center_c = dut.center_col_s1;
                if ((center_r >= 0) && (center_c >= 0) && (center_r < height) && (center_c < width)) begin
                    idx = center_r * width + center_c;
                    if (!got[idx]) begin
                        outbuf[idx] = median_out;
                        got[idx] = 1'b1;
                        out_cnt = out_cnt + 1;
                    end
                end
            end
            timeout = timeout + 1;
        end

        if (out_cnt < OUT_MAX) $display("WARNING: captured %0d/%0d outputs", out_cnt, OUT_MAX);

        f_out = $fopen("output/out_median7x7.pgm", "w");
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
        $fclose(f_out); $fclose(f_in);

        $display("Done. wrote out_median7x7.pgm captured=%0d expected=%0d", out_cnt, OUT_MAX);
        #1000; $finish;
    end

    initial begin
        $dumpfile("tb_median7x7.vcd");
        $dumpvars(0, tb_median7x7.dut, tb_median7x7.clk, tb_median7x7.rst);
    end

endmodule