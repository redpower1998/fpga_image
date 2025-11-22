module rgb2hsv (
    input clk_Image_Process,
    input Rst,
    input [7:0]RGB_Data_R,
    input [7:0]RGB_Data_G,
    input [7:0]RGB_Data_B,
    output reg[8:0]HSV_H,
    output reg[7:0]HSV_S,
    output reg[7:0]HSV_V,
    output [2:0]Delay_Num
    );
    parameter RGB2HSV_Delay_Clk=4;
    reg [7:0]Reg_RGB_R=0;
    reg [7:0]Reg_RGB_G=0;
    reg [7:0]Reg_RGB_B=0;
    reg[7:0]Max_RGB_Data=0;
    reg[7:0]Min_RGB_Data=0;
    reg[14:0]HSV_Dividend_H=0;
    reg[7:0]HSV_Divisior_H=1;
    reg[15:0]HSV_Dividend_S=0;
    reg[7:0]HSV_Divisior_S=1;
    reg Sign_Flag=0;
    reg[7:0]HSV_Data_Tmp_V=0;
    reg[8:0]HSV_Data_Tmp_H=0;
    wire[31:0]Dividend_H;
    wire[31:0]Divisor_H;
    wire[31:0]Divider_Res_H;
    wire[31:0]Dividend_S;
    wire[31:0]Divisor_S;
    wire[31:0]Divider_Res_S;
    wire[14:0]Res_H;
    wire[16:0]Res_S;
    assign Dividend_H={17'b0,HSV_Dividend_H};
    assign Divisor_H={24'b0,HSV_Divisior_H};
    assign Divider_Res_H=Dividend_H/Divisor_H;
    assign Res_H=Divider_Res_H[14:0];
    assign Dividend_S={17'b0,HSV_Dividend_S};
    assign Divisor_S={24'b0,HSV_Divisior_S};
    assign Divider_Res_S=Dividend_S/Divisor_S;
    assign Res_S=Divider_Res_S[16:0];
    assign Delay_Num=RGB2HSV_Delay_Clk;
    always@(posedge clk_Image_Process or negedge Rst)
        begin
            if(!Rst)
                begin
                    HSV_H<=0;
                    HSV_S<=0;
                    HSV_V<=0;
                end
            else
                begin
                    if(Sign_Flag)
                        HSV_H<=HSV_Data_Tmp_H-Res_H;
                    else
                        HSV_H<=Res_H-HSV_Data_Tmp_H;
                    HSV_S<=Res_S;
                    HSV_V<=HSV_Data_Tmp_V;
                end
        end
    always@(posedge clk_Image_Process or negedge Rst)
        begin
            if(!Rst)
                begin
                    Reg_RGB_R<=0;
                    Reg_RGB_G<=0;
                    Reg_RGB_B<=0;
                end
            else
                begin
                    Reg_RGB_R<=RGB_Data_R;
                    Reg_RGB_G<=RGB_Data_G;
                    Reg_RGB_B<=RGB_Data_B;
                end
        end
    always@(posedge clk_Image_Process or negedge Rst)
        begin
            if(!Rst)
                begin
                    Max_RGB_Data<=0;
                    Min_RGB_Data<=0;
                end
            else
                begin
                    Max_RGB_Data<=MAX(RGB_Data_R,RGB_Data_G,RGB_Data_B);
                    Min_RGB_Data<=MIN(RGB_Data_R,RGB_Data_G,RGB_Data_B);
                end
        end
    always@(posedge clk_Image_Process or negedge Rst)
        begin
            if(!Rst)
                begin
                    HSV_Dividend_H<=0;
                    HSV_Divisior_H<=1;
                    HSV_Dividend_S<=0;
                    HSV_Divisior_S<=1;
                    HSV_Data_Tmp_V<=0;
                end
            else
                begin
                    
                    if(Max_RGB_Data==Min_RGB_Data)
                        begin
                            Sign_Flag<=0;                            
                            HSV_Dividend_H<=0;
                            HSV_Divisior_H<=1;
                            HSV_Dividend_S<=0;
                            HSV_Divisior_S<=1;
                            HSV_Data_Tmp_H<=0;
                            HSV_Data_Tmp_V<=Max_RGB_Data;
                        end
                     else if(Max_RGB_Data==Reg_RGB_R)
                        begin
                            HSV_Divisior_H<=Max_RGB_Data-Min_RGB_Data;
                            HSV_Dividend_S<=255*(Max_RGB_Data-Min_RGB_Data);
                            HSV_Divisior_S<=Max_RGB_Data;
                            HSV_Data_Tmp_V<=Max_RGB_Data;
                            if(Reg_RGB_G>=Reg_RGB_B)
                                begin
                                    Sign_Flag<=0; 
                                    HSV_Dividend_H<=60*(Reg_RGB_G-Reg_RGB_B);
                                    HSV_Data_Tmp_H<=0;
                                end
                            else
                                begin
                                    Sign_Flag<=1; 
                                    HSV_Dividend_H<=60*(Reg_RGB_B-Reg_RGB_G);
                                    HSV_Data_Tmp_H<=360;
                                end
                        end
                     else if(Max_RGB_Data==Reg_RGB_G)
                        begin
                            HSV_Divisior_H<=Max_RGB_Data-Min_RGB_Data;
                            HSV_Dividend_S<=255*(Max_RGB_Data-Min_RGB_Data);
                            HSV_Divisior_S<=Max_RGB_Data;
                            HSV_Data_Tmp_H<=120;
                            HSV_Data_Tmp_V<=Max_RGB_Data;
                            if(Reg_RGB_B>Reg_RGB_R)
                                begin
                                    Sign_Flag<=0;
                                    HSV_Dividend_H<=60*(Reg_RGB_B-Reg_RGB_R);
                                end
                            else
                                begin
                                    Sign_Flag<=1;
                                    HSV_Dividend_H<=60*(Reg_RGB_R-Reg_RGB_B);
                                end
                        end
                     else if(Max_RGB_Data==Reg_RGB_B)
                        begin
                            HSV_Divisior_H<=Max_RGB_Data-Min_RGB_Data;
                            HSV_Dividend_S<=255*(Max_RGB_Data-Min_RGB_Data);
                            HSV_Divisior_S<=Max_RGB_Data;
                            HSV_Data_Tmp_H<=240;
                            HSV_Data_Tmp_V<=Max_RGB_Data;
                            if(Reg_RGB_R>Reg_RGB_G)
                                begin
                                    Sign_Flag<=0;
                                    HSV_Dividend_H<=60*(Reg_RGB_R-Reg_RGB_G);
                                end
                            else
                                begin
                                    Sign_Flag<=1;
                                    HSV_Dividend_H<=60*(Reg_RGB_G-Reg_RGB_R);
                                end
                        end
                end
        end
    function [7:0]MAX;
        input [7:0]Data_A;
        input [7:0]Data_B;
        input [7:0]Data_C;
        reg [7:0]Max_AB;
        begin 
            Max_AB = Data_A>=Data_B?Data_A:Data_B;
            MAX = Max_AB>=Data_C?Max_AB:Data_C;
        end
    endfunction
    function [7:0]MIN;
        input [7:0]Data_A;
        input [7:0]Data_B;
        input [7:0]Data_C;
        reg [7:0]Min_AB;
        begin 
            Min_AB = Data_A <= Data_B ? Data_A : Data_B;
            MIN = Min_AB <= Data_C ? Min_AB : Data_C;
        end
    endfunction
endmodule