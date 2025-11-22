`timescale 1ns / 1ps
module tb_census3x3;

    parameter TCLK = 10;
    localparam IMAGE_WIDTH = 320;
    localparam OUTBUF_SIZE = 2000000;

    reg clk = 0;
    reg rst = 1;

    reg [7:0] gray_in = 0;
    reg       gray_valid = 0;

    wire       census_valid;
    wire [15:0] census_out;

    census3x3 #(.IMAGE_WIDTH(IMAGE_WIDTH)) census_inst (
        .clk        (clk),
        .rst        (rst),
        .gray_valid (gray_valid),
        .gray       (gray_in),
        .census_valid(census_valid),
        .census_out (census_out)
    );

    initial forever #(TCLK/2) clk = ~clk;

    initial begin
        rst = 1;
        # (10 * TCLK);
        rst = 0;
    end

    integer f_in, f_out;
    integer i, j;
    integer scanned;
    integer width, height, maxv;
    reg [8*16-1:0] magic;
    integer r_val;
    integer OUT_MAX;
    reg [15:0] outbuf [0:OUTBUF_SIZE-1];
    reg got [0:OUTBUF_SIZE-1];
    integer out_cnt;
    integer idx;
    integer center_r, center_c;
    integer timeout;
    integer tmp;

    integer k;
    reg [3:0] pop;
    integer rr, gg, bb;

    initial begin
        f_in = $fopen("data/gray1.pgm", "r");
        if (f_in == 0) begin
            $display("ERROR: cannot open input file gray1.pgm");
            $finish;
        end

        scanned = $fscanf(f_in, "%s", magic);
        if ((scanned != 1) || (magic != "P2")) begin
            $display("ERROR: unsupported PGM format (need P2 ASCII). got=%s", magic);
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

        if (width != IMAGE_WIDTH) begin
            $display("ERROR: PGM width (%0d) != IMAGE_WIDTH parameter (%0d). Edit tb to match.", width, IMAGE_WIDTH);
            $finish;
        end

        OUT_MAX = width * height;
        if (OUT_MAX > OUTBUF_SIZE) begin
            $display("ERROR: increase OUTBUF_SIZE (%0d required)", OUT_MAX);
            $finish;
        end
        for (i = 0; i < OUT_MAX; i = i + 1) begin
            outbuf[i] = 16'd0;
            got[i] = 1'b0;
        end
        out_cnt = 0;

        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                scanned = $fscanf(f_in, "%d", r_val);
                if (scanned != 1) r_val = 0;
                if (maxv != 0) r_val = (r_val * 255) / maxv;
                if (r_val < 0) r_val = 0;
                if (r_val > 255) r_val = 255;

                gray_in = r_val[7:0];
                gray_valid = 1'b1;
                @(posedge clk);
                gray_valid = 1'b0;

                repeat (3) begin
                    @(posedge clk);
                    if (census_valid) begin
                        center_r = census_inst.center_row_s1;
                        center_c = census_inst.center_col_s1;
                        if ((center_r >= 0) && (center_c >= 0) && (center_r < height) && (center_c < width)) begin
                            idx = center_r * width + center_c;
                            if (!got[idx]) begin
                                pop = 0;
                                for (k = 0; k < 8; k = k + 1) begin
                                    pop = pop + census_out[k];
                                end
                                outbuf[idx] = pop * 16'd8191;
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
            if (census_valid) begin
                center_r = census_inst.center_row_s1;
                center_c = census_inst.center_col_s1;
                if ((center_r >= 0) && (center_c >= 0) && (center_r < height) && (center_c < width)) begin
                    idx = center_r * width + center_c;
                    if (!got[idx]) begin
                        outbuf[idx] = census_out;
                        got[idx] = 1'b1;
                        out_cnt = out_cnt + 1;
                    end
                end
            end
            timeout = timeout + 1;
        end

        if (out_cnt < OUT_MAX) $display("WARNING: captured %0d/%0d outputs", out_cnt, OUT_MAX);

        f_out = $fopen("output/out_census1.pgm", "w");
        if (f_out == 0) begin $display("ERROR: cannot open output file"); $finish; end
        $fdisplay(f_out, "P2");
        $fdisplay(f_out, "%0d %0d", width, height);
        $fdisplay(f_out, "65535");
        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                $fwrite(f_out, "%0d ", outbuf[i*width + j]);
            end
            $fwrite(f_out, "\n");
        end
        $fclose(f_out);
        $fclose(f_in);

        $display("Done. wrote out_census1.pgm captured=%0d expected=%0d", out_cnt, OUT_MAX);
        #1000;
        $finish;
    end

    initial begin
        $dumpfile("tb_census3x3.vcd");
        $dumpvars(0, tb_census3x3.census_inst, tb_census3x3.clk, tb_census3x3.rst);
    end

endmodule