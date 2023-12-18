#!/usr/bin/env python3

import subprocess, os, sys



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
    print("Building test " + test)
    
    env = os.environ.copy()
    env["TEST_PATH"]=test
    res = subprocess.run(["cmake", "-Bbuild/"+test], env=env, stdout=subprocess.PIPE)
    if res.returncode != 0:
        sys.stdout.buffer.write(res.stdout)
        print("Test " + test + " failed to configure")
        return False
    
    res = subprocess.run(["cmake", "--build", "build/"+test], stdout=subprocess.PIPE)
    if res.returncode != 0:
        sys.stdout.buffer.write(res.stdout)
        print("Test " + test + " failed to build")
        return False
    
    res = subprocess.run(["riscv32-unknown-elf-objcopy", "-O", "binary", "build/"+test+"/rom.elf", "build/"+test+"/rom.bin"])
    if res.returncode != 0:
        sys.stdout.buffer.write(res.stdout)
        print("Test " + test + " failed to create BIN")
        return False
    
    res = subprocess.run(["../../tools/bin2mem.py", "build/"+test+"/rom.bin", "build/"+test+"/rom.mem", "32"])
    if res.returncode != 0:
        sys.stdout.buffer.write(res.stdout)
        print("Test " + test + " failed to create MEM")
        return False
    
    return True



def run_test(test, debug=False):
    print("Running test " + test)
    
    env = os.environ.copy()
    env["PROG"]=os.getcwd()+"/build/"+test+"/rom.mem"
    res = subprocess.run(["make", "-C", "../../sim/dev", "wave" if debug else "run"], env=env)
    if res.returncode != 0:
        print("Simulator failure")
        exit(1)



if __name__ == "__main__":
    tests = list_tests("tests.txt")
    compiled = []
    for test in tests:
        if compile_test(test):
            compiled += [test]
    for test in compiled:
        run_test(test)
