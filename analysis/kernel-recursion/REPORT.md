# Kernel recursion in the RH Lean proof

Date: 2026-11-20. Toolchain `leanprover/lean4:v4.33.1`, Mathlib `0df444a3`. Machine: 4 cores, 15 GB RAM.

"Kernel recursion" has three meanings here. This report covers all three:

1. **Kernel evaluation.** Proofs whose checking makes the kernel *run* recursive definitions, such as `decide`, `decide +kernel` and `rfl` on closed computations.
2. **Recursion schemes.** How recursive definitions reach the kernel: recursors (`Nat.rec`, `List.rec`, …), structural recursion (`brecOn`/`below`), and well-founded recursion (`WellFounded.fix`).
3. **Recursion depth.** Native stack depth in the checker. The project passes `--tstack=400000` (a thread stack of about 400 MB).

## TL;DR

- **The kernel is never bypassed.** The code has 0 `native_decide`, `Lean.ofReduceBool`, `implemented_by`, `unsafe` or `debug.skipKernelTC`. Every computation is checked by the kernel itself.
- **Real computation in the kernel happens through 151 `decide +kernel` calls in 34 files.** A handful of them run recursive Boolean checkers over many iterations: prime tables, Chebyshev-type bounds, and Lucas primality certificates. The largest is a structurally recursive loop of **131,070 iterations** (`ChebyshevPrimeBounds/SmallLoop.lean`), which costs **37 s of kernel time** and **655k `Nat.rec` unfoldings**.
- **These kernel computations dominate the build time of the files they appear in** (62–87% of wall time). They are cheap to isolate, because each depends only on Mathlib and at most a few project files.
- **None of the measured files needs the large stack.** Every one of the 10 measured targets passes with the default stack, including the 131k-iteration loop. A variant without the `force` trick (step 4) also stays within the default stack. So `--tstack` must be needed somewhere else in the tree. Finding where would require building more of the tree with the default stack (see "Next steps").
- **Main theorem coverage.** `Supplements.Kernels.MainTheorems` transitively imports 175,128 of the 175,187 source files. Essentially every kernel computation below lies on the path to the main theorem.

## (a) Static analysis

Tools:
- `static_scan.py`: a text-level scan of `src/` with comments and strings stripped. It takes about 4 minutes on 4 cores.
- `RecursionScan.lean`: an environment-level scan of built `.olean` files.

Outputs:
- `out/static_summary.txt`
- `out/static_scan_summary.json` (the full per-file JSON is regenerated locally and git-ignored)
- `out/decide_kernel_sites.csv`
- `out/recursion_scan_targets.csv`

### Size

175,187 files, 17.55 M lines.

### Constructs that make the kernel compute

| construct | count | comment |
|---|---:|---|
| `decide +kernel` | **151** in 34 files | Skips the elaborator's check; the kernel evaluates `Decidable.decide p` directly. All heavy computation goes through this path. |
| `by decide` | 6,054 | Almost all tiny: `Fin 2`, small `Finset` identities, `absurd h (by decide)` |
| `decide` on a line with a ≥4-digit numeral | 411 | Mostly modular-exponentiation facts, e.g. `34 ^ 96 % 413718278401 = …` in `SpanPowerMembership/Primes.lean`. The kernel computes these with GMP-accelerated `Nat` operations. |
| `simp (config := {decide := true})` | 26 | |
| `:= rfl` / `by rfl` / `exact rfl` | 43,040 / 494 / 47 | Definitional-equality checks. Mostly unfolding definitions, not computation. |
| `Iff.rfl`/`HEq.rfl`, `from rfl` | 7,379 / 6,810 | |
| `unfold` / `change` / `delta` | 112,002 / 52,378 / 2,539 | Elaborator-side. These lead to definitional-equality checks in the kernel. |
| `norm_num` | 26,839 | Produces certificates the kernel checks cheaply. This includes 13 `Nat.Prime <literal>` facts up to `Nat.Prime 763521676554817`. |
| `native_decide`, `ofReduceBool`, `implemented_by`, `unsafe`, `skipKernelTC` | **0** | |

### Recursion schemes in the source

