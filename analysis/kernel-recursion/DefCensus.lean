/-
Interface-vs-body census of definition use ("kinematic" vs "dynamic" use).

For every project theorem in the loaded environment, decide for each *project
definition* it mentions whether the proof needs only the definition's interface
(its name/type and lemmas about it) or its body:

  kernel  : the kernel had to delta-unfold the definition while re-checking the
            theorem (measured: the theorem is re-added under a fresh name with
            kernel diagnostics enabled, and the unfold counters are read back);
  eqn     : the proof term uses an equation lemma of the definition
            (`d.eq_def`, `d.eq_<n>`, `d.eq_unfold`), which is how `unfold d`,
            `simp [d]`, `rw [d]` appear after elaboration — the kernel never
            unfolds `d` itself in that case;
  api     : mentioned (type or proof) but neither of the above.

Body-dependent ("dynamic") = kernel ∪ eqn. Each dynamic edge is tagged by locality:
same module / same directory / remote.

Run from the project root once the modules are built:

  lake env lean --run analysis/kernel-recursion/DefCensus.lean OUTDIR MODULE...

Writes OUTDIR/census_edges.csv   (theorem, def, kind, locality, unfold count)
       OUTDIR/census_theorems.csv (per theorem totals)
       OUTDIR/census_defs.csv     (per definition totals)
       OUTDIR/census_external.csv (non-project definitions unfolded by the kernel, totals)
and prints a summary.
-/
import Lean
open Lean

