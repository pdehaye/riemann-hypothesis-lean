# Definition census: interface vs body use

- owner theorems re-checked: **11624** (kernel re-check failures: 0)
- theorem→project-definition edges: **38409**, of which interface-only **17053** (44.4%) and body-dependent **21356** (55.6%)
- theorems with ≥1 body-dependent use: **6695** (57.6%); with ≥1 *remote* body-dependent use: **3058** (26.3%)

| body-dependent use | same-module | same-dir | remote | total |
|---|---:|---:|---:|---:|
| kernel | 5710 | 6596 | 8563 | 20869 |
| eqn | 219 | 64 | 149 | 432 |
| kernel+eqn | 27 | 9 | 19 | 55 |

## By kind of definition

Body use of a `type` definition usually means the kernel looked through a type alias to find its structure (identifying the object); body use of a `value` or `pred` definition means the proof relied on what the function computes or what the predicate says.

| definition kind | interface edges | body edges | of which remote | theorems with remote body use |
|---|---:|---:|---:|---:|
| value | 10419 | 10167 | 3932 | 1848 |
| type-abbrev | 413 | 5936 | 2307 | 1100 |
| pred | 2270 | 2342 | 1678 | 970 |
| inst | 1675 | 1730 | 472 | 141 |
| value-abbrev | 1050 | 863 | 251 | 215 |
| type | 1190 | 230 | 62 | 41 |
| inst-abbrev | 31 | 71 | 12 | 12 |
| pred-abbrev | 5 | 17 | 17 | 11 |

## Definitions whose bodies are opened from other directories (top 30)

