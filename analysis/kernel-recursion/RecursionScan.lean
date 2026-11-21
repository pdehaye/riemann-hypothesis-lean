/-
Environment-level scan for kernel-recursion drivers (step 3 of the analysis plan).

Run from the project root, after the modules you want to inspect are built:

  lake env lean --run analysis/kernel-recursion/RecursionScan.lean OUT.csv PREFIXES MODULE...

  PREFIXES  comma-separated root namespaces / module roots to report on
            (e.g. `Formalism,Development`); declarations are kept when the module
            that defines them starts with one of these.
  MODULE    modules to import (their whole closure is loaded).

For each kept declaration it records (from the elaborated term the kernel checked):
  * `objs`       : number of distinct Expr objects (DAG size, with sharing)
  * `depth`      : true term depth (memoised over shared subterms)
  * `consts`     : number of constant occurrences
  * `rec`        : occurrences of recursors (`*.rec`, any `ConstantInfo.recInfo`)
  * `casesOn`/`recOn`/`brecOn`/`below` : auxiliary recursion schemes
  * `wf`         : `WellFounded.fix`/`fixF`/`Acc.rec` (well-founded recursion; the
                   kernel can only reduce these by unfolding `Acc` proofs, which is slow)
  * `decideK`    : `of_decide_eq_true` / `of_decide_eq_false` applications — the exact
                   elaborated shape of a `decide` proof, which the kernel must evaluate
  * `ofReduce`   : `Lean.ofReduceBool` / `Lean.ofReduceNat` (native evaluation, trusted)
  * `natLitMax`  : bit-length of the largest `Nat` literal (kernel uses GMP for these)
  * `wfDef`      : 1 if the declaration is a definition compiled via well-founded recursion
  * `strDef`     : 1 if the definition's body uses `brecOn` (structural recursion)
-/
import Lean
open Lean

structure KRow where
  name : Name
  module : Name
  kind : String
  objs : Nat := 0
  depth : Nat := 0
  consts : Nat := 0
  n_rec : Nat := 0
  n_casesOn : Nat := 0
  n_recOn : Nat := 0
  n_brecOn : Nat := 0
  n_below : Nat := 0
  wf : Nat := 0
  decideK : Nat := 0
  ofReduce : Nat := 0
  natLitMax : Nat := 0
  wfDef : Nat := 0
  strDef : Nat := 0

def KRow.header : String :=
  "name,module,kind,objs,depth,consts,rec,casesOn,recOn,brecOn,below,wf,decideK,ofReduce,natLitMax,wfDef,strDef"

def KRow.csv (r : KRow) : String :=
  s!"\"{r.name}\",{r.module},{r.kind},{r.objs},{r.depth},{r.consts},{r.n_rec},{r.n_casesOn},{r.n_recOn},{r.n_brecOn},{r.n_below},{r.wf},{r.decideK},{r.ofReduce},{r.natLitMax},{r.wfDef},{r.strDef}"

/-- Depth of an `Expr`, memoised on pointer identity so shared DAGs stay linear. -/
partial def depthOf (e : Expr) : StateM (Std.HashMap Expr Nat) Nat := do
  let key := e
  if let some d := (← get)[key]? then return d
  let d ← match e with
    | .app f a        => return 1 + max (← depthOf f) (← depthOf a)
    | .lam _ t b _    => return 1 + max (← depthOf t) (← depthOf b)
    | .forallE _ t b _=> return 1 + max (← depthOf t) (← depthOf b)
    | .letE _ t v b _ => return 1 + max (max (← depthOf t) (← depthOf v)) (← depthOf b)
    | .mdata _ b      => depthOf b
    | .proj _ _ b     => return 1 + (← depthOf b)
    | _               => return 1
  modify (·.insert key d)
  return d

def lastStr (n : Name) : String :=
  match n with
  | .str _ s => s
  | _ => ""

