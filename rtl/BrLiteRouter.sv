/**
 * BrLite
 * @file BrLiteRouter.sv
 * 
 * @author Angelo Elias Dal Zotto (angelo.dalzotto@edu.pucrs.br)
 * GAPH - Hardware Design Support Group (https://corfu.pucrs.br/)
 * PUCRS - Pontifical Catholic University of Rio Grande do Sul (http://pucrs.br/)
 * 
 * @date October 2023
 * 
 * @brief Light BrNoC router module -- Removed backtrack (unicast)
 */

module BrLiteRouter
    import BrLitePkg::*;
#(
    parameter logic [15:0] ADDRESS = 0,
    parameter 			   CAM_SIZE = 8,
    parameter 			   CLEAR_TICKS = 150
)
(
    input  logic 					 clk_i,
    input  logic 					 rst_ni,

    /* Router signals */
    input  logic 	 [63:0] 		 tick_cnt_i,
    output logic					 local_busy_o,

    /* Data inputs */
    input  br_data_t [(NPORT - 1):0] flit_i,
    input  logic	 [(NPORT - 1):0] req_i,
    output logic 	 [(NPORT - 1):0] ack_o,

    /* Data outputs */
    output br_data_t [(NPORT - 1):0] flit_o,
    output logic	 [(NPORT - 1):0] req_o,
    input  logic	 [(NPORT - 1):0] ack_i
);

////////////////////////////////////////////////////////////////////////////////
// Global signals
////////////////////////////////////////////////////////////////////////////////
    typedef struct packed {
        br_data_t data;
        br_port_t origin;
        logic used;
        logic pending;
    } cam_line_t;

    typedef logic [($clog2(CAM_SIZE) - 1):0] cam_idx_t;

    logic                         clear_local;
    cam_idx_t                     clear_index;

    logic 	   [63:0] 		      clear_tick;
    cam_line_t [(CAM_SIZE - 1):0] cam;