| definition | defined in | kind | interface uses | body uses | remote body uses |
|---|---|---|---:|---:|---:|
| `Formalism.FrobeniusOrbits.G0` | `Formalism.FrobeniusOrbits.Statement` | type-abbrev | 8 | 193 | 178 |
| `Formalism.ConjugateSelfDual.G` | `Formalism.ConjugateSelfDual.Statement` | type-abbrev | 3 | 155 | 155 |
| `GroundTheory.PAdicHodge.normInteger` | `GroundTheory.PAdicHodge.PerfectoidField` | value-abbrev | 450 | 359 | 144 |
| `Formalism.BasicNotions.Loc.Om` | `Formalism.SharpRestriction.LevelLetterCocycles.DataNLoc` | type-abbrev | 0 | 193 | 102 |
| `GroundTheory.PAdicHodge.AInf` | `GroundTheory.PAdicHodge.KerFontaineThetaCompFrobeniusEquivSymmPow` | type-abbrev | 2 | 381 | 98 |
| `Formalism.FrobeniusOrbits.HGrp` | `Formalism.FrobeniusOrbits.Statement` | type-abbrev | 8 | 107 | 91 |
| `Reformulated.AutPerF.Tilt` | `Development.AutomorphicArithmetic.IntegralCasts.CrystallinePeriods.SpanNatCastLeComap` | type-abbrev | 0 | 466 | 89 |
| `GroundTheory.PAdicHodge.ACris.ACris` | `GroundTheory.PAdicHodge.FactorizationFactorialLe` | type-abbrev | 4 | 198 | 87 |
| `Formalism.REAL.Arr` | `Formalism.RealPlaceAnalysis.StatementU` | type-abbrev | 0 | 81 | 81 |
| `Reformulated.AutPerF.Ainf` | `Development.AutomorphicArithmetic.IntegralCasts.CrystallinePeriods.SpanNatCastLeComap` | type-abbrev | 0 | 333 | 78 |
| `Formalism.BasicNotions.Loc.GQ` | `Formalism.SharpRestriction.LevelLetterCocycles.DataNLoc` | type-abbrev | 0 | 142 | 78 |
| `Formalism.L2.Host.Qb` | `Formalism.LocalToGlobal.UnitaryNorms.RealCyclotomicTwoPower` | type-abbrev | 1 | 129 | 78 |
| `Formalism.TwoAdicCyclotomicDecomposition.GalL` | `Formalism.TameInertiaTowers.StatementGroup` | type-abbrev | 2 | 75 | 75 |
| `Formalism.UG.bc` | `Formalism.SatakeDualWeyl.Statement` | value | 20 | 80 | 74 |
| `Formalism.BasicNotions.Loc.OC` | `Formalism.SharpRestriction.LevelLetterCocycles.DataNLoc` | type-abbrev | 0 | 107 | 64 |
| `Formalism.L2.Host.Fld` | `Formalism.LocalToGlobal.UnitaryNorms.RealCyclotomicTwoPower` | type-abbrev | 0 | 100 | 64 |
| `Formalism.BasicNotions.Loc.OCb` | `Formalism.SharpRestriction.LevelLetterCocycles.DataNLoc` | type-abbrev | 0 | 98 | 60 |
| `Formalism.L2.DIV.Pol` | `Formalism.LocalToGlobal.Divisibility.CoefMod` | type-abbrev | 1 | 85 | 57 |
| `Formalism.TwoAdicCyclotomicDecomposition.IsLayer` | `Formalism.TameInertiaTowers.StatementField` | pred | 41 | 56 | 56 |
| `Reformulated.AutPerF.AinfInv` | `Development.AutomorphicArithmetic.IntegralCasts.CrystallinePeriods.SpanNatCastLeComap` | type-abbrev | 0 | 228 | 49 |
| `Cmp6.OC` | `Development.WeilBound.CoreStatements.PeriodRingComparison.CrystallinePeriodRings.GammaEqDpow` | type-abbrev | 0 | 75 | 49 |
| `GroundTheory.PAdicHodge.instCommRingBDeRham` | `GroundTheory.PAdicHodge.BdRField` | inst | 25 | 118 | 48 |
| `GroundTheory.PAdicHodge.ACris.ACrisZero` | `GroundTheory.PAdicHodge.FactorizationFactorialLe` | value | 116 | 125 | 46 |
| `GroundTheory.PAdicHodge.IsPerfectoidField.instFieldBDeRham` | `GroundTheory.PAdicHodge.BdRField` | inst | 45 | 112 | 45 |
| `GroundTheory.PAdicHodge.instAlgebraBDeRham` | `GroundTheory.PAdicHodge.BdRField` | inst | 52 | 85 | 45 |
| `Formalism.UG.inclE` | `Formalism.SatakeDualWeyl.Statement` | value | 19 | 48 | 45 |
| `Formalism.GaloisCohomology.Places` | `Formalism.GaloisCohomology.Statement` | type-abbrev | 1 | 45 | 45 |
| `Formalism.HC.Frame.MA` | `Formalism.SharpRestriction.RamificationFrobenius.TotientGaloisClasses.ZsmulGeneratorEqZeroOfProjection` | type-abbrev | 8 | 166 | 44 |
| `Formalism.HC.Frame.GG` | `Formalism.SharpRestriction.RamificationFrobenius.TotientGaloisClasses.ZsmulGeneratorEqZeroOfProjection` | type-abbrev | 2 | 144 | 44 |
| `Formalism.HermitianLatticesTheory.locS` | `Formalism.HermitianLattices.StatementLat` | value | 31 | 43 | 43 |

## `value`/`pred` definitions whose bodies are opened from other directories (top 30)

