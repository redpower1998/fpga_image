`timescale 1ns/1ps
module tb_sobel;

reg clk;
reg rst_n;
reg gray_valid;
reg [7:0] gray_data;
reg hsync;
reg vsync;
wire sobel_valid;
wire [7:0] sobel_data;

sobel u_sobel (
    .clk        (clk),
    .rst_n      (rst_n),
    .gray_valid (gray_valid),
    .gray_data  (gray_data),
    .hsync      (hsync),
    .vsync      (vsync),
    .sobel_valid(sobel_valid),
    .sobel_data (sobel_data)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    gray_valid = 1'b0;
    gray_data = 8'd0;
    hsync = 1'b1;
    vsync = 1'b1;
    #200;
    rst_n = 1'b1;
    #100;

    read_pgm_and_process(
        "data/gray1.pgm",
        "output/sobel_final_output.pgm"
    );

    #1000;
    $display("Simulation completed. Check sobel_final_output.pgm");
    $finish;
end

task read_pgm_and_process;
    input [80*8-1:0] pgm_in;
    input [80*8-1:0] pgm_out;
    integer f_in, f_out;
    integer width, height, max_val;
    integer i, j, gray_val, scan_res;
    reg [7:0] char;
    reg [15:0] magic;
    reg exit_loop, file_end;
begin
    f_in = $fopen(pgm_in, "r");
    if (f_in == 0) begin
        $display("ERROR: Cannot open input PGM %s", pgm_in);
        $finish;
    end

    exit_loop = 0;
    while (!exit_loop) begin
        scan_res = $fscanf(f_in, "%s", magic);
        if (scan_res == 0) begin
            char = $fgetc(f_in);
            if (char == "#") while ($fgetc(f_in) != "\n") ;
        end else exit_loop = 1;
    end
    if (magic != "P2") begin
        $display("ERROR: Only P2 PGM supported (got %s)", magic);
        $fclose(f_in);
        $finish;
    end

    exit_loop = 0;
    while (!exit_loop) begin
        scan_res = $fscanf(f_in, "%d %d", width, height);
        if (scan_res != 2) begin
            char = $fgetc(f_in);
            if (char == "#") while ($fgetc(f_in) != "\n") ;
        end else exit_loop = 1;
    end

    exit_loop = 0;
    while (!exit_loop) begin
        scan_res = $fscanf(f_in, "%d", max_val);
        if (scan_res != 1) begin
            char = $fgetc(f_in);
            if (char == "#") while ($fgetc(f_in) != "\n") ;
        end else exit_loop = 1;
    end

    f_out = $fopen(pgm_out, "w");
    $fdisplay(f_out, "P2");
    $fdisplay(f_out, "%d %d", width, height);
    $fdisplay(f_out, "255");

    vsync = 0;
    @(posedge clk);
    #10;
    vsync = 1;

    file_end = 0;
    for (i = 0; i < height && !file_end; i = i + 1) begin
        hsync = 1'b1;
        @(posedge clk);
        #10;
        hsync = 1'b0;
        @(posedge clk);
        #10;

        gray_valid = 1'b1;
        for (j = 0; j < width && !file_end; j = j + 1) begin
            scan_res = $fscanf(f_in, "%d", gray_val);
            if (scan_res != 1) begin
                $display("WARNING: End of file at (%d,%d)", i, j);
                file_end = 1;
                gray_val = 0;
            end else begin
                gray_val = (gray_val * 255) / max_val;
                if (gray_val < 0) gray_val = 0;
                if (gray_val > 255) gray_val = 255;
            end

            @(posedge clk);
            gray_data = gray_val[7:0];
            #10;

            repeat(3) @(posedge clk);
            if (sobel_valid && !file_end) begin
                $fwrite(f_out, "%d ", sobel_data);
                if (j % 50 == 0) begin
                    $display("Pixel (%d,%d): Gray=%3d  Edge=%3d", i, j, gray_data, sobel_data);
                end
            end else if (!file_end) begin
                $fwrite(f_out, "0 ");
            end
        end
        gray_valid = 1'b0;
        $fwrite(f_out, "\n");
    end

    $fclose(f_in);
    $fclose(f_out);
    $display("Processed %d x %d pixels. Output saved to %s", width, height, pgm_out);
end
endtask

initial begin
    $dumpfile("tb_sobel_final.vcd");
    $dumpvars(0, tb_sobel);
end

endmodule