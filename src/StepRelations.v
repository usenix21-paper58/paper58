(* 
 * © 2019 XXX.
 * 
 * SPDX-License-Identifier: MIT
 * 
 *)
From Frap Require Export Relations.

Set Implicit Arguments.

Section trc_tri.
  Variable A B : Type.
  Variable R : A -> B -> A -> Prop.
  (* Variable P : B -> Prop. *)

  Inductive trc3 (P : B -> Prop) : A -> A -> Prop :=
  | Trc3Refl : forall x, trc3 P x x
  | Trc3Front : forall x y z b,
      P b
      -> R x b y
      -> trc3 P y z
      -> trc3 P x z.

  Hint Constructors trc3 : core.

  Theorem trc3_one : forall x y b (P : B -> Prop), P b -> R x b y
    -> trc3 P x y.
  Proof.
    eauto.
  Qed.

  Theorem trc3_trans : forall x y (P : B -> Prop), trc3 P x y
    -> forall z, trc3 P y z
      -> trc3 P x z.
  Proof.
    induction 1; eauto.
  Qed.

End trc_tri.

#[export] Hint Constructors trc3 : core.