| definition | defined in | kind | interface uses | body uses | remote body uses |
|---|---|---|---:|---:|---:|
| `GroundTheory.PAdicHodge.normInteger` | `GroundTheory.PAdicHodge.PerfectoidField` | value-abbrev | 450 | 359 | 144 |
| `Formalism.UG.bc` | `Formalism.SatakeDualWeyl.Statement` | value | 20 | 80 | 74 |
| `Formalism.TwoAdicCyclotomicDecomposition.IsLayer` | `Formalism.TameInertiaTowers.StatementField` | pred | 41 | 56 | 56 |
| `GroundTheory.PAdicHodge.ACris.ACrisZero` | `GroundTheory.PAdicHodge.FactorizationFactorialLe` | value | 116 | 125 | 46 |
| `Formalism.UG.inclE` | `Formalism.SatakeDualWeyl.Statement` | value | 19 | 48 | 45 |
| `Formalism.HermitianLatticesTheory.locS` | `Formalism.HermitianLattices.StatementLat` | value | 31 | 43 | 43 |
| `Reformulated.AutPerF.adicMap` | `Development.AutomorphicArithmetic.IntegralCasts.CrystallinePeriods.SpanNatCastLeComap` | value | 3 | 114 | 38 |
| `Formalism.UG.cT` | `Formalism.SatakeDualWeyl.Statement` | value | 35 | 43 | 38 |
| `Formalism.GradedWeylDivisibility.blockAct` | `Formalism.GradedWeylDivisibility.StatementD` | value | 2 | 37 | 37 |
| `Formalism.HermitianLatticesTheory.fcoord` | `Formalism.HermitianLattices.StatementMaj` | value | 32 | 38 | 36 |
| `Formalism.F.rk` | `Formalism.LatticeSlopes.Statement` | value | 34 | 35 | 35 |
| `Formalism.HermitianLatticesTheory.realize` | `Formalism.HermitianLattices.StatementMaj` | value | 41 | 35 | 35 |
| `Formalism.HermitianLatticesTheory.gmap` | `Formalism.HermitianLattices.StatementLat` | value | 54 | 34 | 34 |
| `Formalism.GradedWeylDivisibility.rowAct` | `Formalism.GradedWeylDivisibility.StatementA` | value | 13 | 32 | 32 |
| `Formalism.HN.zl` | `Formalism.HarderNarasimhan.Statement` | value | 58 | 31 | 31 |
| `Formalism.HN.IsLat` | `Formalism.HarderNarasimhan.Statement` | pred | 27 | 31 | 31 |
| `Formalism.REAL.arrOf` | `Formalism.RealPlaceAnalysis.StatementU` | value | 1 | 31 | 31 |
| `GroundTheory.PAdicHodge.AdicCompletion.extendRingHom` | `GroundTheory.PAdicHodge.FactorizationFactorialLe` | value | 3 | 81 | 30 |
| `GroundTheory.PAdicHodge.AdicCompletion.extendFamily` | `GroundTheory.PAdicHodge.FactorizationFactorialLe` | value | 0 | 74 | 29 |
| `Formalism.GradedWeylDivisibility.colAddGen` | `Formalism.GradedWeylDivisibility.StatementA` | value | 14 | 29 | 29 |
| `Formalism.HermitianLatticesTheory.realizeRaw` | `Formalism.HermitianLattices.StatementMaj` | value | 0 | 29 | 29 |
| `Formalism.UG.hform` | `Formalism.SatakeDualWeyl.Statement` | value | 21 | 30 | 28 |
| `Formalism.GradedWeylDivisibility.rowGen` | `Formalism.GradedWeylDivisibility.StatementA` | value | 16 | 29 | 28 |
| `Formalism.HN.rk` | `Formalism.HarderNarasimhan.Statement` | value | 30 | 28 | 28 |
| `Formalism.HermitianLatticesTheory.localization₂` | `Formalism.HermitianLattices.StatementLat` | value | 60 | 28 | 28 |
| `Formalism.HN.PlLat` | `Formalism.HarderNarasimhan.StatementPl` | pred | 1 | 27 | 27 |
| `Formalism.HermitianLatticesTheory.vecAt` | `Formalism.HermitianLattices.StatementMaj` | value | 6 | 28 | 26 |
| `Formalism.REAL.arrTo` | `Formalism.RealPlaceAnalysis.StatementU` | value | 0 | 26 | 26 |
| `Formalism.HermitianLatticesTheory.IsUnimodular` | `Formalism.HermitianLattices.StatementLat` | pred | 36 | 24 | 24 |
| `Formalism.HN.rkK` | `Formalism.HarderNarasimhan.StatementPl` | value | 17 | 24 | 24 |

## Most-used definitions that are only ever used through their interface (top 20)

