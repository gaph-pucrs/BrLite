#! /bin/env python3

class Record:
    def __init__(self, service, pe, origin, payload, time):
        self._service = service
        self._pe = pe
        self._origin = origin
        self._payload = payload
        self._time = time
    
    def __str__(self):
        return "{} {}   from: {}  {:02X}  t:{}".format(self._service, self._pe, self._origin, self._payload, self._time)
    
    def __lt__(self, other):
        if self._pe == other._pe:
            return self._time < other._time
        else:
            return self._pe < other._pe

lines = []

with open("brNoC_log.txt", "r") as f:
    lines = f.readlines()

records = []

for line in lines:
    tokens = line.split()
    records.append(Record(tokens[0], int(tokens[1]), int(tokens[3]), int(tokens[4], 16), int(tokens[6])))

records.sort()

with open("brNoC_log.txt", "w") as f:
    last = 0
    for line in records:
        current = int(str(line).split()[1])
        if last != current:
            f.write("\n")

        f.write(str(line)+"\n")
        last = current
