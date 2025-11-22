module canny_nms #(
    parameter IMAGE_WIDTH = 320
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        gray_valid,
    input  wire [7:0]  gray,
    output reg         nms_valid,
    output reg [11:0]  nms_mag,
    output reg [31:0]  center_row,
    output reg [31:0]  center_col
);

    localparam COL_W = (IMAGE_WIDTH>1) ? $clog2(IMAGE_WIDTH) : 1;

    reg [7:0] o_lb0 [0:IMAGE_WIDTH-1];
    reg [7:0] o_lb1 [0:IMAGE_WIDTH-1];

    reg [7:0] o00,o01,o02;
    reg [7:0] o10,o11,o12;
    reg [7:0] o20,o21,o22;

    reg [7:0] s00,s01,s02;
    reg [7:0] s10,s11,s12;
    reg [7:0] s20,s21,s22;

    reg [11:0] m_lb0 [0:IMAGE_WIDTH-1];
    reg [11:0] m_lb1 [0:IMAGE_WIDTH-1];

    reg [11:0] mm00,mm01,mm02;
    reg [11:0] mm10,mm11,mm12;
    reg [11:0] mm20,mm21,mm22;

    reg [COL_W-1:0] col_ptr;
    reg [31:0] row_cnt;

    reg [31:0] cen_r_s1, cen_c_s1;
    reg [31:0] cen_r_s2, cen_c_s2;
    reg [31:0] cen_r_s3, cen_c_s3;

    reg [1:0] dir_s2, dir_s3;

    reg signed [11:0] gx, gy;
    reg [11:0] abs_gx, abs_gy;
    reg [11:0] mag;

    reg [7:0] t_o0, t_o1;
    reg [11:0] t_m0, t_m1;

    integer i;
    integer idxL, idxC, idxR;

    reg [11:0] smooth;
    always @(posedge clk) begin
        if (rst) begin
            col_ptr <= 0;
            row_cnt <= 0;
            o00<=0;o01<=0;o02<=0; o10<=0;o11<=0;o12<=0; o20<=0;o21<=0;o22<=0;
            s00<=0;s01<=0;s02<=0; s10<=0;s11<=0;s12<=0; s20<=0;s21<=0;s22<=0;
            for (i=0;i<IMAGE_WIDTH;i=i+1) begin
                o_lb0[i] <= 0; o_lb1[i] <= 0;
                m_lb0[i] <= 0; m_lb1[i] <= 0;
            end
            cen_r_s1 <= 0; cen_c_s1 <= 0;
        end else begin
            if (gray_valid) begin
                t_o0 <= o_lb0[ col_ptr ];
                t_o1 <= o_lb1[ col_ptr ];

                o00 <= o01; o01 <= o02; o02 <= t_o1;
                o10 <= o11; o11 <= o12; o12 <= t_o0;
                o20 <= o21; o21 <= o22; o22 <= gray;

                o_lb1[col_ptr] <= o_lb0[col_ptr];
                o_lb0[col_ptr] <= gray;

                smooth <= ( o00 + (o01<<1) + o02
                           + (o10<<1) + (o11<<2) + (o12<<1)
                           + o20 + (o21<<1) + o22 ) >> 4;

                s00 <= s01; s01 <= s02; s02 <= t_o1;
                s10 <= s11; s11 <= s12; s12 <= t_o0;
                s20 <= s21; s21 <= s22; s22 <= smooth[7:0];

                if (col_ptr == 0) cen_c_s1 <= 0;
                else cen_c_s1 <= col_ptr - 1;
                cen_r_s1 <= row_cnt;

                if (col_ptr == IMAGE_WIDTH-1) begin
                    col_ptr <= 0;
                    row_cnt <= row_cnt + 1;
                end else col_ptr <= col_ptr + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            gx <= 0; gy <= 0; abs_gx <= 0; abs_gy <= 0; mag <= 0; dir_s2 <= 0;
            cen_r_s2 <= 0; cen_c_s2 <= 0;
        end else begin
            gx <= - $signed({4'd0,s00}) + $signed({4'd0,s02})
                  - ( $signed({4'd0,s10}) << 1 ) + ( $signed({4'd0,s12}) << 1 )
                  - $signed({4'd0,s20}) + $signed({4'd0,s22});

            gy <= - $signed({4'd0,s00}) - ( $signed({4'd0,s01}) << 1 ) - $signed({4'd0,s02})
                  + $signed({4'd0,s20}) + ( $signed({4'd0,s21}) << 1 ) + $signed({4'd0,s22});

            abs_gx <= (gx[11]) ? -gx : gx;
            abs_gy <= (gy[11]) ? -gy : gy;
            mag <= abs_gx + abs_gy;

            if (abs_gx >= abs_gy) begin
                if ((abs_gy << 1) >= abs_gx) dir_s2 <= 2'd1; else dir_s2 <= 2'd0;
            end else begin
                if ((abs_gx << 1) >= abs_gy) dir_s2 <= 2'd3; else dir_s2 <= 2'd2;
            end

            if (cen_c_s1 < IMAGE_WIDTH) begin
                m_lb1[ cen_c_s1 ] <= m_lb0[ cen_c_s1 ];
                m_lb0[ cen_c_s1 ] <= mag;
            end

            cen_r_s2 <= cen_r_s1;
            cen_c_s2 <= cen_c_s1;
            dir_s3  <= dir_s2;
        end
    end

    reg [31:0] cen_r_s2d, cen_c_s2d;
    always @(posedge clk) begin
        if (rst) begin
            cen_r_s2d <= 0; cen_c_s2d <= 0;
        end else begin
            cen_r_s2d <= cen_r_s2;
            cen_c_s2d <= cen_c_s2;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            mm00<=0;mm01<=0;mm02<=0;
            mm10<=0;mm11<=0;mm12<=0;
            mm20<=0;mm21<=0;mm22<=0;
            nms_valid <= 0;
            nms_mag <= 0;
            center_row <= 0; center_col <= 0;
            cen_r_s3 <= 0; cen_c_s3 <= 0;
        end else begin
            idxC = (cen_c_s2d < IMAGE_WIDTH) ? cen_c_s2d : 0;
            idxL = (idxC > 0) ? idxC - 1 : 0;
            idxR = (idxC + 1 < IMAGE_WIDTH) ? idxC + 1 : idxC;

            mm00 <= m_lb1[ idxL ]; mm01 <= m_lb1[ idxC ]; mm02 <= m_lb1[ idxR ];
            mm10 <= m_lb0[ idxL ]; mm11 <= m_lb0[ idxC ]; mm12 <= m_lb0[ idxR ];
            mm20 <= m_lb1[ idxL ]; mm21 <= m_lb1[ idxC ]; mm22 <= m_lb1[ idxR ];

            case (dir_s3)
                2'd0: begin
                    if ((mm11 >= mm10) && (mm11 >= mm12) && (mm11 != 12'd0)) nms_mag <= mm11; else nms_mag <= 12'd0;
                end
                2'd2: begin
                    if ((mm11 >= mm01) && (mm11 >= mm21) && (mm11 != 12'd0)) nms_mag <= mm11; else nms_mag <= 12'd0;
                end
                2'd1: begin
                    if ((mm11 >= mm02) && (mm11 >= mm20) && (mm11 != 12'd0)) nms_mag <= mm11; else nms_mag <= 12'd0;
                end
                2'd3: begin
                    if ((mm11 >= mm00) && (mm11 >= mm22) && (mm11 != 12'd0)) nms_mag <= mm11; else nms_mag <= 12'd0;
                end
                default: begin
                    if ((mm11 >= mm10) && (mm11 >= mm12) && (mm11 != 12'd0)) nms_mag <= mm11; else nms_mag <= 12'd0;
                end
            endcase

            cen_r_s3 <= cen_r_s2d;
            cen_c_s3 <= cen_c_s2d;

            if ((cen_r_s3 >= 1) && (cen_c_s3 >= 1)) begin
                nms_valid <= 1;
                center_row <= cen_r_s3;
                center_col <= cen_c_s3;
            end else begin
                nms_valid <= 0;
                center_row <= cen_r_s3;
                center_col <= cen_c_s3;
            end
        end
    end

endmodule