(* SPDX-License-Identifier: AGPL-3.0-or-later
   Copyright (C) 2026 Ahmad Ali Parr
   Custom Galois field heart over F_2^n — human-authored. *)

From Stdlib Require Import NArith Bool List.
Import N.
Open Scope N_scope.

Module Type IrreduciblePoly.
  Parameter deg  : N.
  Parameter poly : N.
  Axiom poly_deg : log2 poly = deg.
End IrreduciblePoly.

Module GaloisField (P : IrreduciblePoly).

  Definition mask : N := (1 lsl P.deg) - 1.

  Definition gf_add (a b : N) : N := lxor a b.

  Fixpoint clmul_aux (fuel : nat) (a b acc : N) : N :=
    match fuel with
    | O => acc
    | S f =>
        let acc' := if testbit b 0 then lxor acc a else acc in
        clmul_aux f (a lsl 1) (b lsr 1) acc'
    end.

  Definition clmul (a b : N) : N :=
    clmul_aux (N.to_nat P.deg) a b 0.

  Fixpoint gf_reduce_aux (fuel : nat) (x : N) : N :=
    match fuel with
    | O => land x mask
    | S f =>
        let top_bit := P.deg + of_nat f in
        let x' := if testbit x top_bit
                  then lxor x (P.poly lsl (of_nat f))
                  else x in
        gf_reduce_aux f x'
    end.

  Definition gf_mul (a b : N) : N :=
    gf_reduce_aux (N.to_nat P.deg) (clmul a b).

  Fixpoint gf_pow_aux (fuel : nat) (base exp acc : N) : N :=
    match fuel with
    | O => acc
    | S f =>
        let acc'  := if testbit exp 0 then gf_mul acc base else acc in
        let base' := gf_mul base base in
        gf_pow_aux f base' (exp lsr 1) acc'
    end.

  Definition gf_inv (a : N) : N :=
    let exp := (1 lsl P.deg) - 2 in
    gf_pow_aux (N.to_nat P.deg) a exp 1.

  Theorem gf_add_comm : forall a b, gf_add a b = gf_add b a.
  Proof. intros; unfold gf_add; apply lxor_comm. Qed.

  Theorem gf_add_self_zero : forall a, gf_add a a = 0.
  Proof. intros; unfold gf_add; apply lxor_nilpotent. Qed.

End GaloisField.