| definition | defined in | interface uses |
|---|---|---:|
| `Formalism.BasicNotions.Host.cmStar` | `Formalism.LocalRingCardinality.DataHost` | 48 |
| `Formalism.BasicNotions.GIdx` | `Formalism.LocalRingCardinality.RhoDetPrimeEqMuTildeMulChiPow` | 42 |
| `Formalism.BasicNotions.IsSplitPl` | `Formalism.SharpRestriction.LevelLetterCocycles.DataN` | 27 |
| `Formalism.BasicNotions.IsConjPl` | `Formalism.SharpRestriction.LevelLetterCocycles.DataN` | 23 |
| `Formalism.BasicNotions.Scale.L` | `Formalism.LocalRingCardinality.DataParams₂` | 22 |
| `Formalism.BasicNotions.Scale.X''` | `Formalism.LocalRingCardinality.DataParams₂` | 19 |
| `Formalism.BasicNotions.Scale.w''` | `Formalism.LocalRingCardinality.DataParams₂` | 18 |
| `Formalism.L2.Col.GSD.Ok.fintypeCl` | `Formalism.LocalToGlobal.Columns.RhoEqOfSmulEq` | 18 |
| `Formalism.BasicNotions.LevelStarExponents.h0` | `Formalism.LocalRingCardinality.DataParams` | 16 |
| `UpperTheory.V.Fr.Frame.loc` | `Development.AutomorphicArithmetic.AutomorphicVarieties.FrobeniusSmoothVectors.ContinuousCoboundaries2` | 16 |
| `GroundTheory.Arith.Abelian.instDecidableEqFunctionFieldToAffine_groundTheory` | `GroundTheory.ArithmeticGeometry.AbelianVarieties.FunctionFieldPoint` | 16 |
| `Formalism.MainNotions.S.Loc.resChar` | `Formalism.SharpRestriction.CuspSpanNormBounds.PsiEDef` | 15 |
| `Formalism.BasicNotions.ColumnsAtT.Mram` | `Formalism.LocalRingCardinality.DataKernels` | 15 |
| `UpperTheory.V.Alg.AdicCont` | `Development.AutomorphicArithmetic.AutomorphicVarieties.CommutativeAlgebra.ResMapBijective` | 15 |
| `Formalism.BasicNotions.TH.upq` | `Formalism.LocalRingCardinality.DataTheta` | 14 |
| `ReciprocityTheory.ChartRestriction.G.Geo.Tor.Germ.comp1` | `ReciprocityTheory.ReductiveGroups.ArithmeticGeometry.BirationalGeometry.ToroidalCompactification.CocycleRightZeroThd` | 14 |
| `Formalism.WeaklyAdmissibleFiltrations.IsCrys` | `Formalism.WeaklyAdmissibleFiltrations.Statement` | 14 |
| `Formalism.MainNotions.G.hP` | `Formalism.SharpRestriction.GrowthBounds.IsResidueClassZero` | 14 |
| `Formalism.BasicNotions.HSpace.SigOK` | `Formalism.LocalRingCardinality.DataSpaces` | 13 |
| `Formalism.MainNotions.G.IsDominant` | `Formalism.SharpRestriction.GrowthBounds.UnramifiedQuadraticSetting` | 13 |

## By library area (theorem side)

| area | interface edges | body edges | body share |
|---|---:|---:|---:|
| `Development.AutomorphicArithmetic` | 3218 | 4339 | 57.4% |
| `Formalism.LocalToGlobal` | 1895 | 2749 | 59.2% |
| `Formalism.SharpRestriction` | 2024 | 1973 | 49.4% |
| `GroundTheory.PAdicHodge` | 1419 | 2536 | 64.1% |
| `Development.WeilBound` | 832 | 1907 | 69.6% |
| `Formalism.LocalRingCardinality` | 1897 | 826 | 30.3% |
| `Formalism.SatakeDualWeyl` | 967 | 1246 | 56.3% |
| `Development.AbelianVarietyTheory` | 859 | 912 | 51.5% |
| `Formalism.RealPlaceAnalysis` | 779 | 871 | 52.8% |
| `Formalism.HarderNarasimhan` | 673 | 701 | 51.0% |
| `Formalism.GradedWeylDivisibility` | 392 | 500 | 56.1% |
| `Formalism.FrobeniusOrbits` | 347 | 506 | 59.3% |
| `Formalism.QuotientMetricDivisors` | 374 | 406 | 52.1% |
| `Formalism.HermitianLattices` | 211 | 262 | 55.4% |
| `Formalism.TameInertiaTowers` | 145 | 215 | 59.7% |
| `GroundTheory.ArithmeticGeometry` | 174 | 169 | 49.3% |
| `GroundTheory.GlobalFields` | 143 | 186 | 56.5% |
| `ReciprocityTheory.ReductiveGroups` | 180 | 99 | 35.5% |
| `ReciprocityTheory.GaloisValuations` | 67 | 105 | 61.0% |
| `Formalism.EllipticTorsion` | 93 | 79 | 45.9% |

