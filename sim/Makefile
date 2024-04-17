default: all

all: sim-vsim run-sort run-parser

sim-vsim:
	@vsim -c -do sim.do

run-sort:
	@./sortlog.py

run-parser: parser
	@./parser

parser: parser.c
	@$(CC) parser.c -o parser

clean:
	@rm -rf *.wlf transcript modelsim.ini work
	@rm -f wave.do
	@rm -f brNoC_log.txt
	@rm -f parser

.PHONY: default all sim-vsim run-sort run-parser parser clean
