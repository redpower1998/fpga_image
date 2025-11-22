module histogram_rgb #(
    parameter DATA_WIDTH = 8,
    parameter HIST_BINS = 256,
    parameter HIST_WIDTH = 18
) (
    input wire clk,
    input wire rst_n,
    
    input wire data_valid,
    input wire [DATA_WIDTH-1:0] r_data,
    input wire [DATA_WIDTH-1:0] g_data,
    input wire [DATA_WIDTH-1:0] b_data,
    
    input wire clear_hist,
    input wire enable_hist,
    
    output wire hist_ready,
    output wire [HIST_WIDTH-1:0] r_hist_value,
    output wire [HIST_WIDTH-1:0] g_hist_value,
    output wire [HIST_WIDTH-1:0] b_hist_value,
    output wire [DATA_WIDTH-1:0] hist_bin,
    output wire hist_valid,
    output wire [1:0] channel_sel
);

    reg [HIST_WIDTH-1:0] r_hist_mem [0:HIST_BINS-1];
    reg [HIST_WIDTH-1:0] g_hist_mem [0:HIST_BINS-1];
    reg [HIST_WIDTH-1:0] b_hist_mem [0:HIST_BINS-1];
    
    reg [DATA_WIDTH-1:0] current_bin;
    reg [1:0] current_channel;
    reg output_active;
    reg counting_active;
    
    integer i;
    
    initial begin
        for (i = 0; i < HIST_BINS; i = i + 1) begin
            r_hist_mem[i] = {HIST_WIDTH{1'b0}};
            g_hist_mem[i] = {HIST_WIDTH{1'b0}};
            b_hist_mem[i] = {HIST_WIDTH{1'b0}};
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < HIST_BINS; i = i + 1) begin
                r_hist_mem[i] <= {HIST_WIDTH{1'b0}};
                g_hist_mem[i] <= {HIST_WIDTH{1'b0}};
                b_hist_mem[i] <= {HIST_WIDTH{1'b0}};
            end
            counting_active <= 1'b0;
        end else if (clear_hist) begin
            for (i = 0; i < HIST_BINS; i = i + 1) begin
                r_hist_mem[i] <= {HIST_WIDTH{1'b0}};
                g_hist_mem[i] <= {HIST_WIDTH{1'b0}};
                b_hist_mem[i] <= {HIST_WIDTH{1'b0}};
            end
            counting_active <= 1'b0;
        end else if (enable_hist && data_valid) begin
            counting_active <= 1'b1;
            r_hist_mem[r_data] <= r_hist_mem[r_data] + 1'b1;
            g_hist_mem[g_data] <= g_hist_mem[g_data] + 1'b1;
            b_hist_mem[b_data] <= b_hist_mem[b_data] + 1'b1;
        end else if (!enable_hist && counting_active) begin
            counting_active <= 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_channel <= 2'b00;
            current_bin <= {DATA_WIDTH{1'b0}};
            output_active <= 1'b0;
        end else if (clear_hist) begin
            current_channel <= 2'b00;
            current_bin <= {DATA_WIDTH{1'b0}};
            output_active <= 1'b0;
        end else begin
            if (!enable_hist && !counting_active && !output_active) begin
                output_active <= 1'b1;
                current_channel <= 2'b00;
                current_bin <= {DATA_WIDTH{1'b0}};
            end
            
            if (output_active) begin
                if (current_bin < HIST_BINS - 1) begin
                    current_bin <= current_bin + 1'b1;
                end else begin
                    current_bin <= {DATA_WIDTH{1'b0}};
                    case (current_channel)
                        2'b00: current_channel <= 2'b01;
                        2'b01: current_channel <= 2'b10;
                        2'b10: begin
                            current_channel <= 2'b00;
                            output_active <= 1'b0;
                        end
                        default: current_channel <= 2'b00;
                    endcase
                end
            end
        end
    end
    
    assign hist_ready = !output_active && !counting_active && !enable_hist;
    assign hist_valid = output_active;
    assign channel_sel = current_channel;
    assign hist_bin = current_bin;
    
    assign r_hist_value = r_hist_mem[current_bin];
    assign g_hist_value = g_hist_mem[current_bin];
    assign b_hist_value = b_hist_mem[current_bin];
    
endmodule