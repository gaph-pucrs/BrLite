`include "BrLitePkg.sv"
`include "scenario.sv"

module testbench
(
	input logic clk,
	input logic rst_n
);
	// timeunit 1ns; timeprecision 1ns;
	import BrLitePkg::*;
	import scenario::*;

	logic 	  [31:0] tick_cnt;
	br_data_t [PE_CNT - 1:0] flit_i;
	logic 	  [PE_CNT - 1:0] req_i;
	logic 	  [PE_CNT - 1:0] ack_o;
	br_data_t [PE_CNT - 1:0] flit_o;
	logic 	  [PE_CNT - 1:0] req_o;
	logic 	  [PE_CNT - 1:0] ack_i;
	logic 	  [PE_CNT - 1:0] busy;
	logic	  [NSVC - 1  :0] useds = '0;
	logic	  [PE_CNT - 1:0][4:0] ids;

	BrLiteNoC 
	#(X_CNT, Y_CNT)
	noc(
		.clk_i(clk),
		.rst_ni(rst_n),
		.tick_cnt_i(tick_cnt),
		.flit_i(flit_i),
		.req_i(req_i),
		.ack_o(ack_o),
		.flit_o(flit_o),
		.req_o(req_o),
		.ack_i(ack_i),
		.busy_o(busy)
	);

	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n)
			tick_cnt <= '0;
		else
			tick_cnt <= tick_cnt + 1'b1;
	end

	// Send
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			req_i <= '0;
			ids <= '0;
			useds <= '0;			
		end else begin
			for(int i = 0; i < NSVC; i++) begin
				if(services[i][0] >= tick_cnt && !useds[i] && !busy[services[i][1]]) begin
					req_i[services[i][1]] <= 1'b1;
					flit_i[services[i][1]].payload <= services[i][3];
					flit_i[services[i][1]].source <= to_xy(services[i][1]);
					flit_i[services[i][1]].target <= to_xy(services[i][2]);
					flit_i[services[i][1]].service <= services[i][4];
					flit_i[services[i][1]].id <= ids[services[i][1]];
					ids[services[i][1]] <= ids[services[i][1]] + 1'b1;
					useds[i] <= 1'b1;

					$display(
						"-----------------------------------------  INSERT SERVICE %d %d %d %d",
						services[i][1],
						services[i][2],
						services[i][3],
						services[i][4]
					);
				end
			end

			for(int i = 0; i < PE_CNT; i++)
				if(ack_o[i])
					req_i[i] <= 1'b0;

			if(services[NSVC - 1][0] + 300 < tick_cnt) begin
				$display("---END SIMULATION------- %d", services[NSVC - 1][0]);
				$fclose(fd);
				$finish();
			end
		end
	end

	// Receive
	genvar gen_i;
	generate
		for(gen_i = 0; gen_i < PE_CNT; gen_i++) begin
			always_ff @(posedge req_o[gen_i]) begin
				$fdisplay(
					fd, 
					"%s %d   from: %d  %H  t:%d", 
					flit_o[gen_i].service == BR_SVC_ALL ? "ALL" : "TGT", 
					gen_i,
					((flit_o[gen_i].source >> 8) + ((flit_o[gen_i].source & 16'h00FF)*X_CNT)), 
					flit_o[gen_i].payload,
					tick_cnt
				);
			end
		end
	endgenerate

	logic [PE_CNT - 1 :0] prev_ack;
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			prev_ack <= '0;
		end else begin
			prev_ack <= req_o;
			ack_i <= prev_ack;			
		end
	end

	int fd;
	initial begin
		fd = $fopen("brNoC_log.txt", "w");
	end

	function logic [15:0] to_xy(logic [15:0] index);
		return ((index % X_CNT) << 8) + (index / X_CNT);
	endfunction

endmodule
