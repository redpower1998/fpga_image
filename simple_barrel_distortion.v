module simple_barrel_distortion #(
    parameter WIDTH = 320,
    parameter HEIGHT = 466,
    parameter DATA_WIDTH = 24,
    parameter DISTORTION_K1 = 8'h40
)(
    input wire clk,
    input wire rst_n,
    input wire [DATA_WIDTH-1:0] pixel_in,
    input wire pixel_valid,
    input wire frame_start,
    input wire frame_end,
    output reg [DATA_WIDTH-1:0] pixel_out,
    output reg pixel_out_valid,
    output reg frame_out_start,
    output reg frame_out_end
);

    localparam CENTER_X = WIDTH / 2;
    localparam CENTER_Y = HEIGHT / 2;
    
    reg [15:0] input_x, input_y;
    reg [15:0] output_x, output_y;
    reg frame_active;
    
    reg [DATA_WIDTH-1:0] frame_buffer [0:HEIGHT-1][0:WIDTH-1];
    
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam RECEIVE = 2'd1;
    localparam PROCESS = 2'd2;
    
    reg signed [31:0] dx, dy;
    reg signed [31:0] r_squared;
    reg signed [31:0] distortion_factor;
    reg signed [31:0] src_x, src_y;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_x <= 0;
            input_y <= 0;
            frame_active <= 0;
            state <= IDLE;
            output_x <= 0;
            output_y <= 0;
            
            for (i = 0; i < HEIGHT; i = i + 1) begin
                for (j = 0; j < WIDTH; j = j + 1) begin
                    frame_buffer[i][j] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (frame_start && pixel_valid) begin
                        state <= RECEIVE;
                        input_x <= 0;
                        input_y <= 0;
                        frame_active <= 1;
                    end
                end
                
                RECEIVE: begin
                    if (pixel_valid) begin
                        frame_buffer[input_y][input_x] <= pixel_in;
                        
                        if (input_x == WIDTH - 1) begin
                            input_x <= 0;
                            input_y <= input_y + 1;
                            
                            if (frame_end || input_y == HEIGHT - 1) begin
                                state <= PROCESS;
                                output_x <= 0;
                                output_y <= 0;
                            end
                        end else begin
                            input_x <= input_x + 1;
                        end
                        
                        if (frame_end) begin
                            state <= PROCESS;
                        end
                    end
                end
                
                PROCESS: begin
                    if (output_x == WIDTH - 1 && output_y == HEIGHT - 1) begin
                        state <= IDLE;
                        frame_active <= 0;
                    end
                end
            endcase
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 0;
            pixel_out_valid <= 0;
            frame_out_start <= 0;
            frame_out_end <= 0;
            output_x <= 0;
            output_y <= 0;
            dx <= 0;
            dy <= 0;
            r_squared <= 0;
            distortion_factor <= 0;
            src_x <= 0;
            src_y <= 0;
        end else begin
            case (state)
                IDLE: begin
                    pixel_out_valid <= 0;
                    frame_out_start <= 0;
                    frame_out_end <= 0;
                end
                
                RECEIVE: begin
                    pixel_out_valid <= 0;
                    frame_out_start <= 0;
                    frame_out_end <= 0;
                end
                
                PROCESS: begin
                    if (output_x == 0 && output_y == 0) begin
                        frame_out_start <= 1;
                    end else begin
                        frame_out_start <= 0;
                    end
                    
                    dx <= $signed(output_x) - $signed(CENTER_X);
                    dy <= $signed(output_y) - $signed(CENTER_Y);
                    
                    r_squared <= (dx * dx) + (dy * dy);
                    distortion_factor <= 65536 + (($signed(r_squared) * $signed(DISTORTION_K1)) >>> 4);
                    
                    src_x <= CENTER_X + (($signed(dx) * $signed(distortion_factor)) >>> 16);
                    src_y <= CENTER_Y + (($signed(dy) * $signed(distortion_factor)) >>> 16);
                    
                    if (src_x >= 0 && src_x < WIDTH && src_y >= 0 && src_y < HEIGHT) begin
                        pixel_out <= frame_buffer[src_y][src_x];
                    end else begin
                        pixel_out <= 24'h000000;
                    end
                    
                    pixel_out_valid <= 1;
                    
                    frame_out_end <= (output_x == WIDTH - 1 && output_y == HEIGHT - 1);
                    
                    if (output_x == WIDTH - 1) begin
                        output_x <= 0;
                        output_y <= output_y + 1;
                    end else begin
                        output_x <= output_x + 1;
                    end
                end
            endcase
        end
    end

endmodule