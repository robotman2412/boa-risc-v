#!/usr/bin/env python3

import subprocess, os, sys
from pathlib import Path



def list_tests(file):
    out=[]
    fd = open(file, "r")
    
    lines = fd.readlines()
    
    for line in lines:
        line = line.strip()
        if not line.startswith("#") and len(line):
            out += [line]
    
    fd.close()
    return out



def compile_test(test):
    cc  = os.environ.get("CC",      "riscv32-unknown-elf-gcc")
    cp  = os.environ.get("OBJCOPY", "riscv32-unknown-elf-objcopy")
    isa = os.environ.get("ISA",     "rv32imac_zicsr_zifencei")
    abi = os.environ.get("ABI",     "ilp32")
    
    Path("build/"+test).parent.mkdir(parents=True, exist_ok=True)
    
    res = subprocess.run([cc, "-march="+isa, "-mabi="+abi, "-Iriscv-tests/env/p", "-Iriscv-tests/isa/macros/scalar", "-o", "build/"+test+".elf", test, "-nostartfiles", "-nodefaultlibs", "-nostdlib", "-Tlinker.ld"], stdout=subprocess.PIPE)
    if res.returncode != 0:
        sys.stdout.buffer.write(res.stdout)
        print("Test " + test + " failed to compile")
        return False
    
    res = subprocess.run([cp, "-O", "binary", "build/"+test+".elf", "build/"+test+".bin"], stdout=subprocess.PIPE)
    if res.returncode != 0:
        sys.stdout.buffer.write(res.stdout)
        print("Test " + test + " failed to create BIN")
        return False
    
    res = subprocess.run(["../../tools/bin2mem.py", "build/"+test+".bin", "build/"+test+".mem", "32"], stdout=subprocess.PIPE)
    if res.returncode != 0:
        sys.stdout.buffer.write(res.stdout)
        print("Test " + test + " failed to create MEM")
        return False
    
    return True



def run_test(test, debug=False):
    env = os.environ.copy()
    env["PROG"]=os.getcwd()+"/build/"+test+".mem"
    res = subprocess.run(["make", "run"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.returncode != 0:
        sys.stdout.buffer.write(res.stdout)
        sys.stdout.buffer.flush()
        if debug:
            subprocess.run(["make", "wave"], env=env)
        print("Test " + test + " failed")
        return False
    return True



if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "debug":
        debug = True
    elif len(sys.argv) == 1:
        debug = False
    else:
        print("tests.py [debug]")
    tests = list_tests("tests.txt")
    compiled = []
    notcomp = 0
    notrun  = 0
    for test in tests:
        print("Building test " + test)
        if compile_test(test):
            print("\033[1F\033[2K",end="")
            compiled += [test]
        else:
            notcomp += 1
    for test in compiled:
        print("Running test " + test)
        if run_test(test, debug):
            print("\033[1F\033[2K",end="")
        else:
            notrun += 1
    if notcomp:
        print("{} test{} failed to compile".format(notcomp, "s" if notcomp != 1 else ""))
    if notrun:
        print("{} test{} failed to run".format(notrun, "s" if notrun != 1 else ""))
    if not (notcomp or notrun):
        print("All tests passed")
    exit(notcomp != 0 or notrun != 0)