////////////////////////////////////////////////////////////////////////////////
// Input FSM
////////////////////////////////////////////////////////////////////////////////

    /* In FSM states */
    typedef enum {
        IN_INIT, 
        IN_ARBITRATION, 
        IN_TEST_SPACE, 
        IN_WRITE, 
        IN_CLEAR, 
        IN_ACK
    } in_fsm_t;

    in_fsm_t in_state;

    /* Input port selection */
    br_port_t selected_port;
    br_port_t next_port;

    /* Input port Arbitration (round-robin) */
    always_comb begin
        next_port = selected_port;
        for (int i = 0; i < NPORT; i++) begin
            if (i <= selected_port)
                continue;

            if (req_i[i]) begin
                next_port = br_port_t'(i);
                break;
            end
        end

        if (next_port == selected_port) begin
            for (int i = 0; i < NPORT; i++) begin
                if (i >= selected_port)
                    continue;

                if (req_i[i]) begin
                    next_port = br_port_t'(i);
                    break;
                end
            end
        end
    end

    /* Input port FF */
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            selected_port <= BR_EAST;
        end
        else if (in_state == IN_ARBITRATION) begin
            selected_port <= next_port;
        end
    end

    /* Check if incoming data is present in each table position */
    logic [CAM_SIZE - 1 : 0] is_in_idx;
    always_comb begin
        for (int i = 0; i < CAM_SIZE; i++) begin
            is_in_idx[i] = (
                (cam[i].data.source == flit_i[selected_port].source) 
                && (cam[i].data.id  == flit_i[selected_port].id)
                && cam[i].used /* Addition not present in VHDL */
            );
        end
    end

    /* Check if CAM has space available */
    logic cam_full;
    always_comb begin
        cam_full = 1'b1;
        for (int i = 0; i < CAM_SIZE; i++)
            cam_full &= cam[i].used;
    end

    /* In FSM transition */
    in_fsm_t in_next_state;
    always_comb begin
        case (in_state)
            IN_INIT: 		in_next_state = (req_i != '0 && !clear_local) ? IN_ARBITRATION : IN_INIT;
            IN_ARBITRATION: in_next_state = IN_TEST_SPACE;
            IN_TEST_SPACE: begin
                if (
                    (flit_i[selected_port].service == BR_SVC_ALL || flit_i[selected_port].service == BR_SVC_TGT) 
                    && is_in_idx == '0
                ) begin
                    if (!cam_full) begin
                        in_next_state = IN_WRITE;
                    end
                    else begin
                        $display("++++++++++++++++++++++++++++++++++  CAM CHEIA  SEND LOCAL:  Address: %d", ADDRESS);
                        in_next_state = IN_INIT;
                    end
                end
                else if (flit_i[selected_port].service == BR_SVC_CLEAR && is_in_idx != '0) begin
                    /**
                     * @todo
                     * SystemC implementation uses !pending too
                     * Try without this condition for now
                     */
                    in_next_state = IN_CLEAR;
                end
                else begin
                    /* Ignore */
                    in_next_state = IN_ACK;
                end
            end
            IN_WRITE,
            IN_CLEAR:       in_next_state = IN_ACK;
            IN_ACK:         in_next_state = !req_i[selected_port] ? IN_INIT : IN_ACK; /* Do we really need to wait for req down? */
            default:        in_next_state = IN_INIT;
        endcase
    end

    /* In FSM FF */
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            in_state <= IN_INIT;
        end
        else begin
            in_state <= in_next_state;
        end
    end

    /* Ack control */
    always_comb begin
        ack_o = '0;
        ack_o[selected_port] = (in_state == IN_ACK);
    end

////////////////////////////////////////////////////////////////////////////////
//  Output FSM
////////////////////////////////////////////////////////////////////////////////

    /* Out FSM states */
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

    out_fsm_t out_state;

    /* Line pending to transmit */
    cam_idx_t is_pending;
    always_comb begin
        for (int i = 0; i < CAM_SIZE; i++)
            is_pending[i] = (cam[i].used && cam[i].pending);
    end

    /* Line selected to transmit */
    cam_idx_t selected_index;
    cam_idx_t next_index;

    /* Line Arbitration (round-robin) */
    always_comb begin
        next_index = selected_index;
        for (int i = 0; i < CAM_SIZE; i++) begin
            if (i <= selected_index)
                continue;

            if (is_pending[i]) begin
                next_index = cam_idx_t'(i);
                break;
            end
        end

        if (next_index == selected_index) begin
            for (int i = 0; i < CAM_SIZE; i++) begin
                if (i >= selected_index)
                    continue;

                if (is_pending[i]) begin
                    next_index = cam_idx_t'(i);
                    break;
                end
            end
        end
    end

    /* Line selection FF */
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            selected_index <= '0;
        end
        else if (out_state == OUT_ARBITRATION) begin
            selected_index <= next_index;
        end
    end

    /* Ack input control */
    logic [(NPORT - 1):0] acked_ports;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            acked_ports <= '0;
        end
        else begin
            case (out_state)
                OUT_PROPAGATE: begin
                    acked_ports[cam[selected_index].origin] <= 1'b1;
                    acked_ports[BR_LOCAL] 	<= !(
                        cam[selected_index].data.service == BR_SVC_ALL 
                        && cam[selected_index].data.source != ADDRESS
                    );
                end
                OUT_ACK_ALL:   acked_ports <= acked_ports | ack_i;
                default:       acked_ports <= '0;
            endcase
        end
    end

    /* Out FSM transition */
    out_fsm_t out_next_state;
    always_comb begin
        case (out_state)
            OUT_INIT:        out_next_state = (is_pending != '0 && !clear_local) ? OUT_ARBITRATION : OUT_INIT;
            OUT_ARBITRATION: out_next_state = OUT_SERVICE;
            OUT_SERVICE:     
                out_next_state = (
                    cam[selected_index].data.service == BR_SVC_TGT 
                    && cam[selected_index].data.target == ADDRESS
                ) 
                ? OUT_LOCAL 
                : OUT_PROPAGATE;
            OUT_PROPAGATE:   out_next_state = OUT_ACK_ALL;
            OUT_LOCAL: begin
                out_next_state = ack_i[BR_LOCAL] ? OUT_INIT : OUT_LOCAL;
                
                if (ack_i[BR_LOCAL]) begin
                    $display(
                        ">>>>>>>>>>>>>>>>> SEND LOCAL: [[%h %h %h %h]] %h %h Address: %h",
                        cam[selected_index].data.source[15:8],
                        cam[selected_index].data.source[7:0],
                        cam[selected_index].data.target[15:8],
                        cam[selected_index].data.target[7:0],
                        cam[selected_index].data.service,
                        cam[selected_index].data.payload,
                        ADDRESS
                    );
                end
            end
            OUT_ACK_ALL: begin
                if (acked_ports == '1)
                    out_next_state = (cam[selected_index].data.service == BR_SVC_CLEAR) ? OUT_CLEAR : OUT_INIT;
                else
                    out_next_state = OUT_ACK_ALL;
            end
            OUT_ACK_LOCAL:   out_next_state = !ack_i[BR_LOCAL] ? OUT_INIT : OUT_ACK_LOCAL;
            OUT_CLEAR:       out_next_state = OUT_INIT;
            default:         out_next_state = OUT_INIT;
        endcase
    end

    /* Out FSM FF */
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            out_state <= OUT_INIT;
        end
        else begin
            out_state <= out_next_state;
        end
    end

    /* Req control */
    always_comb begin
        req_o = '0;
        case (out_state)
            OUT_ACK_LOCAL: req_o[BR_LOCAL] = 1'b1;
            OUT_ACK_ALL:   req_o = ~acked_ports;
            default:       req_o = '0;
        endcase
    end

    /* Clear report */
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni && out_state == OUT_CLEAR) begin
            if (cam[selected_index].data.target == ADDRESS && cam[selected_index].used) begin
                $display(
                    "************************************************************ end CLEAR: %x %x %x %x %x %x", 
                    cam[selected_index].data.source[15:8], 
                    cam[selected_index].data.source[7:0], 
                    cam[selected_index].data.target[15:8], 
                    cam[selected_index].data.target[7:0], 
                    cam[selected_index].data.service, 
                    cam[selected_index].data.payload
                );
            end
        end
    end

    /* Output connection */
    always_comb begin
        for (int i = 0; i < NPORT; i++)
            flit_o[i] = cam[selected_index].data;
    end
    
////////////////////////////////////////////////////////////////////////////////
//  CAM control
////////////////////////////////////////////////////////////////////////////////

    /* Index to insert into the CAM */
    cam_idx_t free_index;
    always_comb begin
        free_index = '0;
        for (int i = 0; i < CAM_SIZE; i++) begin
            if (!cam[i].used) begin
                free_index = cam_idx_t'(i);
                break;
            end
        end
    end

    /* Index to propagate */
    cam_idx_t source_index;
    always_comb begin
        source_index = '0;
        for (int i = 0; i < CAM_SIZE; i++) begin
            if (is_in_idx[i]) begin
                source_index = cam_idx_t'(i);
                break;
            end
        end
    end

    /* CAM clear control generation */
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            clear_tick  <= '0;
            clear_index <= '0;
        end
        else if (in_state == IN_WRITE && selected_port == BR_LOCAL) begin
            clear_tick  <= tick_cnt_i + CLEAR_TICKS;
            clear_index <= free_index;
        end
    end

    /* Automatic clear trigger */
    logic can_clear;
    /**
     * @todo
     * SystemC uses clear_local instead of wrote_local
     * Probably SystemC implementation is wrong, as the original VHDL uses clear_local
     *
     * Also, SystemC is not verifying if cam is pending
     * Maybe the pending check can cause a dead line in CAM
     */
    assign can_clear = clear_local && in_state == IN_INIT && out_state == OUT_INIT && !cam[clear_index].pending;

    /* Local write signalizing */
    logic wrote_local;
    assign local_busy_o = wrote_local;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wrote_local <= 1'b0;
        end
        else begin
            if (in_state == IN_WRITE && selected_port == BR_LOCAL)
                wrote_local <= 1'b1;
            else if (can_clear)
                wrote_local <= 1'b0;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            clear_local <= 1'b0;
        end
        else begin
            if (can_clear)
                clear_local <= 1'b0;
            else if (wrote_local && tick_cnt_i >= clear_tick)
                clear_local <= 1'b1; // SystemC also unsets wrote_local
        end
    end

    /* CAM insertion and deletion control */
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (int i = 0; i < CAM_SIZE; i++) begin
                /* No need to zero the memory itself */
                cam[i].used <= 1'b0;
                cam[i].pending <= 1'b0;
            end
        end
        else begin
            case (in_state)
                IN_WRITE: begin
                    cam[free_index].data    <= flit_i[selected_port];
                    cam[free_index].origin  <= selected_port;
                    cam[free_index].used    <= 1'b1;
                    cam[free_index].pending <= 1'b1;
                end
                IN_CLEAR: begin
                    /**
                     * @todo
                     * Check if when ignoring pending line there is a possibility of not propagating a clear
                     * thus ending up with a 'dead' cam line
                     */
                    if (cam[source_index].data.service != BR_SVC_CLEAR && !cam[source_index].pending) begin
                        /* Avoid the insertion of clean in an already clean line */
                        cam[source_index].data.service <= BR_SVC_CLEAR;
                        cam[source_index].pending      <= 1'b1;
                    end
                end
                default: ;
            endcase

            case (out_state)
                OUT_ACK_ALL:   cam[selected_index].pending <= 1'b0;
                OUT_ACK_LOCAL: cam[selected_index].pending <= 1'b0;
                OUT_CLEAR:     cam[selected_index].used    <= 1'b0;
                default: ;
            endcase

            /* clear_local freezes both FSM */
            if (can_clear) begin
                cam[clear_index].data.service <= BR_SVC_CLEAR;
                cam[clear_index].pending      <= 1'b1;
            end
        end
    end

endmodule