| construct | count | comment |
|---|---:|---|
| `Nat.rec` used directly | 339 | Mostly `noncomputable` sequence constructions (`fun n => Nat.rec x₀ (fun _ s => g s) n`), concentrated in `Development/AbelianVarietyTheory/Proofs/DivisorProofs` and `InertiaEigenvalues`. They are proof devices, not evaluated. |
| `Nat.recOn`, `Nat.strongRec*`, `Nat.le_induction`, … | 534 | |
| other `X.rec` | 374 | |
| `brecOn` / `below` mentioned explicitly | 192 | |
| `termination_by` / `decreasing_by` | 20 / 19 | Well-founded recursion. The kernel can only reduce it by unfolding `Acc` proofs, and none of it is evaluated by `decide`. |
| `WellFounded.fix` used explicitly | 1 | `rw [WellFounded.fix_eq]` in `RankLevelDatumIdempotentEqOfSameShape.lean` |
| `partial def` | 2 | Both in metaprograms, which run in the elaborator, not the kernel |
| self-recursive `def` (heuristic) | ~2,740 | Noisy: it also counts a name that merely reappears in its own body |

### Options related to recursion and transparency

| option | sites | max | comment |
|---|---:|---:|---|
| `maxRecDepth` | 34 in 22 files | 1,000,000 | The maximum is `ColFormsInst.lean:25` (`norm_num` proving `Nat.Prime 14145788201`). Most others are 20,000–100,000. This limit applies to the elaborator, not the kernel. |
| `maxHeartbeats` | 57,556 in 54,080 files | 64,000,000 | The most common value is 1,000,000 (50,873 sites) |
| `synthInstance.maxHeartbeats` | 7,381 | 1,000,000 | |
| `backward.isDefEq.respectTransparency` | 1,879 (+87 `.types`) | | |
| `allowUnsafeReducibility` | 37 | | Changes reducibility attributes after the fact. This only affects the elaborator's view; the kernel ignores reducibility. |
| `smartUnfolding false` | 3 | | |

### Code that talks to the kernel directly

- `Formalism/LocalToGlobal/NumberFieldFamilies/OwnStruct.lean:11` calls `Kernel.isDefEq` from a tactic (`kdefeq`), using the kernel as an oracle for definitional equality during elaboration.
- `Formalism/HermitianCurvature/HermitianCurvatureProofs/CutCptCopy.lean` uses `addDecl` to re-add a dependency cone of declarations under new names (`…Cpt`), with constants substituted. These declarations are re-checked by the kernel.

### Environment-level scan (`RecursionScan.lean`, built targets only)

The scan covered 467 declarations in the 21 built target modules:
- Maximum proof-term depth is 142 (`GlobalTheory.CuspGL.sep_numerical_ineq`).
- There are 157 `of_decide_eq_true`/`_false` applications, each the elaborated form of a `decide` proof.
- 6 definitions are compiled via `brecOn` (structural recursion).
- The largest `Nat` literal is 1,185 bits.

The heavy `decide +kernel` proofs are *small* terms. Their cost is all in evaluation, so term-size metrics cannot predict kernel time. The unfolding counters in (b) can.

## (b) Dynamic measurements

The setup:
- Built with `lake build` over the 21 small-closure targets: 195 s wall, 10.3 GB peak, Mathlib from cache.
- Each target file was then re-checked by `measure.sh` in four configurations: full (project settings plus profiler), `debug.skipKernelTC=true`, default stack, and `diagnostics=true`.
- Logs are in `out/measure/`. "kernel" means the profiler's *type checking* category.

