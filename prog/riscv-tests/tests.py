#!/usr/bin/env python3

import subprocess, os



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
        print(res.stdout)
        print("Test " + test + " failed to configure")
        return False
    res = subprocess.run(["cmake", "--build", "build/"+test], stdout=subprocess.PIPE)
    if res.returncode != 0:
        print(res.stdout)
        print("Test " + test + " failed to build")
        return False
    return True



if __name__ == "__main__":
    tests = list_tests("tests.txt")
    for test in tests:
        compile_test(test)
