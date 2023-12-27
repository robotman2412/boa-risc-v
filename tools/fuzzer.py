#!/usr/bin/env python3

# Copyright © 2023, Julian Scheffers, see LICENSE for more information

import os, argparse, re, subprocess, tempfile, random

isa     = os.getenv("FUZ_ISA") or "rv32imc_zicsr"
abi     = "ilp32" if isa.lower().startswith("rv32") else "lp64"
cc      = os.getenv("FUZ_CC") or "riscv32-unknown-elf-gcc"
objdump = os.getenv("FUZ_OBJDUMP") or "riscv32-unknown-elf-objdump"

linkerfile = tempfile.NamedTemporaryFile(mode="w", suffix=".ld")
linkerfile.write("""
/* Copyright © 2023, Julian Scheffers, see LICENSE for more information */

PHDRS {
    codeseg   PT_LOAD;
}

SECTIONS {
    /DISCARD/ : { *(.note.gnu.build-id) }
    
    . = 0x10000;
    .text : AT(0) {
        *(.text)
    } :codeseg
}

ENTRY(_start)
""")
linkerfile.flush()



def rand_raw_insn(allow32 = True, allow16 = True):
    """Generate a random, valid or invalid, instruction."""
    if not allow16 or (allow32 and random.randint(0,1)):
        b = b"\x00\x00\x00\x00"
        while (b[0] & 3) != 3 or (b[0] & 0x1f) == 0x1f: b = random.randbytes(4)
        return b
    else:
        b = b"\x03\x00"
        while (b[0] & 3) == 3: b = random.randbytes(2)
        return b



def rand_insn(allow32 = True, allow16 = True):
    """Generate a random, valid or invalid, instruction."""
    res = disas(rand_raw_insn(allow32, allow16))[0]
    if res["valid"]: res["valid"] = asm(res["asm"])
    return res



def rand_valid(allow32 = True, allow16 = True):
    """Generate a random valid instruction."""
    while True:
        res = disas(rand_raw_insn(allow32, allow16))[0]
        if res["valid"] and asm(res["asm"]): return res



def rand_invalid(allow32 = True, allow16 = True):
    """Generate a random invalid instruction."""
    while True:
        res = disas(rand_raw_insn(allow32, allow16))[0]
        if not res["valid"] or not asm(res["asm"]):
            res["valid"] = False
            return res



def hexparse(raw):
    """Parse a hexadecimal string into a byte string."""
    if type(raw) != str: raise ValueError("Expected str, got " + repr(raw))
    if len(raw) & 1: raise ValueError("Invalid hexadecimal string: " + raw)
    out = []
    for i in range(0, len(raw), 2):
        out += [int(raw[i:i+2], 16)]
    return bytes(out)



def hexdump(raw, uppercase=False):
    """Dump a byte string to a hexadecimal string."""
    if type(raw) != bytes: raise ValueError("Expected bytes, got " + repr(raw))
    out = ""
    for c in raw:
        out += "{:02x}".format(c)
    return out.upper() if uppercase else out



def disas(raw):
    """Disassemble a stream of bytes."""
    # Put the raw data in a temporary file.
    tmp = tempfile.NamedTemporaryFile("wb")
    tmp.write(raw)
    tmp.flush()
    
    # Get objdump to disassemble it for us.
    res = subprocess.run([objdump, "-m", "riscv", "-b", "binary", "-D", tmp.name], stdout=subprocess.PIPE)
    if res.returncode != 0: raise ChildProcessError(objdump + " returned non-zero exit code " + res.returncode)
    tmp.close()
    raw = res.stdout.decode("ascii")
    
    # Find lines with instructions in them.
    out = []
    for line in raw.splitlines():
        m = re.match("^\\s*([0-9a-fA-F])+:\\s*([0-9a-fA-F]+)\\s*(.+?)(?:<(\w+)(?:\+(\w+))?>)?\\s*$", line)
        if not m: continue
        m1 = re.match("^([bBjJ].+?)0[xX]([0-9a-fA-F]+)$", m.group(3))
        if m1:
            if m1.group(2):
                n   = int(m1.group(2), 16)
                if n & (1 << 63):
                    n = (~n+1) & 0xffff_ffff_ffff_ffff
                    off = ".-{}".format(n)
                else:
                    off = ".+{}".format(n)
            else:
                off = "."
            out += [{
                "raw":   hexparse(m.group(2)),
                "asm":   m1.group(1) + off,
                "valid": True
            }]
        else:
            out += [{
                "raw":   hexparse(m.group(2)),
                "asm":   m.group(3),
                "valid": not m.group(3).startswith(".")
            }]
    return out



