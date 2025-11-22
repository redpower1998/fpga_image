module Mirror(
	clk,
	rst_n,
	mode,
	in_enable,
	in_data,
	in_count_x,
	in_count_y,
	out_ready,
	out_data,
	out_count_x,
	out_count_y);

	parameter work_mode = 0;
	parameter data_width = 8;
	parameter im_width = 320;
	parameter im_height = 240;
	parameter im_width_bits = 9;

	input clk;
	input rst_n;
	input [1 : 0] mode;
	input in_enable;
	input [data_width - 1 : 0] in_data;
	input[im_width_bits - 1 : 0] in_count_x;
	input[im_width_bits - 1 : 0] in_count_y;
	output out_ready;
	output[data_width - 1 : 0] out_data;
	output[im_width_bits - 1 : 0] out_count_x;
	output[im_width_bits - 1 : 0] out_count_y;

	reg[im_width_bits - 1 : 0] reg_out_x, reg_out_y;
	reg[data_width - 1 : 0] reg_out_data;
	reg reg_out_ready;

	wire [im_width_bits - 1 : 0] mirror_x, mirror_y;
	
	assign mirror_x = (mode[0] == 1'b0) ? (im_width - 1 - in_count_x) : in_count_x;
	assign mirror_y = (mode[1] == 1'b0) ? (im_height - 1 - in_count_y) : in_count_y;

	generate
		if(work_mode == 0) begin
			always @(posedge clk or negedge rst_n or negedge in_enable) begin
				if(~rst_n || ~in_enable) begin
					reg_out_ready <= 0;
					reg_out_data <= 0;
					reg_out_x <= 0;
					reg_out_y <= 0;
				end else begin
					reg_out_ready <= 1;
					reg_out_data <= in_data;
					reg_out_x <= mirror_x;
					reg_out_y <= mirror_y;
				end
			end
		end else begin 
			reg in_enable_last;
			always @(posedge clk)
				in_enable_last <= in_enable;
				
			always @(posedge clk or negedge rst_n) begin
				if(~rst_n) begin
					reg_out_ready <= 0;
					reg_out_data <= 0;
					reg_out_x <= 0;
					reg_out_y <= 0;
					in_enable_last <= 0;
				end else begin
					if(~in_enable_last & in_enable) begin
						reg_out_ready <= 1;
						reg_out_data <= in_data;
						reg_out_x <= mirror_x;
						reg_out_y <= mirror_y;
					end else if(in_enable_last & ~in_enable) begin
						reg_out_ready <= 0;
					end
				end
			end
		end
	endgenerate

	assign out_ready = reg_out_ready;
	assign out_count_x = reg_out_x;
	assign out_count_y = reg_out_y;
	assign out_data = reg_out_data;

endmodule