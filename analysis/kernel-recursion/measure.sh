#!/usr/bin/env bash
# Per-file kernel measurements. Run from the project root after `lake build` of the
# targets' imports.   usage: analysis/kernel-recursion/measure.sh OUTDIR MODULE...
#
# For each module it re-elaborates the source file (imports come from .olean) in four
# configurations and keeps the logs:
#   full     : project settings (--tstack=400000) + profiler (per-decl "type checking" = kernel)
#   nokernel : same with debug.skipKernelTC=true  -> elaboration-only cost
#   defstack : default thread stack (no --tstack)  -> does anything overflow without it?
#   diag     : diagnostics=true                    -> kernel unfold counters
set -u
OUT=$1; shift
mkdir -p "$OUT"
HERE=$(cd "$(dirname "$0")" && pwd)
# leanOptions from lakefile.toml (lake build passes these; `lake env lean` does not)
OPTS=(-DautoImplicit=false -DrelaxedAutoImplicit=false -DmaxSynthPendingDepth=3 -DmaxHeartbeats=4000000)
run() { # name file extra-args...
  local tag=$1 f=$2; shift 2
  python3 -I "$HERE/timeit.py" timeout 3600 lake env lean "${OPTS[@]}" "$@" "$f" > "$OUT/$base.$tag.log" 2>&1
  tail -1 "$OUT/$base.$tag.log" | sed "s|^|$tag |"
}
for m in "$@"; do
  f="src/$(echo "$m" | tr . /).lean"
  base=$(echo "$m" | awk -F. '{print $NF}')
  echo "### $m"
  run full     "$f" --tstack=400000 -Dprofiler=true -Dprofiler.threshold=50
  run nokernel "$f" --tstack=400000 -Ddebug.skipKernelTC=true
  run defstack "$f"
  run diag     "$f" --tstack=400000 -Ddiagnostics=true -Ddiagnostics.threshold=500
done