| file | full wall | kernel | no-kernel wall | default stack | top kernel unfoldings |
|---|---:|---:|---:|---|---|
| `ChebyshevPrimeBounds/SmallLoop` | 42.9 s | **37.2 s** | 5.7 s | ok | `Nat.rec` 655k, `Nat.casesOn` 524k, `Pow.pow` 524k, `force` 393k, `loop._f` 131k |
| `InvFiveLogLeSumInvPrimes` | 32.5 s | **20.2 s** (`table_ok` 19.5 s) | 12.3 s | ok | `Bool.casesOn` 722k, `Bool.rec` 603k, `Decidable.casesOn` 374k |
| `IRRPrimeRecipSum` | 31.2 s | **24.7 s** (one decl 23.3 s) | 10.9 s | ok | `Bool.rec` 748k, `and` 598k |
| `DyadicPrimeIntervals/Run1` (Run2–4 similar) | 20.2 s | **14.5 s** | 5.6 s | ok | `Bool.casesOn` 278k, `Decidable.casesOn` 180k |
| `MinorOrderedEntries` | 10.3 s | 0.65 s | 9.4 s | ok | `Int.casesOn` ≈1k |
| `PsiUpperBoundOfLtThirtyMulSixPow` | 7.8 s | 0.21 s | 7.9 s | ok | `List.rec` 1.8k |
| `SpanPowerMembership/Primes` (115-digit Lucas prime) | 7.2 s | 0.85 s | 6.1 s | ok | `Decidable.casesOn` 6.7k, `Nat.rec` 2k |
| `Eisenstein4CoeffBound` (`bernoulli 4/6` by `decide +kernel`) | 5.3 s | 0.15 s | 4.9 s | ok | `Int.casesOn` 3.4k |
| `RankLevelDatumIdempotentEqOfSameShape` (`WellFounded.fix_eq`) | 5.7 s | 0.12 s | 5.5 s | ok | `List.rec` 1.1k |
| `FlagDeg` (`maxRecDepth 4000`) | 5.2 s | 0.12 s | 5.3 s | ok | – |

About 3.5 s of every run is importing Mathlib.

Observations:

- **The four kernel-heavy files** (`SmallLoop`, `Run1–4`, `InvFive…`, `IRRPrimeRecipSum`) spend 62–87% of their wall time in a single kernel check. Run2–4 each built in 21–23 s. Together these files cost about 2.3 minutes of kernel time (≈140 s), which is negligible against a 17 M-line build but clearly visible locally.
- **The 115-digit prime is cheap (0.85 s).** The Lucas certificate pushes all the work into GMP-backed `Nat` literal arithmetic (`Nat.pow`, `Nat.mod`), which the kernel performs natively instead of by unfolding.
- **No file needs `--tstack`.** Every default-stack run finished with the same result and timing.

### Experiment: what does `force` buy?

The loops in `SmallLoop.lean` and `DyadicPrimeIntervals/SmallLoop.lean` wrap every argument in

```lean
def force (x : Nat) (f : Nat → Bool) : Bool := match x with | 0 => f 0 | k + 1 => f (k + 1)
```

so the kernel must reduce `x` to a numeral before continuing. Without it, the arguments would build up as unevaluated expressions such as `((0+1)+1)+…`. `experiments/` contains copies of the loop with and without `force`, at 2k, 8k and 32k iterations, run with the default stack and with the large one. Results are in `out/experiments/summary.txt`.

| iterations | with `force` | without `force` |
|---:|---:|---:|
| 2,000 | 0.41 s | 0.27 s |
| 8,000 | 2.28 s | 1.84 s |
| 32,000 | **8.59 s** | **13.2 s** |

No run overflowed the default stack. The kernel's whnf cache and its GMP literal extension keep the unevaluated arguments from blowing up the stack. `force` is therefore a *performance* device: it pays off from about 10k iterations up, which matters at the 131,070 iterations actually used. It is not a stack-depth fix.

## Where is `--tstack=400000` needed? (search so far)

Lean prints *"deep recursion was detected at '…' (potential solution: increase elaboration stack size using the `lean --tstack` flag)"* when a thread runs out of stack. The default thread stack is 8 MiB. The project sets 400 MB. To find files that actually need more than the default, I checked each candidate group below with the default stack. I either re-checked single files with `stack_probe.sh`, or ran a full `lake build` of a module's import chain with `--tstack` temporarily removed from `lakefile.toml` (local edit, never committed). With the second method every module in the chain is checked with the default stack.