/-- Root namespaces of the project's modules (lakefile `lean_lib` roots). -/
def projectRoots : List Name :=
  [`BuildAid, `CompanionTheory, `Development, `Formalism, `GroundTheory, `Lemmata,
   `PositivityTheory, `ReciprocityTheory, `Supplements, `Main, `Statements]

def isProjectModule (m : Name) : Bool := projectRoots.any (·.isPrefixOf m)

/-- `d.eq_def`, `d.eq_3`, `d.eq_unfold` ↦ `d`. -/
def eqnTarget? : Name → Option Name
  | .str p s =>
    if s == "eq_def" || s == "eq_unfold" || (s.startsWith "eq_" && (s.drop 3).all Char.isDigit && s.length > 3)
    then some p else none
  | _ => none

/-- Coarse kind of a definition by what it returns:
`type` (returns a `Sort`), `pred` (returns `Prop`), `inst` (instance, or returns a class),
`value` (anything else: functions and terms). Suffix `-abbrev` if reducible. -/
def classify (env : Environment) (classes insts : NameSet) (n : Name) (ty : Expr) : String :=
  let tgt := ty.getForallBody
  let base :=
    if insts.contains n then "inst"
    else match tgt with
      | .sort .zero => "pred"
      | .sort _ => "type"
      | _ => match tgt.getAppFn with
        | .const c _ => if classes.contains c then "inst" else "value"
        | _ => "value"
  if getReducibilityStatusCore env n == .reducible then base ++ "-abbrev" else base

/-- Project definitions worth reporting: user-level `def`s/instances, not auxiliary machinery. -/
def defKind? (env : Environment) (classes insts : NameSet) (modOf : Name → Option Name) (n : Name) : Option String :=
  match env.find? n with
  | some (.defnInfo d) =>
    match modOf n with
    | some m =>
      if !isProjectModule m then none
      else if (privateToUserName n).isInternalDetail || env.isProjectionFn n || Meta.isMatcherCore env n
           || isAuxRecursor env n || isNoConfusion env n then none
      else some (classify env classes insts n d.type)
    | none => none
  | _ => none

/-- Strip privacy and auxiliary suffixes (`_proof_3`, `proof_1`, `match_2`, numeric parts):
`_private.M.0.Foo.bar._proof_1_1` ↦ `Foo.bar`. Auxiliary lemmas (e.g. the one holding a
`decide +kernel` proof) are attributed to this owner. -/
def ownerOf (n : Name) : Name :=
  let isAux (c : Name) : Bool := match c with
    | .str _ s => s.startsWith "_" || s.startsWith "proof_" || s.startsWith "match_"
    | .num _ _ => true
    | .anonymous => false
  -- components from the root; keep the longest prefix with no auxiliary component
  let comps := (privateToUserName n).components
  (comps.takeWhile (fun c => !isAux c)).foldl (fun acc c => acc ++ c) .anonymous

def dirOf (m : Name) : Name := m.getPrefix

def locality (tm dm : Name) : String :=
  if tm == dm then "same-module" else if dirOf tm == dirOf dm then "same-dir" else "remote"

structure ThmResult where
  thm : Name
  mod : Name
  ok : Bool
  unfolds : Array (Name × Nat)     -- all kernel unfold counters
  used : Array Name                -- constants used in type+value
  deriving Inhabited

def checkOne (kenv : Kernel.Environment) (env : Environment) (modOf : Name → Option Name)
    (n : Name) : ThmResult :=
  match env.find? n with
  | some (.thmInfo t) =>
    let mod := (modOf n).getD .anonymous
    let used := t.type.getUsedConstants ++ t.value.getUsedConstants
    let decl := Declaration.thmDecl { t with name := n ++ `_census_copy }
    let kenv := (kenv.enableDiag true).resetDiag
    match Kernel.Environment.addDeclCore kenv 0 1000000 decl none with
    | .ok kenv' =>
      let d := kenv'.getDiagnostics
      { thm := n, mod, ok := true, used,
        unfolds := d.unfoldCounter.foldl (fun acc k v => acc.push (k, v)) #[] }
    | .error _ => { thm := n, mod, ok := false, used, unfolds := #[] }
  | _ => { thm := n, mod := .anonymous, ok := false, used := #[], unfolds := #[] }

def csvq (s : String) : String := "\"" ++ s.replace "\"" "\"\"" ++ "\""

def main (args : List String) : IO UInt32 := do
  let out :: mods := args
    | IO.eprintln "usage: DefCensus OUTDIR MODULE..."; return 1
  initSearchPath (← findSysroot)
  IO.FS.createDirAll out
  let env ← importModules (mods.toArray.map ({ module := ·.toName })) {} (loadExts := false)
  let modNames := env.header.moduleNames
  let modOf (n : Name) : Option Name := (env.getModuleIdxFor? n).map (modNames[·.toNat]!)
  -- class / instance tables read from each module's stored extension entries
  -- (extensions are not initialised by `importModules (loadExts := false)`)
  let mut classes : NameSet := {}
  let mut insts : NameSet := {}
  for i in [0:modNames.size] do
    for e in classExtension.getModuleEntries env i do classes := classes.insert e.name
    for e in Meta.instanceExtension.ext.getModuleEntries env i do
      let ie : Meta.InstanceEntry := match e with | .global a => a | .scoped _ a => a
      if let some g := ie.globalName? then insts := insts.insert g
  -- project theorems (skip auxiliary proof_/eq_ lemmas generated by Lean)
  let mut thms : Array Name := #[]
  for (n, ci) in env.constants.map₁.toList do
    if let .thmInfo _ := ci then
      if let some m := modOf n then
        if isProjectModule m && (eqnTarget? n).isNone && (eqnTarget? (ownerOf n)).isNone then
          thms := thms.push n
  IO.println s!"project theorems to re-check: {thms.size}"
  let kenv := env.toKernelEnv
  -- re-check in parallel chunks
  let nTasks := 4
  let chunk := (thms.size + nTasks - 1) / nTasks
  let tasks := (List.range nTasks).map fun i =>
    Task.spawn (prio := .dedicated) fun _ =>
      (thms.extract (i * chunk) ((i + 1) * chunk)).map (checkOne kenv env modOf)
  let raw := (tasks.map Task.get).foldl (· ++ ·) #[]
  -- merge auxiliary lemmas into their owner theorem (owner resolved privately or publicly)
  let resolve (o : Name) : Option Name :=
    if (env.find? o).isSome then some o else
    -- private owner: look it up among re-checked decls with the same user name
    none
  let mut merged : Std.HashMap Name ThmResult := {}
  let mut order : Array Name := #[]
  for r in raw do
    let o := ownerOf r.thm
    let key := (resolve o).getD o
    match merged[key]? with
    | some m =>
      merged := merged.insert key { m with ok := m.ok && r.ok, unfolds := m.unfolds ++ r.unfolds, used := m.used ++ r.used }
    | none =>
      merged := merged.insert key { r with thm := key }; order := order.push key
  -- keep owners that are theorems (drop aux lemmas of definitions, e.g. termination proofs)
  let isThmOwner (k : Name) : Bool :=
    match env.find? k with
    | some (.thmInfo _) => true
    | some _ => false
    | none => true   -- private theorem: user name not in env; keep
  let results := order.filter isThmOwner |>.map (merged[·]!)
  IO.println s!"declarations re-checked: {raw.size}, owner theorems: {results.size}"
  -- tallies
  let hE ← IO.FS.Handle.mk (out ++ "/census_edges.csv") .write
  hE.putStrLn "theorem,thm_module,def,def_kind,def_module,use,locality,unfolds"
  let hT ← IO.FS.Handle.mk (out ++ "/census_theorems.csv") .write
  hT.putStrLn "theorem,module,checked,api,eqn,kernel,dynamic,dynamic_remote,unfolds_total"
  let mut defApi : Std.HashMap Name Nat := {}
  let mut defDyn : Std.HashMap Name Nat := {}
  let mut defDynRemote : Std.HashMap Name Nat := {}
  let mut ext : Std.HashMap Name Nat := {}
  let mut totEdges : Std.HashMap String Nat := {}
  let mut failed := 0
  for r in results do
    unless r.ok do failed := failed + 1
    let unf : Std.HashMap Name Nat := r.unfolds.foldl (fun m (k, v) => m.insert k (m.getD k 0 + v)) {}
    -- external (non-project) definitions unfolded by the kernel
    for (k, v) in r.unfolds do
      if (modOf k).map isProjectModule != some true then
        ext := ext.insert k (ext.getD k 0 + v)
    -- candidate project definitions: mentioned, unfolded, or reached via an equation lemma
    let eqnDefs : Std.HashSet Name := r.used.foldl (fun s c => (eqnTarget? c).map s.insert |>.getD s) {}
    let mentioned : Std.HashSet Name := r.used.foldl (·.insert ·) {}
    let mut cands : Std.HashSet Name := {}
    for c in r.used do cands := cands.insert c
    for (k, _) in r.unfolds do cands := cands.insert k
    for c in eqnDefs do cands := cands.insert c
    let mut nApi := 0; let mut nEqn := 0; let mut nKer := 0; let mut nDyn := 0; let mut nDynR := 0
    let mut uTot := 0
    for d in cands do
      let some kind := defKind? env classes insts modOf d | continue
      if ownerOf d == r.thm then continue
      let dm := (modOf d).getD .anonymous
      let k := unf.getD d 0
      let isEqn := eqnDefs.contains d
      let use := if k > 0 && isEqn then "kernel+eqn" else if k > 0 then "kernel"
                 else if isEqn then "eqn" else if mentioned.contains d then "api" else "none"
      if use == "none" then continue
      let loc := locality r.mod dm
      totEdges := totEdges.insert (use ++ "/" ++ loc) (totEdges.getD (use ++ "/" ++ loc) 0 + 1)
      uTot := uTot + k
      if use == "api" then
        nApi := nApi + 1; defApi := defApi.insert d (defApi.getD d 0 + 1)
      else
        if isEqn then nEqn := nEqn + 1
        if k > 0 then nKer := nKer + 1
        nDyn := nDyn + 1; defDyn := defDyn.insert d (defDyn.getD d 0 + 1)
        if loc == "remote" then
          nDynR := nDynR + 1; defDynRemote := defDynRemote.insert d (defDynRemote.getD d 0 + 1)
        hE.putStrLn s!"{csvq r.thm.toString},{r.mod},{csvq d.toString},{kind},{dm},{use},{loc},{k}"
    hT.putStrLn s!"{csvq r.thm.toString},{r.mod},{r.ok},{nApi},{nEqn},{nKer},{nDyn},{nDynR},{uTot}"
  hE.flush; hT.flush
  let hD ← IO.FS.Handle.mk (out ++ "/census_defs.csv") .write
  hD.putStrLn "def,module,kind,api_uses,dynamic_uses,dynamic_remote_uses"
  let mut allDefs : Std.HashSet Name := {}
  for (d, _) in defApi.toList do allDefs := allDefs.insert d
  for (d, _) in defDyn.toList do allDefs := allDefs.insert d
  for d in allDefs do
    let kind := (defKind? env classes insts modOf d).getD "?"
    hD.putStrLn s!"{csvq d.toString},{(modOf d).getD .anonymous},{kind},{defApi.getD d 0},{defDyn.getD d 0},{defDynRemote.getD d 0}"
  hD.flush
  let hX ← IO.FS.Handle.mk (out ++ "/census_external.csv") .write
  hX.putStrLn "def,module,kernel_unfolds_total"
  for (d, v) in ext.toList do
    hX.putStrLn s!"{csvq d.toString},{(modOf d).getD .anonymous},{v}"
  hX.flush
  IO.println s!"re-checked: {results.size}, kernel re-check failures: {failed}"
  IO.println "edges by use/locality:"
  for (k, v) in totEdges.toList.toArray.qsort (fun a b => a.1 < b.1) do IO.println s!"  {k}: {v}"
  return 0
