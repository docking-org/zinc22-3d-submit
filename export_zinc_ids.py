import sys
import os

class Rangemap:

    def __init__(self, fn):

        with open(fn, 'r') as rangemap:
            self.rangevals = rangemap.read().split()

        self.map = {}
        self.invmap = {}
        for i, logp in enumerate(self.rangevals):
            self.map[logp] = i
            self.invmap[i] = logp

    def get(self, hlogp):
        h = int(hlogp[1:3])
        p = self.map[hlogp[3:]]
        return h, p

    def getinv(self, h, p):
        hlogp_str = "H{:>02d}{}".format(h, self.invmap[p])
        return hlogp_str

target_file=sys.argv[1]
rangemap=Rangemap("mp_range.txt")

def base62(n):
    digits="0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    b62_str=""
    while n >= 62:
        n, r = divmod(n, 62)
        b62_str += digits[r]
    b62_str += digits[n]
    return ''.join(reversed(b62_str))

with open(target_file, 'r') as smiles_file:

    for line in smiles_file:

        smiles, tranche, sub_id = line.split()

        h_bucket, logp_bucket = rangemap.get(tranche)

        b62_h = base62(h_bucket)
        b62_p = base62(logp_bucket)
        b62_sub = base62(int(sub_id))

        b62_sub = (10 - len(b62_sub)) * "0" + b62_sub

        zinc_id = "ZINC" + b62_h + b62_p + b62_sub

        assert(len(zinc_id) == 16)

        print(smiles + " " + zinc_id)