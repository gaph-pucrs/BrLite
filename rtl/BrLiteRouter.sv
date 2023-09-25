/**
 * MA-Memphis
 * @file BrLiteRouter.sv
 * 
 * @author Angelo Elias Dalzotto (angelo.dalzotto@edu.pucrs.br)
 * GAPH - Hardware Design Support Group (https://corfu.pucrs.br/)
 * PUCRS - Pontifical Catholic University of Rio Grande do Sul (http://pucrs.br/)
 * 
 * @date October 2022
 * 
 * @brief Light BrNoC router module -- Removed backtrack (unicast)
 */

module BrLiteRouter
	import BrLitePkg::*;
#(
	parameter ADDRESS = 0,
	parameter CAM_SIZE = 8,
	parameter CLEAR_TICKS = 180
)
(
	/* Router signals */
	input	logic 			clk_i,
	input	logic 			rst_ni,
	input	logic [31:0]	tick_cnt_i,
	output	logic			local_busy_o,

	/* Data inputs */
	input 	br_data_t [NPORT - 1:0]	flit_i,
	input 	logic	  [NPORT - 1:0] req_i,
	output	logic 	  [NPORT - 1:0] ack_o,

	/* Data outputs */
	output	br_data_t [NPORT - 1:0]	flit_o,
	output	logic	  [NPORT - 1:0]	req_o,
	input	logic	  [NPORT - 1:0]	ack_i
);
	typedef enum {
		IN_INIT, 
		IN_ARBITRATION, 
		IN_TEST_SPACE, 
		IN_WRITE, 
		IN_CLEAR, 
		IN_ACK
	} in_fsm_t;		

	typedef enum {
		OUT_INIT, 
		OUT_ARBITRATION, 
		OUT_SERVICE, 
		OUT_PROPAGATE, 
		OUT_LOCAL, 
		OUT_CLEAR, 
		OUT_ACK_ALL, 
		OUT_ACK_LOCAL
	} out_fsm_t;

	typedef struct packed {
		br_data_t data;
		br_port_t origin;
		logic used;
		logic pending;
	} cam_line_t;

	typedef logic [$clog2(CAM_SIZE) - 1 : 0] cam_idx_t;

	logic has_request;
	logic clear_local;
	logic is_in_table;
	logic should_write;
	logic is_full;
	logic wrote_local;
	logic has_pending;
	logic propagate_local;
	logic [CAM_SIZE - 1 : 0] is_in_idx;
	logic [CAM_SIZE - 1 : 0] is_pending_idx;
	logic [NPORT - 1 : 0] acked_ports;
	logic [31:0] clear_tick;
	cam_idx_t free_index;
	cam_idx_t source_index;
	cam_idx_t clear_index;
	cam_idx_t selected_index;
	cam_idx_t next_index;
	br_port_t selected_port;
	br_port_t next_port;
	in_fsm_t in_cs, in_ns;
	out_fsm_t out_cs, out_ns;
	cam_line_t [(CAM_SIZE - 1):0] cam;

	assign propagate_local = (
		cam[selected_index].data.service == BR_SVC_ALL && 
		cam[selected_index].data.source != 16'(ADDRESS)
	);
	assign local_busy_o = wrote_local;

	// Check if incoming data is in any table position
	assign is_in_table = | is_in_idx;

	assign has_pending = | is_pending_idx;

	assign should_write = (
		(
			flit_i[selected_port].service == BR_SVC_ALL || 
			flit_i[selected_port].service == BR_SVC_TGT
		) &&
		!is_in_table
	);

	always_comb begin
		for (int i = 0; i < NPORT; i++)
			flit_o[i] = cam[selected_index].data;
	end

	// Check if has request
	assign has_request = | req_i;

	// Check if CAM has space available
	always_comb begin
		is_full = 1'b1;
		for (int i = 0; i < CAM_SIZE; i++)
			is_full &= cam[i].used;
	end

	// Check if incoming data is present in each table position
	always_comb begin
		for (int i = 0; i < CAM_SIZE; i++) begin
			is_in_idx[i] = (
				(cam[i].data.source == flit_i[selected_port].source) && 
				(cam[i].data.id == flit_i[selected_port].id)
			);
		end
	end

	always_comb begin
		for (int i = 0; i < CAM_SIZE; i++)
			is_pending_idx[i] = (cam[i].used && cam[i].pending);
	end

	// Beautiful synthesizable SystemVerilog code:
	always_comb begin
		free_index = '0;
		for (int i = 0; i < CAM_SIZE; i++) begin
			if (!cam[i].used) begin
				free_index = cam_idx_t'(i);
				break;
			end
		end
	end

	// Beautiful synthesizable SystemVerilog code:
	always_comb begin
		source_index = '0;
		for (int i = 0; i < CAM_SIZE; i++) begin
			if (is_in_idx[i]) begin
				source_index = cam_idx_t'(i);
				break;
			end
		end
	end

	always_comb begin
		automatic logic found = 1'b0;
		next_port = EAST;
		for (int i = 0; i < NPORT; i++) begin
			if (i <= selected_port) begin
				continue;
			end else if (req_i[i]) begin
				found = 1'b1;
				next_port = br_port_t'(i);
				break;
			end
		end

		if (!found) begin
			for (int i = 0; i < NPORT; i++) begin
				if (req_i[i]) begin
					next_port = br_port_t'(i);
					break;
				end
			end
		end
	end

	always_comb begin
		automatic logic found = 1'b0;
		next_index = '0;
		for (int i = 0; i < CAM_SIZE; i++) begin
			if (i <= selected_index) begin
				continue;
			end else if (is_pending_idx[i]) begin
				found = 1'b1;
				next_index = cam_idx_t'(i);
				break;
			end
		end

		if (!found) begin
			for (int i = 0; i < CAM_SIZE; i++) begin
				if (is_pending_idx[i]) begin
					next_index = cam_idx_t'(i);
					break;
				end
			end
		end
	end

	// Input FSM control
	always_comb begin
		unique case(in_cs)
			IN_INIT:
				if (!clear_local && has_request)
					in_ns = IN_ARBITRATION;
				else
					in_ns = IN_INIT;
			IN_ARBITRATION:
				in_ns = IN_TEST_SPACE;
			IN_TEST_SPACE:
				if (should_write)
					if (!is_full)
						in_ns = IN_WRITE;
					else
						in_ns = IN_INIT;
				else if (
					flit_i[selected_port].service == BR_SVC_CLEAR &&
					is_in_table
					/* && not pending no SystemC, que não está no VHDL. Acho que deve ficar sem por enquanto. */
				)
					in_ns = IN_CLEAR;
				else 
					in_ns = IN_ACK;
			IN_ACK:
				if (!req_i[selected_port])
					in_ns = IN_INIT;
				else
					in_ns = IN_ACK;
			default:
				in_ns = IN_ACK;
		endcase
	end

	// Output FSM control
	always_comb begin
		unique case(out_cs)
			OUT_INIT:
				if (has_pending && !clear_local)
					out_ns = OUT_ARBITRATION;
				else
					out_ns = OUT_INIT;
			OUT_ARBITRATION:
				out_ns = OUT_SERVICE;
			OUT_SERVICE:
				if (
					cam[selected_index].data.service == BR_SVC_TGT && 
					cam[selected_index].data.target == 16'(ADDRESS)
				)
					out_ns = OUT_LOCAL;
				else
					out_ns = OUT_PROPAGATE;
			OUT_PROPAGATE:
				out_ns = OUT_ACK_ALL;
			OUT_ACK_ALL:
				if (acked_ports == '1)
					if (cam[selected_index].data.service == BR_SVC_CLEAR)
						out_ns = OUT_CLEAR;
					else
						out_ns = OUT_INIT;
				else
					out_ns = OUT_ACK_ALL;
			OUT_CLEAR:
				out_ns = OUT_INIT;
			OUT_LOCAL:
				if (ack_i[LOCAL])
					out_ns = OUT_ACK_LOCAL;
				else
					out_ns = OUT_LOCAL;
			OUT_ACK_LOCAL:
				if (!ack_i[LOCAL])
					out_ns = OUT_INIT;
				else
					out_ns = OUT_ACK_LOCAL;
		endcase
	end

	// Input FSM state change
	always_ff @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni)
			in_cs <= IN_INIT;
		else
			in_cs <= in_ns;
	end

	// Output FSM state change
	always_ff @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni)
			out_cs <= OUT_INIT;
		else
			out_cs <= out_ns;
	end

	// Input control
	always_ff @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni) begin
			for (int i = 0; i < NPORT; i++)
				ack_o[i] <= 1'b0;

			selected_port <= LOCAL;
		end
		else begin
			unique case(in_cs)
				IN_INIT:
					ack_o[selected_port] <= 1'b0;
				IN_ARBITRATION:
					selected_port <= next_port;
				IN_TEST_SPACE:
					if (should_write && is_full)
						$warning("++++++++++++++++++++++++++++++++++ PE %h: CAM IS FULL", ADDRESS);
				IN_ACK:
					ack_o[selected_port] <= 1'b1; // ACK ocorre antes no SystemC
				default: ;
			endcase
		end
	end

	// Output control
	always_ff @(posedge clk_i or negedge rst_ni)  begin
		if (!rst_ni) begin
			req_o <= '0;

			acked_ports <= '0;
		end else begin
			unique case(out_cs)
				OUT_INIT: begin
					req_o <= '0;

					acked_ports <= '0;
				end
				OUT_ARBITRATION: begin
					selected_index <= next_index;
				end
				OUT_PROPAGATE: begin
					req_o <= '1;

					req_o[cam[selected_index].origin] <= 1'b0;					
					acked_ports[cam[selected_index].origin] <= 1'b1;

					req_o[LOCAL] <= propagate_local;
					acked_ports[LOCAL] <= ~propagate_local;
				end
				OUT_ACK_ALL: begin
					acked_ports <= acked_ports | ack_i;
					req_o <= req_o & ~ack_i;
				end
				OUT_CLEAR: begin
					if (cam[selected_index].data.target == 16'(ADDRESS) && cam[selected_index].used) begin
						$display(
							"************************************************************ end CLEAR: %x %x %x %x", 
							cam[selected_index].data.source, 
							cam[selected_index].data.target, 
							cam[selected_index].data.service, 
							cam[selected_index].data.payload
						);
					end
				end
				OUT_LOCAL: begin
					req_o[LOCAL] <= 1'b1;
				end
				OUT_ACK_LOCAL: begin
					req_o[LOCAL] <= 1'b0;
				end
			endcase
		end
	end

	// CAM Control
	always_ff @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni) begin
			wrote_local <= 1'b0;
			clear_tick <= '0;
			clear_index <= '0;
		end
		else begin
			unique case(in_cs)
				IN_WRITE: begin
					cam[free_index].data <= flit_i[selected_port];
					cam[free_index].origin <= selected_port;
					cam[free_index].used <= 1'b1;
					cam[free_index].pending <= 1'b1;

					if (selected_port == LOCAL) begin
						wrote_local <= 1'b1;
						clear_index <= free_index;
						clear_tick  <= tick_cnt_i + CLEAR_TICKS;
					end
				end
				IN_CLEAR:
					if (
						cam[source_index].data.service != BR_SVC_CLEAR && 
						!cam[source_index].pending
					) begin
						cam[source_index].data.service <= BR_SVC_CLEAR;
						cam[source_index].pending <= 1'b1;
					end
				default: ;
			endcase

			unique case(out_cs)
				OUT_ACK_ALL, OUT_ACK_LOCAL:
					cam[selected_index].pending <= 1'b0;
				OUT_CLEAR:
					cam[selected_index].used <= 1'b0;
				default: ;
			endcase

			// SystemC also unsets wrote_local
			if (wrote_local && clear_tick < tick_cnt_i)
				clear_local <= 1'b1;

			// SystemC uses clear_local instead of wrote_local
			// SystemC is not verifying if cam is pending
			if (wrote_local && !cam[clear_index].pending && in_cs == IN_INIT && out_cs == OUT_INIT) begin
				wrote_local <= 1'b0;
				clear_local <= 1'b0;
				cam[clear_index].data.service <= BR_SVC_CLEAR;
				cam[clear_index].pending <= 1'b1;
			end
		end
	end

endmodule
