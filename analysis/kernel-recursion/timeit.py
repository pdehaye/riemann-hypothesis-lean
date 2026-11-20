#!/usr/bin/env python3
"""Run a command, then print wall time, exit code and peak RSS of its process tree (to stderr)."""
import resource, subprocess, sys, time
t = time.monotonic()
rc = subprocess.call(sys.argv[1:])
dt = time.monotonic() - t
rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss  # KiB on Linux
print(f"@@ wall={dt:.2f}s rc={rc} maxrss={rss/1024:.0f}MiB", file=sys.stderr)
sys.exit(rc)
