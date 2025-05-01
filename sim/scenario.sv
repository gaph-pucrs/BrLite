/**
 * BrLite
 * @file scenario.sv
 *
 * @author Angelo Elias Dal Zotto (angelo.dalzotto@edu.pucrs.br)
 * GAPH - Hardware Design Support Group (https://corfu.pucrs.br)
 * PUCRS - Pontifical Catholic University of Rio Grande do Sul (http://pucrs.br/)
 *
 * @date September 2023
 *
 * @brief BrLite testbench scenario
 */

`ifndef SCENARIO_PKG
`define SCENARIO_PKG

`include "../rtl/BrLitePkg.sv"

package scenario;
	import BrLitePkg::*;

	parameter X_CNT = 8;
	parameter Y_CNT = 8;
	parameter PE_CNT = X_CNT * Y_CNT;
	parameter NPKTS = 9;

	typedef struct packed {
		int timestamp;
		int source;
		logic [15:0] payload;
	} record_t;

	const record_t services [NPKTS] = '{
		'{ 4, 4, 32'h01},
		'{80, 0, 32'h02},
		'{80, 3, 32'h03},
        '{80, 5, 32'h04},

        '{680, 30, 32'h9F}, 
        '{750,  3, 32'h77},

        '{900, 1, 32'h22},

        '{1200, 8, 32'hBC},
        '{1200, 5, 32'hF1}
	};

endpackage

`endif