def asm(raw):
    """Assemble a single instruction at address 0."""
    global isa, abi, linkerfile
    
    # Write a simple assembly file.
    src = tempfile.NamedTemporaryFile(mode="w+", suffix=".S")
    src.write("""
    .text
    .global _start
    .option norelax
_start:
    """)
    src.write(raw)
    src.flush()
    
    # Compile it.
    elf = tempfile.NamedTemporaryFile("r+b", suffix=".elf")
    res = subprocess.run([cc, "-march="+isa, "-mabi="+abi, "-nostdinc", "-nodefaultlibs", "-nostartfiles", "-nostdlib", "-o", elf.name, src.name, "-T", linkerfile.name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # if res.returncode != 0: raise ChildProcessError(cc + " returned non-zero exit code " + res.returncode)
    src.close()
    elf.close()
    return res.returncode == 0



if __name__ == "__main__":
    # Parse arguments.
    parser = argparse.ArgumentParser(prog="fuzzer.py", description="RISC-V instruction fuzzer")
    parser.add_argument("--rvc",            help="Generate 16-bit and 32-bit instructions",       action="store_const", const=True, default=False)
    parser.add_argument("--only-rvc",       help="Generate only 16-bit instructions",             action="store_const", const=True, default=False)
    parser.add_argument("--valid",          help="Generate only valid instructions",              action="store_const", const=True, default=False)
    parser.add_argument("--invalid",        help="Generate only invalid instructions",            action="store_const", const=True, default=False)
    parser.add_argument("--isa",            help="The instruction set to adhere to",              action="store", default=isa)
    parser.add_argument("--binary",         help="Output instructions as binary data",            action="store_const", const=True, default=False)
    parser.add_argument("--asm-wrapper",    help="Put an INSN() wrapper around assembly",         action="store_const", const=True, default=False)
    parser.add_argument("count",            help="Number of instructions to generate",            nargs="?", default="1")
    parser.add_argument("outfile",          help="The file to output generated instruction to",   nargs="?", default="/proc/self/fd/1")
    args = parser.parse_args()
    isa  = args.isa
    abi  = "ilp32" if isa.lower().startswith("rv32") else "lp64"
    
    # Validate arguments.
    if args.valid and args.invalid:
        print("Error: Cannot specify both --valid and --invalid")
        exit(1)
    if args.rvc and args.only_rvc:
        print("Error: Cannot specify both --rvc and --only-rvc")
        exit(1)
    if args.binary and args.asm_wrapper:
        print("Error: cannot specify both --binary and --asm-wrapper")
        exit(1)
    count   = int(args.count)
    allow32 = not args.only_rvc
    allow16 = args.rvc or args.only_rvc
    
    # Generate instructions.
    if args.valid:
        out = [rand_valid(allow32, allow16) for _ in range(count)]
    elif args.invalid:
        out = [rand_invalid(allow32, allow16) for _ in range(count)]
    else:
        out = [rand_insn(allow32, allow16) for _ in range(count)]
    
    # Output instructions.
    if args.binary:
        fd = open(args.outfile, "wb")
        for insn in out: fd.write(insn["raw"])
        fd.flush()
        fd.close()
    elif args.asm_wrapper:
        fd = open(args.outfile, "w")
        for insn in out:
            if insn["valid"]:
                fd.write("VALID_INSN(\t" + insn["asm"] + ")\n")
            else:
                fd.write("INVALID_INSN(\t" + insn["asm"] + ")\n")
        fd.flush()
        fd.close()
    else:
        fd = open(args.outfile, "w")
        for insn in out: fd.write(insn["asm"] + "\n")
        fd.flush()
        fd.close()
