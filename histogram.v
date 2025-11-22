module histogram #(
    parameter DATA_WIDTH = 8,
    parameter HIST_BINS = 256,
    parameter HIST_WIDTH = 18
)(
    input clk,
    input rst_n,
    
    input data_valid,
    input [DATA_WIDTH-1:0] pixel_data,
    input clear_hist,
    input enable_hist,
    
    output reg hist_ready,
    output reg [HIST_WIDTH-1:0] hist_value,
    output reg [DATA_WIDTH-1:0] hist_bin,
    output reg hist_valid,
    output reg [1:0] state_out
);

reg [HIST_WIDTH-1:0] hist_memory [0:HIST_BINS-1];
reg [DATA_WIDTH-1:0] current_bin;
reg [1:0] state;
reg enable_hist_r1;
reg counting_complete;

localparam IDLE = 2'b00;
localparam COUNTING = 2'b01;
localparam OUTPUT = 2'b10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        enable_hist_r1 <= 1'b0;
    end else begin
        enable_hist_r1 <= enable_hist;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hist_ready <= 1'b1;
    end else begin
        case (state)
            IDLE: begin
                hist_ready <= 1'b1;
            end
            COUNTING: begin
                hist_ready <= 1'b0;
            end
            OUTPUT: begin
                hist_ready <= counting_complete;
            end
            default: begin
                hist_ready <= 1'b1;
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer i = 0; i < HIST_BINS; i = i + 1) begin
            hist_memory[i] <= {HIST_WIDTH{1'b0}};
        end
    end else if (clear_hist) begin
        for (integer i = 0; i < HIST_BINS; i = i + 1) begin
            hist_memory[i] <= {HIST_WIDTH{1'b0}};
        end
    end else if (data_valid && enable_hist && state == COUNTING) begin
        if (pixel_data < HIST_BINS) begin
            hist_memory[pixel_data] <= hist_memory[pixel_data] + 1'b1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        state_out <= IDLE;
        current_bin <= {DATA_WIDTH{1'b0}};
        hist_value <= {HIST_WIDTH{1'b0}};
        hist_bin <= {DATA_WIDTH{1'b0}};
        hist_valid <= 1'b0;
        counting_complete <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                hist_valid <= 1'b0;
                counting_complete <= 1'b0;
                state_out <= IDLE;
                
                if (enable_hist) begin
                    state <= COUNTING;
                    state_out <= COUNTING;
                end
            end
            
            COUNTING: begin
                state_out <= COUNTING;
                
                if (!enable_hist) begin
                    current_bin <= {DATA_WIDTH{1'b0}};
                    counting_complete <= 1'b1;
                    state <= OUTPUT;
                    state_out <= OUTPUT;
                end
            end
            
            OUTPUT: begin
                state_out <= OUTPUT;
                
                hist_valid <= 1'b1;
                hist_bin <= current_bin;
                hist_value <= hist_memory[current_bin];
                
                if (current_bin < HIST_BINS - 1) begin
                    current_bin <= current_bin + 1'b1;
                end else begin
                    hist_valid <= 1'b0;
                    counting_complete <= 1'b0;
                    state <= IDLE;
                    state_out <= IDLE;
                end
            end
            
            default: begin
                state <= IDLE;
                state_out <= IDLE;
            end
        endcase
    end
end

endmodule