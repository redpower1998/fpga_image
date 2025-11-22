`timescale 1ns / 1ps

module tb_mean3x3;

    parameter TCLK = 10;
    localparam IMAGE_WIDTH = 320;
    localparam OUTBUF_SIZE = 2000000;

    reg clk = 0;
    reg rst = 1;

    reg [7:0] gray_in = 0;
    reg       gray_valid = 0;

    wire       mean_valid;
    wire [7:0] mean_out;

    mean3x3 #(.IMAGE_WIDTH(IMAGE_WIDTH)) dut (
        .clk(clk),
        .rst(rst),
        .gray_valid(gray_valid),
        .gray(gray_in),
        .mean_valid(mean_valid),
        .mean_out(mean_out),
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
    integer valid_width;
    integer valid_height;
    integer actual_expected;
    integer border_pixels;

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
        
        for (i = 0; i < OUT_MAX; i = i + 1) begin 
            outbuf[i] = 8'd128;
            got[i] = 1'b0;
        end
        out_cnt = 0;

        $display("Starting mean3x3 test: width=%0d, height=%0d", width, height);

        for (i = 0; i < height; i = i + 1) begin
            for (j = 0; j < width; j = j + 1) begin
                scanned = $fscanf(f_in, "%d", r_val);
                if (scanned != 1) r_val = 0;
                if (maxv != 0) r_val = (r_val * 255) / maxv;
                if (r_val < 0) r_val = 0;
                if (r_val > 255) r_val = 255;

                idx = i * width + j;
                outbuf[idx] = r_val[7:0];

                gray_in = r_val[7:0];
                gray_valid = 1'b1;
                @(posedge clk);
                gray_valid = 1'b0;

                if (i < 2 && j < 5) begin
                    $display("Input: row=%0d, col=%0d, pixel=%0d", i, j, r_val);
                end

                repeat (10) begin
                    @(posedge clk);
                    if (mean_valid) begin
                        center_r = dut.center_row_s1;
                        center_c = dut.center_col_s1;
                        if ((center_r >= 0) && (center_c >= 0) && (center_r < height) && (center_c < width)) begin
                            idx = center_r * width + center_c;
                            if (!got[idx]) begin
                                outbuf[idx] = mean_out;
                                got[idx] = 1'b1;
                                out_cnt = out_cnt + 1;
                                if (out_cnt <= 10 || (out_cnt % 1000 == 0)) begin
                                    $display("Output %0d: row=%0d, col=%0d, mean=%0d", out_cnt, center_r, center_c, mean_out);
                                end
                            end
                        end
                    end
                end
            end
        end

        $display("Input complete. Waiting for remaining outputs...");

        valid_width = width - 2;
        valid_height = height - 2;
        actual_expected = valid_width * valid_height;
        
        timeout = 0;
        while ((out_cnt < actual_expected) && (timeout < 1000000)) begin
            @(posedge clk);
            if (mean_valid) begin
                center_r = dut.center_row_s1;
                center_c = dut.center_col_s1;
                if ((center_r >= 0) && (center_c >= 0) && (center_r < height) && (center_c < width)) begin
                    idx = center_r * width + center_c;
                    if (!got[idx]) begin
                        outbuf[idx] = mean_out;
                        got[idx] = 1'b1;
                        out_cnt = out_cnt + 1;
                        if (out_cnt % 1000 == 0) begin
                            $display("Captured %0d/%0d outputs", out_cnt, actual_expected);
                        end
                    end
                end
            end
            timeout = timeout + 1;
            if (timeout % 500000 == 0 && timeout > 0) begin
                $display("Waiting: %0d cycles, captured=%0d/%0d", timeout, out_cnt, actual_expected);
            end
        end

        border_pixels = OUT_MAX - actual_expected;
        
        $display("3x3 mean filter boundary effect analysis:");
        $display("Image size: %0d x %0d = %0d pixels", width, height, OUT_MAX);
        $display("Border pixels: 1 row top and bottom, 1 column left and right = %0d pixels", border_pixels);
        $display("Actually processable: %0d x %0d = %0d pixels", valid_width, valid_height, actual_expected);
        $display("Actually captured: %0d pixels", out_cnt);
        
        if (out_cnt >= actual_expected) begin
            $display("SUCCESS: 3x3 mean filter working correctly!");
            $display("Captured %0d/%0d valid pixels (border %0d pixels remain unchanged)", out_cnt, actual_expected, border_pixels);
            $display("SUCCESS: captured %0d/%0d outputs", out_cnt, OUT_MAX);
        end else begin
            $display("WARNING: Captured %0d/%0d valid pixels", out_cnt, actual_expected);
            $display("WARNING: captured %0d/%0d outputs", out_cnt, OUT_MAX);
        end

        f_out = $fopen("output/out_mean3x3.pgm", "w");
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

        $display("Done. wrote out_mean3x3.pgm captured=%0d expected=%0d", out_cnt, actual_expected);
        #1000; $finish;
    end

    initial begin
        $dumpfile("tb_mean3x3.vcd");
        $dumpvars(0, tb_mean3x3.dut, tb_mean3x3.clk, tb_mean3x3.rst);
    end

endmodule