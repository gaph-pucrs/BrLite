module BrLiteNoC
	import BrLitePkg::*;
#(
	parameter X_CNT = 3,
	parameter Y_CNT = 3
)
(
	input  logic 	 				 clk_i,
	input  logic 	 				 rst_ni,

	input  logic 	 [31:0]			 tick_cnt_i,

	input  br_data_t [X_CNT * Y_CNT - 1:0] flit_i,
	input  logic	 [X_CNT * Y_CNT - 1:0] req_i,
	output logic	 [X_CNT * Y_CNT - 1:0] ack_o,

	output br_data_t [X_CNT * Y_CNT - 1:0] flit_o,
	output logic	 [X_CNT * Y_CNT - 1:0] req_o,
	input  logic	 [X_CNT * Y_CNT - 1:0] ack_i,
	output logic	 [X_CNT * Y_CNT - 1:0] busy_o
);
	localparam PE_CNT = X_CNT * Y_CNT;
	br_data_t	[PE_CNT - 1:0][NPORT - 1:0] flit_i_sig;
	logic		[PE_CNT - 1:0][NPORT - 1:0] req_i_sig;
	logic		[PE_CNT - 1:0][NPORT - 1:0] ack_o_sig;
	br_data_t 	[PE_CNT - 1:0][NPORT - 1:0] flit_o_sig;
	logic		[PE_CNT - 1:0][NPORT - 1:0] req_o_sig;
	logic		[PE_CNT - 1:0][NPORT - 1:0] ack_i_sig;

	genvar gen_x, gen_y;
	generate
		for(gen_x = 0; gen_x < X_CNT; gen_x++) begin
			for(gen_y = 0; gen_y < Y_CNT; gen_y++) begin
				int index = gen_x*Y_CNT + gen_y;
				BrLiteRouter #(.ADDRESS(gen_x << 8 | gen_y))
				Router
				(
					.clk_i(clk_i),
					.rst_ni(rst_ni),
					.tick_cnt_i(tick_cnt_i),
					.local_busy_o(busy_o[index]),
					.flit_i(flit_i_sig[index]),
					.req_i(req_i_sig[index]),
					.ack_o(ack_o_sig[index]),
					.flit_o(flit_o_sig[index]),
					.req_o(req_o_sig[index]),
					.ack_i(ack_i_sig[index])
				);
			end
		end
	endgenerate

	always_comb begin
		for(int x = 0; x < X_CNT; x++) begin
			for(int y = 0; y < Y_CNT; y++) begin
				int index = x*Y_CNT + y;

				if(x != X_CNT - 1) begin
					flit_i_sig[index][EAST] = flit_o_sig[index + Y_CNT][WEST];
					req_i_sig[index][EAST] = req_o_sig[index + Y_CNT][WEST];
					ack_i_sig[index][EAST] = ack_o_sig[index + Y_CNT][WEST];
				end else begin
					flit_i_sig[index][EAST] = '0;
					req_i_sig[index][EAST] = '0;
					ack_i_sig[index][EAST] = '1;
				end

				if(x != 0) begin
					flit_i_sig[index][WEST] = flit_o_sig[index - Y_CNT][EAST];
					req_i_sig[index][WEST] = req_o_sig[index - Y_CNT][EAST];
					ack_i_sig[index][WEST] = ack_o_sig[index - Y_CNT][EAST];
				end else begin
					flit_i_sig[index][WEST] = '0;
					req_i_sig[index][WEST] = '0;
					ack_i_sig[index][WEST] = '1;
				end

				if(y != Y_CNT - 1) begin
					flit_i_sig[index][NORTH] = flit_o_sig[index + 1][SOUTH];
					req_i_sig[index][NORTH] = req_o_sig[index + 1][SOUTH];
					ack_i_sig[index][NORTH] = ack_o_sig[index + 1][SOUTH];
				end else begin
					flit_i_sig[index][NORTH] = '0;
					req_i_sig[index][NORTH] = '0;
					ack_i_sig[index][NORTH] = '1;
				end

				if(y != 0) begin
					flit_i_sig[index][SOUTH] = flit_o_sig[index - 1][NORTH];
					req_i_sig[index][SOUTH] = req_o_sig[index - 1][NORTH];
					ack_i_sig[index][SOUTH] = ack_o_sig[index - 1][NORTH];
				end else begin
					flit_i_sig[index][SOUTH] = '0;
					req_i_sig[index][SOUTH] = '0;
					ack_i_sig[index][SOUTH] = '1;
				end

				flit_i_sig[index][LOCAL] = flit_i[index];
				req_i_sig[index][LOCAL] = req_i[index];
				ack_o[index] = ack_o_sig[index][LOCAL];
				flit_o[index] = flit_o_sig[index][LOCAL];
				req_o[index] = req_o_sig[index][LOCAL];
				ack_i_sig[index][LOCAL] = ack_i[index];
			end
		end
	end
	
endmodule
