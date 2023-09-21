package scenario;
	import BrLitePkg::*;

	parameter X_CNT = 8;
	parameter Y_CNT = 8;
	parameter PE_CNT = X_CNT * Y_CNT;
	parameter NPKTS = 29;

	typedef struct packed {
		int timestamp;
		int source;
		int target;
		logic [31:0] payload;
		br_svc_t service;
	} record_t;

	const record_t services [NPKTS] = '{
		'{ 4, 4, 0, 32'h01, BR_SVC_ALL},
		'{80, 0, 0, 32'h02, BR_SVC_ALL},
		'{80, 3, 0, 32'h03, BR_SVC_ALL},
        '{80, 5, 0, 32'h04, BR_SVC_ALL},

		'{150, 8, 6, 32'hBA, BR_SVC_TGT},

		'{250, 8, 5, 32'hA8, BR_SVC_TGT}, // burst to 5
		'{300, 0, 5, 32'hA0, BR_SVC_TGT}, 
		'{350, 6, 5, 32'hA6, BR_SVC_TGT}, 
		'{400, 1, 5, 32'hA1, BR_SVC_TGT}, 
		'{410, 3, 5, 32'hA3, BR_SVC_TGT}, 
		'{420, 4, 5, 32'hA4, BR_SVC_TGT}, 
		'{410, 7, 5, 32'hA7, BR_SVC_TGT}, 

		'{500, 2, 0, 32'hEE, BR_SVC_TGT}, // to 0
        '{550, 1, 0, 32'hFF, BR_SVC_TGT}, 
        '{650, 5, 0, 32'h88, BR_SVC_TGT},

		'{650,  6, 4, 32'h66, BR_SVC_TGT}, // 6 send to 4
        '{680, 30, 0, 32'h9F, BR_SVC_ALL}, 
        '{750,  3, 4, 32'h77, BR_SVC_ALL}, // 3 send to 4
        '{770,  0, 4, 32'hCA, BR_SVC_TGT}, // 0 send to 4
        '{790,  2, 4, 32'hBE, BR_SVC_TGT}, // 2 send to 4

		'{850, 6, 0, 32'h11, BR_SVC_TGT},
        '{900, 1, 7, 32'h22, BR_SVC_ALL},
        '{950, 8, 7, 32'h33, BR_SVC_TGT},
        '{950, 2, 7, 32'h44, BR_SVC_TGT},

		'{1100, 7, 0, 32'hAF, BR_SVC_TGT},
        '{1150, 4, 0, 32'hDE, BR_SVC_TGT},
        '{1200, 8, 0, 32'hBC, BR_SVC_ALL},
        '{1200, 5, 0, 32'hF1, BR_SVC_ALL},
        '{1300, 2, 7, 32'h33, BR_SVC_TGT}
	};

endpackage
