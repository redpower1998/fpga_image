module hsv2rgb (
    input clk_Image_Process,
    input Rst,
    input [8:0]HSV_Data_H,
    input [7:0]HSV_Data_S,
    input [7:0]HSV_Data_V,
    output [7:0]RGB_Data_R,
    output [7:0]RGB_Data_G,
    output [7:0]RGB_Data_B,
    output [2:0]Delay_Num
    );
    parameter HSV2RGB_Delay_Clk=2;

    wire [7:0]RGB_Max_Data=HSV_Data_V;
    wire [15:0]RGB_Tmp_Data=RGB_Max_Data*(255-HSV_Data_S);
    wire [7:0]RGB_Min_Data=RGB_Tmp_Data[15:8];
    wire [7:0]RGB_Delta_Data=RGB_Max_Data-RGB_Min_Data;
    wire [5:0]Data_H_Mod=HSV_Data_H%60;
    wire [13:0]RGB_Adjust_Tmp=RGB_Delta_Data*Data_H_Mod;
    wire [7:0]RGB_Adjust=RGB_Adjust_Tmp/60;
    
    reg [15:0]RGB_R=0;
    reg [15:0]RGB_G=0;
    reg [15:0]RGB_B=0;
    assign Delay_Num=HSV2RGB_Delay_Clk;
    assign RGB_Data_R=RGB_R[15:8];
    assign RGB_Data_G=RGB_G[15:8];
    assign RGB_Data_B=RGB_B[15:8];
    always@(posedge clk_Image_Process or negedge Rst)
        begin
            if(!Rst)
                begin
                    RGB_R<=0;
                    RGB_G<=0;
                    RGB_B<=0;
                end
            else
                begin
                    if(HSV_Data_H<60)
                        begin
                            RGB_R<={RGB_R[7:0],RGB_Max_Data};
                            RGB_G<={RGB_G[7:0],RGB_Min_Data+RGB_Adjust};
                            RGB_B<={RGB_B[7:0],RGB_Min_Data};
                        end
                    else if(HSV_Data_H<120)
                        begin
                            RGB_R<={RGB_R[7:0],RGB_Max_Data-RGB_Adjust};
                            RGB_G<={RGB_G[7:0],RGB_Max_Data};
                            RGB_B<={RGB_B[7:0],RGB_Min_Data};
                        end
                    else if(HSV_Data_H<180)
                        begin
                            RGB_R<={RGB_R[7:0],RGB_Min_Data};
                            RGB_G<={RGB_G[7:0],RGB_Max_Data};
                            RGB_B<={RGB_B[7:0],RGB_Min_Data+RGB_Adjust};
                        end
                    else if(HSV_Data_H<240)
                        begin
                            RGB_R<={RGB_R[7:0],RGB_Min_Data};
                            RGB_G<={RGB_G[7:0],RGB_Max_Data-RGB_Adjust};
                            RGB_B<={RGB_B[7:0],RGB_Max_Data};
                        end
                    else if(HSV_Data_H<300)
                        begin
                            RGB_R<={RGB_R[7:0],RGB_Min_Data+RGB_Adjust};
                            RGB_G<={RGB_G[7:0],RGB_Min_Data};
                            RGB_B<={RGB_B[7:0],RGB_Max_Data};
                        end
                    else
                        begin
                            RGB_R<={RGB_R[7:0],RGB_Max_Data};
                            RGB_G<={RGB_G[7:0],RGB_Min_Data};
                            RGB_B<={RGB_B[7:0],RGB_Max_Data-RGB_Adjust};
                        end
                end
        end
endmodule