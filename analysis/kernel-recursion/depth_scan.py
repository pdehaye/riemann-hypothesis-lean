#!/usr/bin/env python3
"""Rank source files by syntactic features that tend to produce deep Expr trees
(and hence "deep recursion was detected" without a big --tstack).

Usage: python3 -I depth_scan.py [SRC] [OUT.tsv]

Per file (comments/strings stripped):
  nest     max bracket nesting depth  ( [ {
  litmax   max number of top-level commas inside one [...] / ![...] / {...} literal
  opchain  max count of binary operators (+ * - ∧ ∨ :: ++ ∪ ∩ •) in one
           bracket-balanced statement line run (long left-nested chains)
  seqmax   max number of `<;>` in a single tactic line (case explosion)
  linemax  longest line (chars)
  declmax  largest declaration (chars between top-level decl keywords)
"""
import os, re, sys
from multiprocessing import Pool
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from static_scan import strip  # noqa: E402

SRC = sys.argv[1] if len(sys.argv) > 1 else "src"
OUT = sys.argv[2] if len(sys.argv) > 2 else "analysis/kernel-recursion/out/depth_scan.tsv"
OPS = re.compile(r"(?<![<>=:|&])(\+\+|::|[+*∧∨∪∩•])(?![=>])|(?<=\s)-(?=\s)")
DECL = re.compile(r"^(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|noncomputable|partial)\s+)*"
                  r"(?:def|abbrev|theorem|lemma|instance|example)\b", re.M)

def scan(path):
    raw = open(path, encoding="utf-8", errors="replace").read()
    s = strip(raw)
    depth = nest = 0
    stack = []          # per open bracket: [kind, commas]
    litmax = 0
    for ch in s:
        if ch in "([{":
            depth += 1; nest = max(nest, depth); stack.append([ch, 0])
        elif ch in ")]}":
            if stack:
                k, c = stack.pop()
                if k in "[{": litmax = max(litmax, c)
            depth = max(0, depth - 1)
        elif ch == "," and stack:
            stack[-1][1] += 1
    opchain = cur = 0
    for ln in s.split("\n"):
        n = len(OPS.findall(ln))
        cur = cur + n if ln.startswith((" ", "\t")) and n else n
        opchain = max(opchain, cur)
    seqmax = max((ln.count("<;>") for ln in s.split("\n")), default=0)
    linemax = max((len(ln) for ln in raw.split("\n")), default=0)
    starts = [m.start() for m in DECL.finditer(s)] + [len(s)]
    declmax = max((b - a for a, b in zip(starts, starts[1:])), default=len(s))
    return (os.path.relpath(path, SRC), nest, litmax, opchain, seqmax, linemax, declmax, len(raw))

def main():
    files = [os.path.join(r, f) for r, _, fs in os.walk(SRC) for f in fs if f.endswith(".lean")]
    with Pool(os.cpu_count()) as p:
        rows = p.map(scan, files, chunksize=64)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as fh:
        fh.write("file\tnest\tlitmax\topchain\tseqmax\tlinemax\tdeclmax\tbytes\n")
        for r in sorted(rows):
            fh.write("\t".join(map(str, r)) + "\n")
    cols = ["nest", "litmax", "opchain", "seqmax", "linemax", "declmax"]
    for i, c in enumerate(cols, 1):
        print(f"== top by {c}")
        for r in sorted(rows, key=lambda r: -r[i])[:12]:
            print(f"  {r[i]:8d}  {r[0]}")

if __name__ == "__main__":
    main()
