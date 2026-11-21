#!/usr/bin/env python3
"""Summarise DefCensus.lean output.   usage: python3 -I census_report.py OUTDIR > summary.md"""
import csv, os, sys
from collections import Counter, defaultdict

D = sys.argv[1] if len(sys.argv) > 1 else "analysis/kernel-recursion/out/census"
rd = lambda f: list(csv.DictReader(open(os.path.join(D, f), newline="")))
thms, edges, defs, ext = rd("census_theorems.csv"), rd("census_edges.csv"), rd("census_defs.csv"), rd("census_external.csv")

def lib(m):  # first two module components, e.g. Formalism.LocalToGlobal
    return ".".join(m.split(".")[:2])

nT = len(thms)
api = sum(int(t["api"]) for t in thms)
dyn = sum(int(t["dynamic"]) for t in thms)
withDyn = sum(1 for t in thms if int(t["dynamic"]) > 0)
withRemote = sum(1 for t in thms if int(t["dynamic_remote"]) > 0)
failed = sum(1 for t in thms if t["checked"] != "true")
use = Counter(e["use"] for e in edges)
loc = Counter(e["locality"] for e in edges)
useloc = Counter((e["use"], e["locality"]) for e in edges)

print("# Definition census: interface vs body use\n")
print(f"- owner theorems re-checked: **{nT}** (kernel re-check failures: {failed})")
print(f"- theorem→project-definition edges: **{api + dyn}**, of which interface-only **{api}** "
      f"({100*api/max(1,api+dyn):.1f}%) and body-dependent **{dyn}** ({100*dyn/max(1,api+dyn):.1f}%)")
print(f"- theorems with ≥1 body-dependent use: **{withDyn}** ({100*withDyn/max(1,nT):.1f}%); "
      f"with ≥1 *remote* body-dependent use: **{withRemote}** ({100*withRemote/max(1,nT):.1f}%)\n")
print("| body-dependent use | same-module | same-dir | remote | total |\n|---|---:|---:|---:|---:|")
for u in ["kernel", "eqn", "kernel+eqn"]:
    r = [useloc[(u, l)] for l in ("same-module", "same-dir", "remote")]
    print(f"| {u} | {r[0]} | {r[1]} | {r[2]} | {sum(r)} |")
print()

# breakdown by definition kind (type / pred / inst / value, ±abbrev)
print("## By kind of definition\n")
print("Body use of a `type` definition usually means the kernel looked through a type alias to find "
      "its structure (identifying the object); body use of a `value` or `pred` definition means the "
      "proof relied on what the function computes or what the predicate says.\n")
print("| definition kind | interface edges | body edges | of which remote | theorems with remote body use |\n|---|---:|---:|---:|---:|")
kindOf = {d["def"]: d["kind"] for d in defs}
apiK = Counter(); bodyK = Counter(); remK = Counter(); thmRemK = defaultdict(set)
for d in defs:
    apiK[d["kind"]] += int(d["api_uses"])
for e in edges:
    k = e["def_kind"]; bodyK[k] += 1
    if e["locality"] == "remote":
        remK[k] += 1; thmRemK[k].add(e["theorem"])
for k in sorted(set(apiK) | set(bodyK), key=lambda k: -(apiK[k] + bodyK[k])):
    print(f"| {k} | {apiK[k]} | {bodyK[k]} | {remK[k]} | {len(thmRemK[k])} |")
print()

dd = sorted(defs, key=lambda d: (-int(d["dynamic_remote_uses"]), -int(d["dynamic_uses"])))
print("## Definitions whose bodies are opened from other directories (top 30)\n")
print("| definition | defined in | kind | interface uses | body uses | remote body uses |\n|---|---|---|---:|---:|---:|")
for d in [d for d in dd if int(d["dynamic_remote_uses"]) > 0][:30]:
    print(f"| `{d['def']}` | `{d['module']}` | {d['kind']} | {d['api_uses']} | {d['dynamic_uses']} | {d['dynamic_remote_uses']} |")
print()

print("## `value`/`pred` definitions whose bodies are opened from other directories (top 30)\n")
print("| definition | defined in | kind | interface uses | body uses | remote body uses |\n|---|---|---|---:|---:|---:|")
for d in [d for d in dd if int(d["dynamic_remote_uses"]) > 0 and d["kind"].split("-")[0] in ("value", "pred")][:30]:
    print(f"| `{d['def']}` | `{d['module']}` | {d['kind']} | {d['api_uses']} | {d['dynamic_uses']} | {d['dynamic_remote_uses']} |")
print()

print("## Most-used definitions that are only ever used through their interface (top 20)\n")
print("| definition | defined in | interface uses |\n|---|---|---:|")
for d in sorted([d for d in defs if int(d["dynamic_uses"]) == 0], key=lambda d: -int(d["api_uses"]))[:20]:
    print(f"| `{d['def']}` | `{d['module']}` | {d['api_uses']} |")
print()

byLib = defaultdict(lambda: [0, 0])
for t in thms:
    byLib[lib(t["module"])][0] += int(t["api"]); byLib[lib(t["module"])][1] += int(t["dynamic"])
print("## By library area (theorem side)\n")
print("| area | interface edges | body edges | body share |\n|---|---:|---:|---:|")
for k, (a, b) in sorted(byLib.items(), key=lambda kv: -(kv[1][0] + kv[1][1]))[:20]:
    print(f"| `{k}` | {a} | {b} | {100*b/max(1,a+b):.1f}% |")
print()

print("## Remote body-dependent edges, by (theorem area → definition area)\n")
pairs = Counter((lib(e["thm_module"]), lib(e["def_module"])) for e in edges if e["locality"] == "remote")
print("| theorem area | definition area | edges |\n|---|---|---:|")
for (a, b), n in pairs.most_common(20):
    print(f"| `{a}` | `{b}` | {n} |")
print()

print("## Non-project definitions most unfolded by the kernel (top 20)\n")
print("| definition | module | kernel unfolds |\n|---|---|---:|")
for x in sorted(ext, key=lambda x: -int(x["kernel_unfolds_total"]))[:20]:
    print(f"| `{x['def']}` | `{x['module']}` | {x['kernel_unfolds_total']} |")
