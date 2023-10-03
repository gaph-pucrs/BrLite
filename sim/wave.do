onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/ADDRESS}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/clk_i}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/rst_ni}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/tick_cnt_i}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/local_busy_o}
add wave -noupdate -expand -subitemconfig {{/testbench/noc/genblk1[0]/genblk1[4]/Router/flit_i[4]} -expand} {/testbench/noc/genblk1[0]/genblk1[4]/Router/flit_i}
add wave -noupdate -expand {/testbench/noc/genblk1[0]/genblk1[4]/Router/req_i}
add wave -noupdate -expand {/testbench/noc/genblk1[0]/genblk1[4]/Router/ack_o}
add wave -noupdate -expand {/testbench/noc/genblk1[0]/genblk1[4]/Router/flit_o}
add wave -noupdate -expand {/testbench/noc/genblk1[0]/genblk1[4]/Router/req_o}
add wave -noupdate -expand {/testbench/noc/genblk1[0]/genblk1[4]/Router/ack_i}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/clear_local}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/clear_index}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/clear_tick}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/cam}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/in_state}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/selected_port}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/next_port}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/is_in_idx}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/cam_full}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/in_next_state}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/out_state}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/is_pending}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/selected_index}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/next_index}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/acked_ports}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/out_next_state}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/free_index}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/source_index}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/can_clear}
add wave -noupdate {/testbench/noc/genblk1[0]/genblk1[4]/Router/wrote_local}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {85 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {10 ns} {434 ns}