| candidate group | why suspected | modules checked with default stack | failures |
|---|---|---:|---:|
| kernel-heavy `decide +kernel` files (step b) | long kernel evaluations | 10 | 0 |
| 33 files with the most extreme syntax (`depth_scan.py`): operator chains up to 1,979 terms, 299-element list literals, 730 KB declarations, nesting depth 19 | deep `Expr` trees | 33 | 0 |
| tier 1: files with `maxRecDepth` raised and import chains ≤ 226 modules (`PlaceSumSquares` = 240-term prime sum, `PermChar` = `decide`, `BaseInst`, `CrystallineComparison/*`, `FlagDeg`), **full import chains** | the author hit recursion limits here | 429 | 0 |
| tier 2: `ColFormsInst` (`maxRecDepth 1000000`), `InertiaEigenvalues/{ExistsNeSame,TwistDataAgreeAcrossCoefficients}` (`maxRecDepth 100000`), **full import chains** | same | 322 | 0 |
| **total** | | **751 unique project modules** (≈ 140k lines) | **0** |

Calibration: the probe does detect stack exhaustion. `InvFiveLogLeSumInvPrimes` fails at ≤ 1 MiB ("Stack overflow detected") and passes at 2 MiB. Below 256 KiB, Mathlib's own initialisation fails ("deep recursion … at 'interpreter'"). The 131k-iteration kernel loop passes even at 512 KiB.

Conclusions so far:
- **Kernel evaluation, large literals, long polynomial identities and the `maxRecDepth` sites do not need the big stack.** `maxRecDepth` limits a Lean-level recursion counter, which is a different resource from the native stack.
- The remaining suspects all sit on import chains of 140k–400k lines that have not been built yet:
  1. `CutMainCpt.lean:945` runs the project command `cpt_copy_thms`. Its helper `go` (`CutCptCopy.lean`) is a **non-tail-recursive `partial def` doing a depth-first walk over the dependency graph of `Formalism.*` declarations**, executed by the *interpreter*. Its recursion depth equals the longest dependency chain, which is a textbook source of "deep recursion at 'interpreter'". Import chain: 1,601 modules, ≈ 395k new lines.
  2. 50 files using the project tactic `kexactB`, which calls `Kernel.isDefEq` from the elaborator (`OwnStruct.lean`). The cheapest is `AutomorphicMembership/ECure.lean`, ≈ 142k new lines, which also sets `smartUnfolding false`.
  3. The `maxRecDepth` files on very large import chains (`IwasawaDecomposition/*`, `E8ActionRelativelyAmple`, 1k–15k modules).
- Another possibility: `--tstack` is not needed at all with this toolchain. The author may have added it under an earlier Lean version, or for a step that was later rewritten.

## Interface vs body census ("kinematic" vs "dynamic" use of definitions)

Tool: `DefCensus.lean`, summarised by `census_report.py`; output in `out/census/` (`summary.md`, CSVs).

**What it measures.** For every project theorem it re-checks the proof in the kernel with unfold diagnostics on. Auxiliary lemmas, such as the one holding a `decide +kernel` proof, and private names are merged into their user-level owner. For each project definition the theorem mentions, it then records one of three outcomes:
- **interface only**: mentioned but never opened;
- **kernel**: the kernel had to unfold the body;
- **eqn**: used through an equation lemma (`d.eq_def`, `d.eq_N`).

Each body use is tagged by where the definition lives relative to the theorem: same module, same directory, or remote.

Definitions are classified by what they return:
- `type`: returns a `Sort`;
- `pred`: returns `Prop`;
- `inst`: instance, or returns a class;
- `value`: anything else.

An `-abbrev` suffix marks reducible definitions. Body use of a `type` alias usually just identifies the carrier of a structure (kinematic). Body use of a `value` or `pred` means the proof relied on what the definition computes or says (dynamic).

