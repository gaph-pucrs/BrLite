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

`include "BrLitePkg.sv"

module BrLiteRouter
    import BrLitePkg::*;
#(
    parameter logic [15:0] SEQ_ADDRESS = 0,
    parameter 			   CAM_SIZE    = 8,     /* Power of 2 */
    parameter 			   CLEAR_TICKS = 180    /* Up to 255  */
)
(
    input  logic 					 clk_i,
    input  logic 					 rst_ni,

    /* Router signals */
    output logic					 local_busy_o,

    /* Data inputs */
    input  br_data_t [(BR_NPORT - 1):0] flit_i,
    input  logic	 [(BR_NPORT - 1):0] req_i,
    output logic 	 [(BR_NPORT - 1):0] ack_o,

    /* Data outputs */
    output br_data_t [(BR_NPORT - 1):0] flit_o,
    output logic	 [(BR_NPORT - 1):0] req_o,
    input  logic	 [(BR_NPORT - 1):0] ack_i
);

////////////////////////////////////////////////////////////////////////////////
// Global signals
////////////////////////////////////////////////////////////////////////////////
    typedef struct packed {
        br_data_t data;
        br_port_t origin;
        logic cleared;
        logic used;
        logic pending;
    } cam_line_t;

    typedef logic [($clog2(CAM_SIZE) - 1):0] cam_idx_t;

    logic                         clear_local;
    cam_idx_t                     clear_index;
    cam_idx_t                     source_index;

    cam_line_t [(CAM_SIZE - 1):0] cam;

////////////////////////////////////////////////////////////////////////////////
// Input FSM
////////////////////////////////////////////////////////////////////////////////

    /* In FSM states */
    typedef enum logic [5:0] {
        IN_INIT        = 6'b000001, 
        IN_ARBITRATION = 6'b000010, 
        IN_TEST_SPACE  = 6'b000100, 
        IN_WRITE       = 6'b001000, 
        IN_CLEAR       = 6'b010000, 
        IN_ACK         = 6'b100000
    } in_fsm_t;

    in_fsm_t in_state;

    /* Input port selection */
    br_port_t selected_port;
    br_port_t next_port;

    /* Input port Arbitration (round-robin) */
    always_comb begin
        next_port = selected_port;
        for (int i = 0; i < BR_NPORT; i++) begin
            if (i <= selected_port)
                continue;

            if (req_i[i]) begin
                next_port = br_port_t'(i);
                break;
            end
        end

        if (next_port == selected_port) begin
            for (int i = 0; i < BR_NPORT; i++) begin
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
    logic [(CAM_SIZE - 1):0] is_in_idx;
    always_comb begin
        for (int i = 0; i < CAM_SIZE; i++) begin
            is_in_idx[i] = (
                (cam[i].data.seq_source == flit_i[selected_port].seq_source) 
                && (cam[i].data.id  == flit_i[selected_port].id)
                && (cam[i].used || cam[i].cleared)
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
                    (flit_i[selected_port].service != BR_SVC_CLEAR) 
                    && is_in_idx == '0
                ) begin
                    if (!cam_full) begin
                        in_next_state = IN_WRITE;
                    end
                    else begin
                        in_next_state = IN_INIT;
                        $display(
                            "[%7.3f] [BrLiteRouter] PE seq. %d with full CAM. Deadlock may occur.", 
                            $time()/1_000_000.0, 
                            SEQ_ADDRESS
                        );
                    end
                end
                else if (
                    is_in_idx != '0 
                    && flit_i[selected_port].service  == BR_SVC_CLEAR 
                    && cam[source_index].data.service != BR_SVC_CLEAR 
                    && !cam[source_index].pending
                ) begin
                    in_next_state = IN_CLEAR;
                end
                else begin
                    /* Ignore */
                    in_next_state = IN_ACK;
                end
            end
            IN_WRITE,
            IN_CLEAR:       in_next_state = IN_ACK;
            default:        in_next_state = IN_INIT;    /* IN_ACK */
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
    typedef enum logic [5:0] {
        OUT_INIT        = 6'b000001, 
        OUT_ARBITRATION = 6'b000010, 
        OUT_SERVICE     = 6'b000100, 
        OUT_PROPAGATE   = 6'b001000, 
        OUT_CLEAR       = 6'b010000, 
        OUT_ACK         = 6'b100000
    } out_fsm_t;

    out_fsm_t out_state;

    /* Line pending to transmit */
    logic [(CAM_SIZE - 1): 0] is_pending;
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

    logic propagate_all;
    assign propagate_all = (cam[selected_index].data.service == BR_SVC_ALL);

    logic propagate_clr;
    assign propagate_clr =  (cam[selected_index].data.service == BR_SVC_CLEAR);

    logic propagate_tgt;
    assign propagate_tgt = (cam[selected_index].data.seq_target != SEQ_ADDRESS);

    logic receive_tgt;
    assign receive_tgt = (
        cam[selected_index].data.service != BR_SVC_CLEAR && 
        cam[selected_index].data.seq_target == SEQ_ADDRESS
    );

    logic ack_ports;
    assign ack_ports = !(propagate_all || propagate_clr || propagate_tgt);

    logic ack_local;
    assign ack_local = !(propagate_all || receive_tgt);

    /* Ack input control */
    logic [(BR_NPORT - 1):0] acked_ports;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            acked_ports <= '0;
        end
        else begin
            case (out_state)
                OUT_PROPAGATE: begin
                    acked_ports[(BR_NPORT - 2):0]           <= {(BR_NPORT - 1){ack_ports}};
                    acked_ports[BR_LOCAL] 	                <= ack_local;
                    acked_ports[cam[selected_index].origin] <= 1'b1; /* Should be after LOCAL because ORIGIN can be local */
                end
                OUT_ACK:       acked_ports <= acked_ports | ack_i;
                default:       acked_ports <= '0;
            endcase
        end
    end

    /* Out FSM transition */
    out_fsm_t out_next_state;
    always_comb begin
        case (out_state)
            OUT_INIT:
                out_next_state = (is_pending != '0 && !clear_local) 
                    ? OUT_ARBITRATION 
                    : OUT_INIT;
            OUT_ARBITRATION: 
                out_next_state = OUT_SERVICE;
            OUT_SERVICE:     
                out_next_state = OUT_PROPAGATE;
            OUT_PROPAGATE:
                out_next_state = OUT_ACK;
            OUT_ACK: begin
                if (acked_ports == '1) begin
                    out_next_state = propagate_clr ? OUT_CLEAR : OUT_INIT;
                    // if (ack_local) begin
                    //     $display(
                    //         ">>>>>>>>>>>>>>>>> SEND LOCAL: [[%d %d]] %h %h Address: %d",
                    //         cam[selected_index].data.seq_source,
                    //         cam[selected_index].data.seq_target,
                    //         cam[selected_index].data.service,
                    //         cam[selected_index].data.payload,
                    //         SEQ_ADDRESS
                    //     );
                    // end
                end
                else begin
                    out_next_state = OUT_ACK;
                end
            end
            default:         out_next_state = OUT_INIT; /* OUT_CLEAR */
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
        case (out_state)
            OUT_ACK:     req_o = ~acked_ports;
            default:     req_o = '0;
        endcase
    end

    /* Clear report */
    // always_ff @(posedge clk_i or negedge rst_ni) begin
    //     if (rst_ni && out_state == OUT_CLEAR) begin
    //         if (cam[selected_index].data.seq_target == SEQ_ADDRESS && cam[selected_index].used) begin
    //             $display(
    //                 "************************************************************ end CLEAR: %d %d %x %x", 
    //                 cam[selected_index].data.seq_source,
    //                 cam[selected_index].data.seq_target,
    //                 cam[selected_index].data.service, 
    //                 cam[selected_index].data.payload
    //             );
    //         end
    //     end
    // end

    /* Output connection */
    always_comb begin
        for (int i = 0; i < BR_NPORT; i++)
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
    logic [7:0] clear_tick;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            clear_tick  <= '0;
        end
        else begin
            if (clear_tick != '0)
                clear_tick <= clear_tick + 1'b1;
            else if (in_state == IN_WRITE && selected_port == BR_LOCAL)
                clear_tick  <= (255 - CLEAR_TICKS);
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            clear_index <= '0;
        end
        else if (in_state == IN_WRITE && selected_port == BR_LOCAL) begin
            clear_index <= free_index;
        end
    end

    /* Automatic clear trigger */
    logic can_clear;
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
            else if (wrote_local && clear_tick == '0)
                clear_local <= 1'b1;
        end
    end

    /* CAM insertion and deletion control */
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (int i = 0; i < CAM_SIZE; i++) begin
                cam[i].cleared <= 1'b0;
                cam[i].used <= 1'b0;
                cam[i].pending <= 1'b0;
            end
        end
        else begin
            case (in_state)
                IN_WRITE: begin
                    cam[free_index].data    <= flit_i[selected_port];
                    cam[free_index].origin  <= selected_port;
                    cam[free_index].cleared <= 1'b0;
                    cam[free_index].used    <= 1'b1;
                    cam[free_index].pending <= 1'b1;
                end
                IN_CLEAR: begin
                        cam[source_index].data.service <= BR_SVC_CLEAR;
                        cam[source_index].pending      <= 1'b1;
                    end
                default: ;
            endcase

            case (out_state)
                OUT_ACK: begin
                    if (acked_ports == '1)
                        cam[selected_index].pending <= 1'b0;
                end
                OUT_CLEAR: begin
                    cam[selected_index].used    <= 1'b0;
                    cam[selected_index].cleared <= 1'b1;
                end
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
