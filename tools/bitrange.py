#!/usr/bin/env python3

# Copyright © 2023, Julian Scheffers, see LICENSE for more information

import sys, re



class Mapping:
    def __init__(self, raw: dict|str):
        self.multimap = []
        if type(raw) == dict:
            self.map = raw
        elif type(raw) == str:
            self.map = {}
            self._parse(raw)
        else:
            raise ValueError("Expected dict or str, got " + str(type(raw)))
        self._gen_multimap()
    
    def _parse(self, raw: str):
        if len(raw) == 0 or raw[0] not in '0123456789':
            raise ValueError("Broken format")
        tmp = []
        while len(raw):
            m   = re.match("[|,]?([0-9]+)(?::([0-9]+))?", raw)
            if not m: raise ValueError("Broken format")
            raw = raw[m.end():]
            if m.group(2):
                tmp += range(int(m.group(1)), int(m.group(2))-1, -1)
            else:
                tmp += [int(m.group(1))]
        for i in range(len(tmp)):
            self.map[len(tmp)-1-i] = tmp[i]
    
    def _gen_multimap(self):
        self.multimap = []
        si = min(self.map)
        so = self.map[si]
        for i in range(min(self.map)+1, max(self.map)+2):
            if si != None and (i not in self.map or self.map[i] != so+i-si):
                self.multimap = [(si,so,i-si)] + self.multimap
                si = None; so = None
            if si == None and i in self.map:
                si = i
                so = self.map[si]
    
    def __repr__(self) -> str:
        out = ""
        for i in range(len(self.multimap)-1,-1,-1):
            if self.multimap[i][2] == 1:
                out += "{} -> {}".format(self.multimap[i][0], self.multimap[i][1])
            else:
                out += "{}:{} -> {}:{}".format(self.multimap[i][0]+self.multimap[i][2]-1, self.multimap[i][0], self.multimap[i][1]+self.multimap[i][2]-1, self.multimap[i][1])
            if i > 0:
                out += ",  "
        return "Mapping{" + out + "}"
    
    def invert(self):
        tmp = {}
        for s in self.map:
            tmp[self.map[s]] = s
        return Mapping(tmp)
    
    def _apply(self, getter, setter):
        for i in self.map:
            tmp = getter(i)
            if tmp != None:
                setter(self.map[i], tmp)
    
    def apply(self, to):
        if type(to) == int:
            tmp = 0
            def getter(s): return (to >> s) & 1
            def setter(d, v): nonlocal tmp; tmp |= v << d
            self._apply(getter, setter)
            return tmp
        elif type(to) == Mapping:
            to = to.invert()
            tmp = {}
            def getter(s): return to.map[s] if s in to.map else None
            def setter(d, v): nonlocal tmp; tmp[d]=v
            self._apply(getter, setter)
            return Mapping(tmp).invert()
        else:
            raise TypeError("Cannot apply mapping to type " + str(type(to)))



if __name__ == "__main__":
    if len(sys.argv) < 2:
        exit(1)
    cur = Mapping(sys.argv[1])
    printed = False
    for i in range(2, len(sys.argv)):
        if sys.argv[i] == "inv" or sys.argv[i] == "invert":
            cur = cur.invert()
        elif sys.argv[i] == "concat":
            mm  = cur.invert().multimap
            p   = mm[0][0]+mm[0][2]
            tmp = ""
            for m in mm:
                if p > m[0]+m[2]:
                    tmp += ", {}'bz".format(p-m[0]-m[2])
                if m[2] == 1:
                    tmp += ", in[{}]".format(m[1])
                else:
                    tmp += ", in[{}:{}]".format(m[1]+m[2]-1, m[1])
                p = m[0]
            if p > 0:
                tmp += ", {}'bz".format(p)
            tmp = tmp[2:]
            print("{" + tmp + "}")
            printed = True
        elif sys.argv[i] == "assign":
            for m in cur.invert().multimap:
                if m[2] == 1:
                    print("out[{}] = in[{}];".format(m[0], m[1]))
                else:
                    print("out[{}:{}] = in[{}:{}];".format(m[0]+m[2]-1, m[0], m[1]+m[2]-1, m[1]))
            printed = True
        elif sys.argv[i] == "show":
            print(cur)
            printed = True
        else:
            cur = Mapping(sys.argv[i]).apply(cur)
    if not printed: print(cur)
