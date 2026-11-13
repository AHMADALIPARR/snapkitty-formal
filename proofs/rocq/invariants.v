Require Import Coq.Arith.PeanoNat.
Require Extraction.
Extraction Language OCaml.

Definition add_zero (n : nat) : nat := n + 0.

Theorem add_zero_id : forall n, add_zero n = n.
Proof. intros; apply Nat.add_0_r. Qed.

Extraction "artifacts/rocq_invariants.ml" add_zero.
