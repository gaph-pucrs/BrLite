`ifndef BR_LITE_PKG
`define BR_LITE_PKG

package BrLitePkg;

	parameter BR_NPORT = 5;
	typedef enum logic [($clog2(BR_NPORT) - 1):0] {
		BR_EAST,
		BR_WEST,
		BR_NORTH,
		BR_SOUTH,
		BR_LOCAL
	} br_port_t;

	localparam NSVC = 4;
	typedef enum logic [($clog2(NSVC) - 1):0] {
		BR_SVC_ALL,
		BR_SVC_CLEAR,
		BR_SVC_TGT,
		BR_SVC_MON
	} br_svc_t;

	typedef struct packed {
		logic 	[31:0] 	payload;
		logic 	[15:0] 	seq_target;
		logic 	[15:0] 	seq_source;
		logic 	[15:0] 	producer;
		logic 	[ 7:0] 	ksvc;
		logic 	[ 4:0] 	id;
		br_svc_t 		service;
	} br_data_t;

endpackage

`endif
