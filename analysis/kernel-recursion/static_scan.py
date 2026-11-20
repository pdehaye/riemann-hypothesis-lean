#!/usr/bin/env python3
"""Source-level scan for constructs that drive Lean kernel recursion / reduction.

Usage:  python3 -I analysis/kernel-recursion/static_scan.py [SRC_DIR] [OUT_DIR]

Writes OUT_DIR/static_scan.json (per-file counts + notable sites) and prints a summary.
This is a heuristic, text-level scan: it does not elaborate anything. Counts of
`decide`, `rfl`, recursors etc. are upper bounds on what the kernel actually has to
reduce, and the list of "notable sites" is meant to pick files for dynamic profiling.
"""
import json, os, re, sys
from collections import Counter, defaultdict
from multiprocessing import Pool

SRC = sys.argv[1] if len(sys.argv) > 1 else "src"
OUT = sys.argv[2] if len(sys.argv) > 2 else "analysis/kernel-recursion/out"

# Strip comments (line + nested block) and string literals, keeping line structure.
TOK = re.compile(r'/-|-/|--[^\n]*|"(?:\\.|[^"\\\n])*"|\n')
def strip(text):
    out, pos, depth = [], 0, 0
    for m in TOK.finditer(text):
        t = m.group()
        if depth == 0:
            out.append(text[pos:m.start()])
        if t == "\n":
            out.append("\n")
        elif t == "/-":
            depth += 1
        elif t == "-/":
            if depth: depth -= 1
            elif True: out.append(t)
        elif t.startswith("--"):
            pass
        elif depth == 0:
            out.append('""')
        pos = m.end()
    if depth == 0:
        out.append(text[pos:])
    return "".join(out)

PATTERNS = {
    # kernel evaluation of decision procedures
    "decide":            r"\bdecide\b",
    "by_decide":         r"\bby\s+decide\b",
    "decide_true_cfg":   r"\bdecide\s*:=\s*true\b",
    "native_decide":     r"\bnative_decide\b",
    "ofReduceBool":      r"\bofReduce(Bool|Nat)\b",
    "Decidable.decide":  r"\bDecidable\.decide\b",
    "deriving_DecEq":    r"deriving[^\n]*\bDecidableEq\b",
    "Decidable_inst":    r"\binstance\b[^\n:]*:\s*Decidable",
    # definitional-equality checks
    "rfl_term":          r":=\s*rfl\b",
    "by_rfl":            r"\bby\s+rfl\b",
    "exact_rfl":         r"\bexact\s+rfl\b",
    "Iff.rfl/HEq.rfl":   r"\b(Iff|HEq)\.rfl\b",
    "show_from_rfl":     r"\bfrom\s+rfl\b",
    "change":            r"\bchange\b",
    "unfold":            r"\bunfold\b",
    "delta":             r"\bdelta\b",
    # explicit recursors / recursion schemes
    "Nat.rec":           r"\bNat\.rec\b",
    "Nat.recOn":         r"\bNat\.(recOn|strongRecOn|strongRec|le_induction|decreasingInduction)\b",
    "other_.rec":        r"(?<![\w.])(?!Nat\.)[A-Z][\w.]*\.rec\b",
    "recOn/casesOn":     r"(?<![\w.])[\w.]+\.(recOn|casesOn)\b",
    "brecOn/below":      r"(?<![\w.])[\w.]+\.(brecOn|below|binductionOn)\b",
    "WellFounded.fix":   r"\bWellFounded\.fix\b",
    "termination_by":    r"\btermination_by\b",
    "decreasing_by":     r"\bdecreasing_by\b",
    "partial_def":       r"\bpartial\s+def\b",
    "unsafe":            r"\bunsafe\b",
    "implemented_by":    r"\bimplemented_by\b",
    "Nat.iterate":       r"\bNat\.iterate\b|\^\[",
    # transparency / kernel-facing attributes and commands
    "irreducible_def":   r"\birreducible_def\b",
    "@[irreducible]":    r"@\[[^\]]*\birreducible\b",
    "@[reducible]":      r"@\[[^\]]*\breducible\b",
    "seal/unseal":       r"\b(seal|unseal)\b",
    "addDecl":           r"\baddDecl\b",
    "Kernel_api":        r"\bLean\.Kernel\b|\bKernel\.(whnf|isDefEq)\b",
    "skipKernelTC":      r"\bskipKernelTC\b",
    "Meta.whnf":         r"\bwhnf[RD]?\b",
    # numerics the kernel may have to grind (GMP-accelerated only for Nat literals)
    "norm_num":          r"\bnorm_num\b",
    "Nat.Prime_lit":     r"\bNat\.Prime\s+\d{4,}\b",
    "big_literal":       r"(?<![\w.])\d{7,}(?![\w.])",
}
RX = {k: re.compile(v) for k, v in PATTERNS.items()}

OPT_RX = re.compile(r"set_option\s+([\w.]+)\s+(\S+)")
DECL_RX = re.compile(r"^(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|noncomputable|partial|nonrec)\s+)*"
                     r"(def|abbrev|theorem|lemma|instance|example)\s+([^\s:({\[]+)?", re.M)

