default: all

all: sim-vsim run-sort

sim-vsim:
	@vsim -c -do sim.do

run-sort:
	@./sortlog.py

clean:
	@rm -rf *.wlf transcript modelsim.ini work
	@rm -f wave.do
	@rm -f brNoC_log.txt

.PHONY: default all sim-vsim run-sort run-parser parser clean
