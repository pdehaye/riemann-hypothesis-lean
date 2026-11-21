import Mathlib
-- Variant of ChebyshevPrimeBounds/SmallLoop.lean (force, 32000 iterations) to test kernel stack use.
namespace KExp
def tst (n c : Nat) : Bool :=
  Nat.blt (n ^ 256) (2 ^ ((3225600000000 * n - 1) / (c * 6931471808)))
def force (x : Nat) (f : Nat → Bool) : Bool :=
  match x with
  | 0 => f 0
  | k + 1 => f (k + 1)
def loop (B : Nat) : Nat → Nat → Nat → Nat → Bool
  | 0, _, _, _ => true
  | k + 1, n, c, Q =>
    force n fun n => force c fun c => force Q fun Q =>
    if Nat.gcd n Q = 1 then
      tst n (c + 1) && loop B k (n + 1) (c + 1) (if n ≤ B then Q * n else Q)
    else tst n c && loop B k (n + 1) c Q
theorem loop_run : loop 362 32000 2 0 1 = true := by decide +kernel
end KExp