def self_recursive_defs(stripped):
    """Heuristic: top-level `def`/`abbrev` whose (last name component) recurs in its body."""
    hits = []
    decls = list(DECL_RX.finditer(stripped))
    for idx, m in enumerate(decls):
        kind, name = m.group(1), m.group(2)
        if kind not in ("def", "abbrev") or not name:
            continue
        end = decls[idx + 1].start() if idx + 1 < len(decls) else len(stripped)
        block = stripped[m.end():end]
        # body starts after the first `:=` or first `|` pattern-match alternative
        k = min([p for p in (block.find(":="), block.find("\n  |"), block.find("\n|")) if p >= 0] or [-1])
        if k < 0: continue
        short = name.split(".")[-1]
        if re.search(r"(?<![\w.'])" + re.escape(short) + r"(?![\w'])", block[k:]):
            line = stripped.count("\n", 0, m.start()) + 1
            hits.append((name, line))
    return hits

NOTABLE_KEYS = ("Nat.Prime_lit", "big_literal", "native_decide", "ofReduceBool",
                "addDecl", "Kernel_api", "skipKernelTC", "WellFounded.fix",
                "partial_def", "unsafe", "implemented_by", "decide_true_cfg")
BIGNUM = re.compile(r"(?<![\w.])\d{4,}(?![\w.])")

def scan_file(path):
    try:
        raw = open(path, encoding="utf-8").read()
    except UnicodeDecodeError:
        raw = open(path, encoding="utf-8", errors="replace").read()
    s = strip(raw)
    rel = os.path.relpath(path, SRC)
    nlines = raw.count("\n") + 1
    c = Counter()
    for k, rx in RX.items():
        n = len(rx.findall(s))
        if n: c[k] = n
    file_opts, file_notable = [], []
    for i, ln in enumerate(s.split("\n"), 1):
        if "set_option" in ln:
            for m in OPT_RX.finditer(ln):
                file_opts.append((m.group(1), m.group(2), i))
        for k in NOTABLE_KEYS:
            if c.get(k) and RX[k].search(ln):
                file_notable.append((k, i, ln.strip()[:160]))
        # `decide` on a line mentioning a big numeral: a kernel-evaluation risk
        if c.get("decide") and RX["decide"].search(ln) and BIGNUM.search(ln):
            file_notable.append(("decide_with_big_numeral", i, ln.strip()[:160]))
    sr = self_recursive_defs(s)
    if sr: c["self_recursive_def"] = len(sr)
    c["lines"] = nlines
    return rel, nlines, c, file_opts, file_notable, sr

def main():
    files = []
    for root, _, fs in os.walk(SRC):
        for f in fs:
            if f.endswith(".lean"):
                files.append(os.path.join(root, f))
    files.sort()
    total = Counter()
    per_file = {}
    opts = defaultdict(list)          # option -> [(value, file, line)]
    notable = defaultdict(list)       # category -> [(file, line, snippet)]
    selfrec = []
    total_lines = 0
    with Pool(os.cpu_count()) as pool:
        results = pool.map(scan_file, files, chunksize=64)
    for rel, nlines, c, file_opts, file_notable, sr in results:
        total_lines += nlines
        for k, v, i in file_opts: opts[k].append((v, rel, i))
        for k, i, ln in file_notable: notable[k].append((rel, i, ln))
        selfrec += [(rel, ln, nm) for nm, ln in sr]
        per_file[rel] = dict(c)
        total.update(c)
    def num(v):
        try: return int(v)
        except ValueError: return None

    opt_summary = {}
    for k, vs in opts.items():
        vals = [num(v) for v, _, _ in vs]
        ints = sorted([x for x in vals if x is not None], reverse=True)
        opt_summary[k] = {
            "count": len(vs),
            "files": len({f for _, f, _ in vs}),
            "max": ints[0] if ints else None,
            "value_hist": Counter(v for v, _, _ in vs).most_common(12),
            "top_sites": sorted(vs, key=lambda t: -(num(t[0]) or 0))[:15],
        }

    def top(key, n=25):
        return sorted(((f, d[key]) for f, d in per_file.items() if d.get(key)),
                      key=lambda t: -t[1])[:n]

    # per-directory rollup (2 levels)
    rollup = defaultdict(Counter)
    for f, d in per_file.items():
        parts = f.split(os.sep)
        rollup[os.sep.join(parts[:2])].update(d)

    report = {
        "src": SRC, "files": len(files), "lines": total_lines,
        "totals": dict(total),
        "options": opt_summary,
        "top_files": {k: top(k) for k in PATTERNS if total.get(k)} | {"self_recursive_def": top("self_recursive_def")},
        "notable_sites": {k: v[:200] for k, v in notable.items()},
        "notable_counts": {k: len(v) for k, v in notable.items()},
        "self_recursive_defs": selfrec,
        "dir_rollup": {d: dict(c) for d, c in sorted(rollup.items(), key=lambda t: -t[1]["lines"])},
        "per_file": per_file,
    }
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "static_scan.json"), "w") as fh:
        json.dump(report, fh, indent=1)
    print(f"files={len(files)} lines={total_lines}")
    for k in sorted(total, key=lambda k: -total[k]):
        print(f"  {k:22s} {total[k]}")
    print("options:")
    for k, v in sorted(opt_summary.items(), key=lambda t: -t[1]["count"]):
        print(f"  {k:40s} n={v['count']:6d} files={v['files']:6d} max={v['max']}")
    print("notable:", {k: len(v) for k, v in notable.items()})

if __name__ == "__main__":
    main()
