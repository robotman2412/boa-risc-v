#!/usr/bin/env python3

def filter_tab(raw, tabsize=8):
    pos = 0
    out = ""
    for c in raw:
        if c == "\t":
            n    = tabsize - pos % tabsize
            out += " " * n
            pos += n
        else:
            out += c
            pos += 1
    return out

def readlines(file):
    fd = open(file, "r")
    out = []
    for line in fd.readlines():
        out += [filter_tab(line.strip())]
    fd.close()
    return out

def read(file):
    fd = open(file, "r")
    out = fd.read()
    fd.close()
    return out

def readwords(file):
    fd = open(file, "rb")
    data = fd.read()
    out = [0 for i in range((len(data)+3) // 4)]
    fd.close()
    for i in range(len(data)):
        out[i//4] |= data[i] << ((i & 3) * 8)
    return out

if __name__ == "__main__":
    # Read data
    insn_rvc        = readwords("obj_dir/insn_rvc.bin")
    insn            = readwords("obj_dir/insn.bin")
    decomp          = readwords("obj_dir/decomp.bin")
    insn_rvc_disas  = readlines("obj_dir/insn_rvc.asm")
    insn_disas      = readlines("obj_dir/insn.asm")
    decomp_disas    = readlines("obj_dir/decomp.asm")
    valid           = read     ("obj_dir/valid.txt")
    
    # Verify that all instructions are RVC.
    for i in range(len(insn_rvc)):
        if (insn_rvc[i] & 0x0000ffff) == 0:
            print("Non-RVC instruction at address 0x{:08x} (line {})".format(i*4, i))
            exit(1)
    if len(insn_rvc) != len(insn):
        print("Table length mismatch")
        exit(1)
    if len(insn_rvc_disas) != 2*len(insn_disas):
        print("Disassembly length mismatch")
        exit(1)
    
    # Format into a table.
    lines = [["COMP", "(asm)", "V", "DECOMP", "(asm)", "E", "EXPECTED", "(asm)"]]
    nv = 0
    ne = 0
    for i in range(len(insn_rvc)):
        lines += [[
            "{:04x}".format(insn_rvc[i]),
            insn_rvc_disas[i*2],
            valid[i],
            "{:08x}".format(decomp[i]),
            decomp_disas[i],
            "1" if decomp[i] == insn[i] else "0",
            "{:08x}".format(insn[i]),
            insn_disas[i]
        ]]
        nv += valid[i] == '0'
        ne += decomp[i] != insn[i]
    
    # Remove correct entries.
    if nv or ne:
        i = 1
        while i < len(lines):
            if lines[i][2] == "1" and lines[i][5] == "1":
                lines.remove(lines[i])
            else:
                i += 1
    else:
        print("All test cases passed")
        exit(0)
    
    width = [0, 0, 0, 0, 0, 0, 0, 0]
    for line in lines:
        for i in range(len(line)):
            width[i] = max(width[i], len(line[i]))
    
    # Print the table.
    for line in lines:
        tmp = ""
        for i in range(len(line)):
            tmp += "  " + line[i] + " " * (width[i] - len(line[i]))
        print(tmp)
    
    if nv:
        print("{} not valid".format(nv))
    if ne:
        print("{} not equal".format(ne))
