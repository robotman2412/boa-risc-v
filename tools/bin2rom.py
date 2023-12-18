#!/usr/bin/env python3

# Copyright © 2023, Julian Scheffers, see LICENSE for more information

import sys, math

def help():
    print("Usage: bin2rom.py <infile> <outfile> <rom_id> <data_bits>")
    exit(1)

if len(sys.argv) != 5:
    help()



infd  = open(sys.argv[1], "rb")
outfd = open(sys.argv[2], "w")
rom_id = sys.argv[3]
data_bits = int(sys.argv[4])
data_bytes = math.ceil(data_bits / 8)



raw   = infd.read()
infd.close()
depth = math.ceil(len(raw) / data_bytes)
data  = depth * [0]
for i in range(len(raw)):
    data[i//data_bytes] |= raw[i] << (i % data_bytes * 8)


outfd.write("    localparam {}_len = {};\n".format(rom_id, depth))
outfd.write("    wire[{}:0] {}[{}:0];\n".format(data_bits-1, rom_id, depth-1))
for i in range(len(data)):
    outfd.write("    assign {}[{}] = {}'h{:x};\n".format(rom_id, i, data_bits, data[i]))

outfd.close()

