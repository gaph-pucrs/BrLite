`include "../rtl/BrLitePkg.sv"
`include "../rtl/BrLiteRouter.sv"
`include "BrLiteNoC.sv"
`include "scenario.sv"

module testbench ();
	// timeunit 1ns; timeprecision 1ns;
	import BrLitePkg::*;
	import scenario::*;

	logic clk=1, rst_n;

	logic 	  [        31:0] 		tick_cnt;
	br_data_t [PE_CNT - 1:0] 		flit_i;
	logic 	  [PE_CNT - 1:0] 		req_i;
	logic 	  [PE_CNT - 1:0] 		ack_o;
	br_data_t [PE_CNT - 1:0] 		flit_o;
	logic 	  [PE_CNT - 1:0] 		req_o;
	logic 	  [PE_CNT - 1:0] 		ack_i;
	logic 	  [PE_CNT - 1:0] 		busy;
	logic	  [ NPKTS - 1:0] 		useds;
	logic	  [PE_CNT - 1:0][4:0] 	ids;

	int fd;
	initial begin
		fd = $fopen("brNoC_log.txt", "w");

		rst_n = 1'b0;
		#100
		rst_n = 1'b1;
	end

	always begin
        #5.0 clk = 1'b0;
        #5.0 clk = 1'b1;
    end

	BrLiteNoC #(
		X_CNT, 
		Y_CNT
	) noc (
		.clk_i		(clk),
		.rst_ni		(rst_n),
		.tick_cnt_i	(tick_cnt),
		.flit_i		(flit_i),
		.req_i		(req_i),
		.ack_o		(ack_o),
		.flit_o		(flit_o),
		.req_o		(req_o),
		.ack_i		(ack_i),
		.busy_o		(busy)
	);

	always_ff @(posedge clk or negedge rst_n) begin
		if (rst_n == 1'b0) begin
			tick_cnt <= '0;
		end
		else begin
			tick_cnt <= tick_cnt + 1'b1;
		end
	end

	// Send
	always_ff @(posedge clk or negedge rst_n) begin
		if (rst_n == 1'b0) begin
			req_i 	<= '0;
			flit_i  <= '0;
			ids 	<= '0;
			useds 	<= '0;			
		end else begin
			for (int i = 0; i < NPKTS; i++) begin
				if (tick_cnt >= services[i].timestamp && !useds[i] && !busy[services[i].source]) begin
					req_i[services[i].source] 			<= 1'b1;
					flit_i[services[i].source].source 	<= to_xy(services[i].source);
					flit_i[services[i].source].target 	<= to_xy(services[i].target);
					flit_i[services[i].source].payload 	<= services[i].payload;
					flit_i[services[i].source].service 	<= br_svc_t'(services[i].service);
					flit_i[services[i].source].id 		<= ids[services[i].source];
					ids[services[i].source] 			<= ids[services[i].source] + 1'b1;
					useds[i] 							<= 1'b1;

					$display("[%0t] Injected - services[%0d] - timestamp = %0d - source %0d - target %0d", $time, i, services[i].timestamp, services[i].source, services[i].target);
					/*$display(
						"-----------------------------------------  INSERT SERVICE %d %d %d %d",
						services[i].source,
						services[i].target,
						services[i].payload,
						services[i].service
					);*/
				end
			end

			for (int i = 0; i < PE_CNT; i++) begin
				if (ack_o[i] == 1'b1) begin
					req_i[i] <= 1'b0;
				end
			end

			if (services[NPKTS - 1].timestamp + 3000 < tick_cnt) begin
				$display("---END SIMULATION------- %d", services[NPKTS - 1][0]);
				$fclose(fd);
				$finish();
			end
		end
	end

	logic [PE_CNT - 1 :0] prev_ack;
	always_ff @(posedge clk or negedge rst_n) begin
		if (rst_n == 1'b0) begin
			prev_ack 	<= '0;
			ack_i 		<= '0;			
		end else begin
			prev_ack 	<= req_o;
			ack_i 		<= prev_ack;			
		end
	end

	// Receive
	genvar gen_i;
	generate
		for (gen_i = 0; gen_i < PE_CNT; gen_i++) begin
			always_ff @(posedge req_o[gen_i]) begin
				$fdisplay(
					fd, 
					"%s %d   from: %d  %0H  t:%d", 
					flit_o[gen_i].service == BR_SVC_ALL ? "ALL" : "TGT", 
					gen_i,
					((flit_o[gen_i].source >> 8) + ((flit_o[gen_i].source & 16'h00FF)*X_CNT)), 
					flit_o[gen_i].payload,
					tick_cnt
				);
			end
		end
	endgenerate

	function logic [15:0] to_xy(logic [15:0] index);
		return ((index % X_CNT) << 8) + (index / X_CNT);
	endfunction

endmodule
