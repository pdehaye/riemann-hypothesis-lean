#!/usr/bin/env bash
# Probe which files need more than a given thread stack.
# usage: analysis/kernel-recursion/stack_probe.sh OUTDIR "STACKS" MODULE...
#   STACKS: space-separated list of --tstack values in KiB, "default" = no flag
#           (Lean's default thread stack, 8 MiB here), e.g. "default 2048 1024".
# Imports must already be built. For each (module, stack) prints one line:
#   <stack> <rc> <wall> <first deep-recursion/overflow message or "ok">
set -u
OUT=$1; STACKS=$2; shift 2
mkdir -p "$OUT"
HERE=$(cd "$(dirname "$0")" && pwd)
OPTS=(-DautoImplicit=false -DrelaxedAutoImplicit=false -DmaxSynthPendingDepth=3 -DmaxHeartbeats=4000000)
for m in "$@"; do
  f="src/$(echo "$m" | tr . /).lean"
  base=$(echo "$m" | awk -F. '{print $NF}')
  for st in $STACKS; do
    A=(); [ "$st" != default ] && A=(--tstack="$st")
    log="$OUT/$base.$st.log"
    python3 -I "$HERE/timeit.py" timeout 3600 lake env lean "${OPTS[@]}" "${A[@]}" "$f" > "$log" 2>&1
    msg=$(grep -m1 -iE "deep recursion|stack overflow|Stack overflow detected" "$log" | cut -c1-200)
    stat=$(grep -m1 '^@@' "$log")
    echo "$m stack=$st ${stat#@@ } ${msg:-ok}"
  done
done
