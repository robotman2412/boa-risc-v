#!/usr/bin/env python3

# Copyright © 2024, Julian Scheffers, see LICENSE for more information

import sys, math

def help():
    print("Usage: bin2rom.py <infile> <outfile> <data_bits>")
    exit(1)

if len(sys.argv) != 4:
    help()



infd  = open(sys.argv[1], "rb")
outfd = open(sys.argv[2], "w")
data_bits = int(sys.argv[3])
data_bytes = math.ceil(data_bits / 8)



raw   = infd.read()
infd.close()
depth = math.ceil(len(raw) / data_bytes)
data  = depth * [0]
for i in range(len(raw)):
    data[i//data_bytes] |= raw[i] << (i % data_bytes * 8)


for i in range(len(data)):
    outfd.write("{:x}{}".format(data[i], '' if i == len(data)-1 else ','))

outfd.close()

