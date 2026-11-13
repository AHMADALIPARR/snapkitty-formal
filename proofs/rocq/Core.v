From Coq Require Import Bool.Bool.

Module SnapKittyCore.

Definition xor_bool (a b : bool) : bool := xorb a b.

Theorem xor_zero_right : forall x : bool,
  xor_bool x false = x.
Proof. intros x. destruct x; reflexivity. Qed.

Theorem xor_commutative : forall x y : bool,
  xor_bool x y = xor_bool y x.
Proof. intros x y. destruct x, y; reflexivity. Qed.

End SnapKittyCore.
