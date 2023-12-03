vlib work

vlog black_hole_hexROM.v

vsim -L altera_mf_ver black_hole_hexROM

log {/*}
add wave -unsigned {/*}

#Test Case 1: read out ALL data
force -freeze {clock} 1 0, 0 {5 ps} -r 10

force {address[16:0]} 'd0
force -freeze {address[0]} 1 0, 0 {1 ps} -r 2
force -freeze {address[1]} 1 0, 0 {2 ps} -r 4
force -freeze {address[2]} 1 0, 0 {4 ps} -r 8
force -freeze {address[3]} 1 0, 0 {8 ps} -r 16
force -freeze {address[4]} 1 0, 0 {16 ps} -r 32
force -freeze {address[5]} 1 0, 0 {32 ps} -r 64
force -freeze {address[6]} 1 0, 0 {64 ps} -r 128
force -freeze {address[7]} 1 0, 0 {128 ps} -r 256
force -freeze {address[8]} 1 0, 0 {256 ps} -r 512
force -freeze {address[9]} 1 0, 0 {512 ps} -r 1024
force -freeze {address[10]} 1 0, 0 {1024 ps} -r 2048
force -freeze {address[11]} 1 0, 0 {2048 ps} -r 4096
force -freeze {address[12]} 1 0, 0 {4096 ps} -r 8192
force -freeze {address[13]} 1 0, 0 {8192 ps} -r 16384
force -freeze {address[14]} 1 0, 0 {16384 ps} -r 32768
force -freeze {address[15]} 1 0, 0 {32768 ps} -r 65536
force -freeze {address[16]} 1 0, 0 {65536 ps} -r 131072

run 150000ps