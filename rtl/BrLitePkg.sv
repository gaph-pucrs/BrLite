package BrLitePkg;

	localparam NPORT = 5;
	typedef enum logic [$clog2(NPORT) - 1 : 0] {
		EAST,
		WEST,
		NORTH,
		SOUTH,
		LOCAL
	} br_port_t;

	localparam NSVC = 3;
	typedef enum logic [$clog2(NSVC) - 1 : 0] {
		BR_SVC_ALL,
		BR_SVC_TGT,
		BR_SVC_CLEAR
	} br_svc_t;

	typedef struct packed {
		logic 	[31:0] 	payload;
		logic 	[15:0] 	target;
		logic 	[15:0] 	source;
		logic 	[15:0] 	producer;
		logic 	[ 7:0] 	ksvc;
		logic 	[ 4:0] 	id;
		br_svc_t 		service;
	} br_data_t;

endpackage
