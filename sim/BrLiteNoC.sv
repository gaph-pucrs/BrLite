module BrLiteNoC
	import BrLitePkg::*;
#(
	parameter X_CNT = 3,
	parameter Y_CNT = 3
)
(
	input  logic 	 				 clk_i,
	input  logic 	 				 rst_ni,

	input  logic 	 [63:0]			 tick_cnt_i,

	input  br_data_t [X_CNT * Y_CNT - 1:0] flit_i,
	input  logic	 [X_CNT * Y_CNT - 1:0] req_i,
	output logic	 [X_CNT * Y_CNT - 1:0] ack_o,

	output br_data_t [X_CNT * Y_CNT - 1:0] flit_o,
	output logic	 [X_CNT * Y_CNT - 1:0] req_o,
	input  logic	 [X_CNT * Y_CNT - 1:0] ack_i,
	output logic	 [X_CNT * Y_CNT - 1:0] busy_o
);
	localparam PE_CNT = X_CNT * Y_CNT;
	br_data_t	[NPORT - 1:0] flit_i_sig [PE_CNT - 1:0];
	logic		[NPORT - 1:0] req_i_sig  [PE_CNT - 1:0];
	logic		[NPORT - 1:0] ack_o_sig  [PE_CNT - 1:0];
	br_data_t 	[NPORT - 1:0] flit_o_sig [PE_CNT - 1:0];
	logic		[NPORT - 1:0] req_o_sig  [PE_CNT - 1:0];
	logic		[NPORT - 1:0] ack_i_sig  [PE_CNT - 1:0];

	genvar gen_x, gen_y;
	generate
		for (gen_x = 0; gen_x < X_CNT; gen_x++) begin
			for (gen_y = 0; gen_y < Y_CNT; gen_y++) begin
				localparam index = gen_y*X_CNT + gen_x;
				BrLiteRouter #(.SEQ_ADDRESS(index))
				Router
				(
					.clk_i			(clk_i),
					.rst_ni			(rst_ni),
					.tick_cnt_i		(tick_cnt_i),
					.local_busy_o	(busy_o[index]),
					.flit_i			(flit_i_sig[index]),
					.req_i			(req_i_sig[index]),
					.ack_o			(ack_o_sig[index]),
					.flit_o			(flit_o_sig[index]),
					.req_o			(req_o_sig[index]),
					.ack_i			(ack_i_sig[index])
				);
			end
		end
	endgenerate

	always_comb begin
		for (int x = 0; x < X_CNT; x++) begin
			for (int y = 0; y < Y_CNT; y++) begin
				automatic int index = y*X_CNT + x;

				if (x != X_CNT - 1) begin
					flit_i_sig[index][BR_EAST] = flit_o_sig[index + 1][BR_WEST];
					req_i_sig[index][BR_EAST] = req_o_sig[index + 1][BR_WEST];
					ack_i_sig[index][BR_EAST] = ack_o_sig[index + 1][BR_WEST];
				end else begin
					flit_i_sig[index][BR_EAST] = '0;
					req_i_sig[index][BR_EAST] = '0;
					ack_i_sig[index][BR_EAST] = '1;
				end

				if (x != 0) begin
					flit_i_sig[index][BR_WEST] = flit_o_sig[index - 1][BR_EAST];
					req_i_sig[index][BR_WEST] = req_o_sig[index - 1][BR_EAST];
					ack_i_sig[index][BR_WEST] = ack_o_sig[index - 1][BR_EAST];
				end else begin
					flit_i_sig[index][BR_WEST] = '0;
					req_i_sig[index][BR_WEST] = '0;
					ack_i_sig[index][BR_WEST] = '1;
				end

				if (y != Y_CNT - 1) begin
					flit_i_sig[index][BR_NORTH] = flit_o_sig[index + X_CNT][BR_SOUTH];
					req_i_sig[index][BR_NORTH] = req_o_sig[index + X_CNT][BR_SOUTH];
					ack_i_sig[index][BR_NORTH] = ack_o_sig[index + X_CNT][BR_SOUTH];
				end else begin
					flit_i_sig[index][BR_NORTH] = '0;
					req_i_sig[index][BR_NORTH] = '0;
					ack_i_sig[index][BR_NORTH] = '1;
				end

				if (y != 0) begin
					flit_i_sig[index][BR_SOUTH] = flit_o_sig[index - X_CNT][BR_NORTH];
					req_i_sig[index][BR_SOUTH] = req_o_sig[index - X_CNT][BR_NORTH];
					ack_i_sig[index][BR_SOUTH] = ack_o_sig[index - X_CNT][BR_NORTH];
				end else begin
					flit_i_sig[index][BR_SOUTH] = '0;
					req_i_sig[index][BR_SOUTH] = '0;
					ack_i_sig[index][BR_SOUTH] = '1;
				end

				flit_i_sig[index][BR_LOCAL] = flit_i[index];
				req_i_sig[index][BR_LOCAL] = req_i[index];
				ack_o[index] = ack_o_sig[index][BR_LOCAL];
				flit_o[index] = flit_o_sig[index][BR_LOCAL];
				req_o[index] = req_o_sig[index][BR_LOCAL];
				ack_i_sig[index][BR_LOCAL] = ack_i[index];
			end
		end
	end
	
endmodule
