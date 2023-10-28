# BrLite

BrLite is a lightweight version of BrNoC, without backtracking.

## Testing

It is possible to simulate with Modelsim or Xcelium with the commands below inside [sim/](sim/):
```
make sim-vsim
make sim-xrun
```

The simulation parameters are present in [sim/scenario.sv](sim/scenario.sv).
Change the parameters `X_CNT` and `Y_CNT` to simulate.
In smaller NoCs, it may be necessary to remove the packet with origin in PE number 30,
and reducing the `NPKTS` to `28`.

The simulation produces a `sim/brNoC_log.txt`.
To understand more clearly, run the sort script with:
```
make run-sort
```

After sorting, it is possible to run the parser to view a summary of the results:
```
make run-parser
```

To run everything, simulating with Modelsim:
```
make
```

## Acknowledgements

* BrLite
```
Dalzotto, A. E., Borges, C. S., Ruaro, M., and Moraes, F. G. (2022). Non-intrusive Monitoring Framework for NoC-based Many-Cores. In Proceedings of the Brazilian Symposium on Computing Systems Engineering (SBESC), pages 1-7.
```

* BrNoC
```
Wachter, E., Caimi, L. L., Fochi, V., Munhoz, D., & Moraes, F. G. (2017). BrNoC: A broadcast NoC for control messages in many-core systems. Microelectronics Journal, 68:69-77.
```