/-- Visit each node once (pointer-memoised) and tally constants and literals. -/
partial def tally (env : Environment) (e : Expr) : StateT (KRow × Std.HashSet Expr) IO Unit := do
  let key := e
  if (← get).2.contains key then return
  modify fun (r, s) => (r, s.insert key)
  let bump (f : KRow → KRow) : StateT (KRow × Std.HashSet Expr) IO Unit := modify fun (r, s) => (f r, s)
  match e with
  | .const c _ =>
    bump fun r => { r with consts := r.consts + 1 }
    let s := lastStr c
    match env.find? c with
    | some (.recInfo _) => bump fun r => { r with n_rec := r.n_rec + 1 }
    | _ => pure ()
    if s == "casesOn" then bump fun r => { r with n_casesOn := r.n_casesOn + 1 }
    if s == "recOn"   then bump fun r => { r with n_recOn := r.n_recOn + 1 }
    if s == "brecOn" || s == "binductionOn" then bump fun r => { r with n_brecOn := r.n_brecOn + 1 }
    if s == "below"   then bump fun r => { r with n_below := r.n_below + 1 }
    if c == ``WellFounded.fix || c == ``WellFounded.fixF || c == ``Acc.rec || c == ``WellFounded.fix_eq then
      bump fun r => { r with wf := r.wf + 1 }
    if c == ``of_decide_eq_true || c == ``of_decide_eq_false then
      bump fun r => { r with decideK := r.decideK + 1 }
    if c == ``Lean.ofReduceBool || c == ``Lean.ofReduceNat then
      bump fun r => { r with ofReduce := r.ofReduce + 1 }
  | .lit (.natVal n) => bump fun r => { r with natLitMax := max r.natLitMax n.log2.succ }
  | .app f a        => tally env f; tally env a
  | .lam _ t b _    => tally env t; tally env b
  | .forallE _ t b _=> tally env t; tally env b
  | .letE _ t v b _ => tally env t; tally env v; tally env b
  | .mdata _ b      => tally env b
  | .proj _ _ b     => tally env b
  | _ => pure ()

def kindOf : ConstantInfo → String
  | .thmInfo _ => "thm" | .defnInfo _ => "def" | .opaqueInfo _ => "opaque"
  | .axiomInfo _ => "axiom" | .inductInfo _ => "induct" | .ctorInfo _ => "ctor"
  | .recInfo _ => "rec" | .quotInfo _ => "quot"

def scanConst (env : Environment) (mod : Name) (ci : ConstantInfo) : IO KRow := do
  let mut r : KRow := { name := ci.name, module := mod, kind := kindOf ci }
  let some v := ci.value? (allowOpaque := true) | return r
  let e := mkApp ci.type v      -- type and value are both kernel-checked
  r := { r with objs := ← e.numObjs, depth := (depthOf e |>.run' {}) }
  let (_, (r', _)) ← (tally env e).run (r, {})
  r := r'
  if ci matches .defnInfo _ then
    if r.wf > 0 then r := { r with wfDef := 1 }
    if r.n_brecOn > 0 then r := { r with strDef := 1 }
  return r

def main (args : List String) : IO UInt32 := do
  let out :: prefixes :: mods := args
    | IO.eprintln "usage: RecursionScan OUT.csv PREFIX[,PREFIX...] MODULE..."; return 1
  let prefixes := (prefixes.splitOn ",").map String.toName
  initSearchPath (← findSysroot)
  let env ← importModules (mods.toArray.map ({ module := ·.toName })) {} (loadExts := false)
  let modNames := env.header.moduleNames
  let keep (m : Name) := prefixes.any (·.isPrefixOf m)
  let h ← IO.FS.Handle.mk out .write
  h.putStrLn KRow.header
  let mut n := 0
  let mut tot : KRow := { name := `total, module := `total, kind := "total" }
  let mut deepest : Array KRow := #[]
  for (c, ci) in env.constants.map₁.toList do
    let some idx := env.getModuleIdxFor? c | continue
    let mod := modNames[idx.toNat]!
    unless keep mod do continue
    if c.isInternalDetail && !(lastStr c).startsWith "_proof" then continue
    let r ← scanConst env mod ci
    h.putStrLn r.csv
    n := n + 1
    tot := { tot with objs := tot.objs + r.objs, consts := tot.consts + r.consts, n_rec := tot.n_rec + r.n_rec,
                      n_casesOn := tot.n_casesOn + r.n_casesOn, n_recOn := tot.n_recOn + r.n_recOn,
                      n_brecOn := tot.n_brecOn + r.n_brecOn, n_below := tot.n_below + r.n_below, wf := tot.wf + r.wf,
                      decideK := tot.decideK + r.decideK, ofReduce := tot.ofReduce + r.ofReduce,
                      natLitMax := max tot.natLitMax r.natLitMax, wfDef := tot.wfDef + r.wfDef,
                      strDef := tot.strDef + r.strDef, depth := max tot.depth r.depth }
    deepest := (deepest.push r).qsort (fun a b => a.depth > b.depth) |>.extract 0 10
  h.flush
  IO.println s!"declarations scanned: {n}"
  IO.println KRow.header
  IO.println tot.csv
  IO.println "deepest terms:"
  for r in deepest do IO.println s!"  depth={r.depth} objs={r.objs} {r.name}"
  return 0
