/**
 * BrLite
 * @file BrLitePkg.sv
 *
 * @author Angelo Elias Dal Zotto (angelo.dalzotto@edu.pucrs.br)
 * GAPH - Hardware Design Support Group (https://corfu.pucrs.br)
 * PUCRS - Pontifical Catholic University of Rio Grande do Sul (http://pucrs.br/)
 *
 * @date September 2023
 *
 * @brief BrLite package
 */

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

	typedef struct packed {
		logic 	[15:0] 	seq_source;
		logic 	[15:0] 	payload;
		logic 	[ 3:0] 	ksvc;
		logic 	[ 4:0] 	id;
		logic 			clear;
	} br_data_t;

endpackage

`endif