**Scope.** 11,624 theorems from the ≈ 800 project modules built so far (≈ 5% of the tree, not the main theorem's full cone). Runtime: 283 s, peak 12.5 GB.

| definition kind | interface edges | body edges | of which remote | theorems with remote body use |
|---|---:|---:|---:|---:|
| value | 10,419 | 10,167 | 3,932 | 1,848 |
| type-abbrev | 413 | 5,936 | 2,307 | 1,100 |
| pred | 2,270 | 2,342 | 1,678 | 970 |
| inst | 1,675 | 1,730 | 472 | 141 |
| value-abbrev | 1,050 | 863 | 251 | 215 |
| type | 1,190 | 230 | 62 | 41 |

Findings:
- **Body use is the norm, not the exception.** Overall, 55.6% of theorem→definition edges open the body, and 57.6% of theorems open at least one project definition. Even excluding `type` aliases and instances, value/pred definitions are opened about as often as they are used through their interface (≈ 12.5k body vs 12.7k interface edges).
- **Proofs work by definitional unfolding, not by equation lemmas.** Only 487 body edges go through `eq_def`/`eq_N`, against 20,869 kernel unfoldings. `unfold`, `show`, `change` and `rfl` on non-recursive definitions leave a definitional cast that the kernel resolves by unfolding. This matches the static counts (112k `unfold`, 52k `change`, 43k `:= rfl`).
- **Dynamic use concentrates at the statement layer.** Of the 5,878 *remote* body uses of value/pred definitions, **3,292 (56%) open definitions that live in `*Statement*` modules.** The project defines its notions where the intermediate theorems are stated, and proofs elsewhere work with those definitions by unfolding them rather than through a lemma API. The most-opened examples are `Formalism.UG.bc`, `Formalism.HermitianLatticesTheory.locS`/`realize`/`gmap`, `Formalism.HN.zl`/`IsLat`, `Formalism.F.rk` and `Formalism.TwoAdicCyclotomicDecomposition.IsLayer`.
- **Frobenius-named definitions:**
  - The period-ring Frobenii (`Reformulated.AutPerF.{Ainf,Acris,Bcris}.frob`) are opened mostly *locally*: 2–3 remote body uses each.
  - `Formalism.FrobeniusOrbits` is opened remotely, but almost entirely through its type aliases `G0`, `HGrp`, `GG` (178 / 91 / 34 remote uses). Its value-level definitions are opened remotely much less: `c0` 23, `hostE` 17, `HostHyp` 12.
  - This census cannot tell which of these uses encode the *arithmetic* role of Frobenius, as opposed to bookkeeping.

Caveats:
- The kernel's lazy unfolding heuristics sometimes unfold a definition that a smarter check would avoid, so "kernel" edges are an upper bound on what is logically needed.
- Unfolding of non-project (Mathlib/core) definitions is recorded separately in `out/census/census_external.csv`.

## Reproducing

```bash
# (a) static
python3 -I analysis/kernel-recursion/static_scan.py src analysis/kernel-recursion/out
# (b) build targets, then measure
lake exe cache get
lake build Formalism.PeriodIntegrals.UnitaryGroupMassFormula.ChebyshevPrimeBounds.SmallLoop   # etc.
analysis/kernel-recursion/measure.sh analysis/kernel-recursion/out/measure <Module>...
# interface-vs-body census of built modules (call lean directly; `lake env` adds minutes of overhead)
LEAN_PATH=$(lake env printenv LEAN_PATH) lean --run analysis/kernel-recursion/DefCensus.lean OUTDIR <Module>...
python3 -I analysis/kernel-recursion/census_report.py OUTDIR > OUTDIR/summary.md
# environment scan of built modules
lake env lean --tstack=400000 --run analysis/kernel-recursion/RecursionScan.lean out.csv <Prefix,...> <Module>...
```

## Next steps

1. **Find out where `--tstack` is actually needed.** Build progressively larger closures with the default stack and record the first stack overflow, if any. Good candidates:
   - files using `maxRecDepth 100000` (e.g. `InertiaEigenvalues/*`);
   - `CyclotomicIsCyclotomicExtension` (27 `decide +kernel`, 791-module closure);
   - `ColFormsInst` (`maxRecDepth 1000000`, 423 modules).

   The overflow may be in the elaborator rather than the kernel. The log says which.
2. **Measure the remaining `decide +kernel` files**, whose closures span 50–1,164 modules (`out/decide_kernel_sites.csv`).
3. **Replay independently.** Export the environment with `lean4export` and replay it in `leanchecker`, nanoda or lean4lean, recording recursion depth per declaration. That gives kernel stack depth directly, without relying on Lean's own profiler.
4. **Run `RecursionScan.lean` on the full environment** after a full build, to get the complete recursor-use map.