## Remote body-dependent edges, by (theorem area → definition area)

| theorem area | definition area | edges |
|---|---|---:|
| `Formalism.SatakeDualWeyl` | `Formalism.SatakeDualWeyl` | 767 |
| `Formalism.RealPlaceAnalysis` | `Formalism.RealPlaceAnalysis` | 735 |
| `Development.WeilBound` | `GroundTheory.PAdicHodge` | 709 |
| `Development.AutomorphicArithmetic` | `Development.AutomorphicArithmetic` | 548 |
| `Formalism.LocalToGlobal` | `Formalism.LocalToGlobal` | 529 |
| `Formalism.GradedWeylDivisibility` | `Formalism.GradedWeylDivisibility` | 378 |
| `Formalism.HarderNarasimhan` | `Formalism.HarderNarasimhan` | 367 |
| `Development.WeilBound` | `Development.AutomorphicArithmetic` | 317 |
| `Formalism.LocalRingCardinality` | `Formalism.SharpRestriction` | 275 |
| `Formalism.FrobeniusOrbits` | `Formalism.FrobeniusOrbits` | 253 |
| `Formalism.QuotientMetricDivisors` | `Formalism.QuotientMetricDivisors` | 243 |
| `Development.WeilBound` | `Formalism.SharpRestriction` | 241 |
| `Formalism.HermitianLattices` | `Formalism.HermitianLattices` | 217 |
| `Development.WeilBound` | `Development.WeilBound` | 201 |
| `Formalism.SharpRestriction` | `Formalism.FrobeniusOrbits` | 189 |
| `Formalism.TameInertiaTowers` | `Formalism.TameInertiaTowers` | 172 |
| `Development.AutomorphicArithmetic` | `Development.WeilBound` | 171 |
| `Development.AutomorphicArithmetic` | `GroundTheory.PAdicHodge` | 143 |
| `Development.AbelianVarietyTheory` | `Formalism.SharpRestriction` | 138 |
| `Formalism.FlagUnipotentLattices` | `Formalism.FlagUnipotentLattices` | 122 |

## Non-project definitions most unfolded by the kernel (top 20)

| definition | module | kernel unfolds |
|---|---|---:|
| `HMul.hMul` | `Init.Prelude` | 9445826 |
| `Mul.mul` | `Init.Prelude` | 9445437 |
| `Membership.mem` | `Init.Prelude` | 8161315 |
| `Subtype.val` | `Init.Prelude` | 4410800 |
| `SMul.smul` | `Init.Prelude` | 3783685 |
| `HSMul.hSMul` | `Init.Prelude` | 3728888 |
| `Bool.casesOn` | `Init.Prelude` | 2944389 |
| `Bool.rec` | `Init.Prelude` | 2613356 |
| `HAdd.hAdd` | `Init.Prelude` | 2378074 |
| `Add.add` | `Init.Prelude` | 2377894 |
| `Nat.casesOn` | `Init.Prelude` | 2205710 |
| `_private.Mathlib.GroupTheory.OreLocalization.Basic.0.OreLocalization.smul'` | `Mathlib.GroupTheory.OreLocalization.Basic` | 1816710 |
| `Nat.rec` | `Init.Prelude` | 1798718 |
| `Pow.pow` | `Init.Prelude` | 1351190 |
| `HPow.hPow` | `Init.Prelude` | 1340062 |
| `Decidable.casesOn` | `Init.Prelude` | 1303392 |
| `Decidable.rec` | `Init.Prelude` | 1233167 |
| `AddSubsemigroup.carrier` | `Mathlib.Algebra.Group.Subsemigroup.Defs` | 1191738 |
| `AddSubmonoid.toAddSubsemigroup` | `Mathlib.Algebra.Group.Submonoid.Defs` | 1188860 |
| `DFunLike.coe` | `Mathlib.Data.FunLike.Basic` | 1184924 |
