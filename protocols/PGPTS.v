(*
 * © 2020 XXX.
 * 
 * SPDX-License-Identifier: MIT
 * 
 *)
From Coq Require Import
     List.

From SPICY Require Import
     MyPrelude
     Maps
     ChMaps
     Messages
     ModelCheck
     Keys
     Automation
     Tactics
     Simulation
     AdversaryUniverse

     ModelCheck.UniverseEqAutomation
     ModelCheck.ProtocolAutomation
     ModelCheck.SafeProtocol
     ModelCheck.ProtocolFunctions
.

From SPICY Require IdealWorld RealWorld.

Import IdealWorld.IdealNotations
       RealWorld.RealWorldNotations
       SimulationAutomation.

From protocols Require Import
     PGP.

Set Implicit Arguments.

Open Scope protocol_scope.

Module PGPProtocolSecure <: AutomatedSafeProtocol.

  Import PGPProtocol.

  Definition t__hon := Nat.
  Definition t__adv := Unit.
  Definition b := tt.
  Definition iu0  := ideal_univ_start.
  Definition ru0  := real_univ_start.

  Import Gen Tacs SetLemmas.

  #[export] Hint Unfold t__hon t__adv b ru0 iu0 ideal_univ_start real_univ_start : core.

  Lemma next_key_natmap_exists :
    forall {V} (m : NatMap.t V),
    exists k, m $? k = None.
  Proof.
    intros.
    exists (next_key m); eauto using Maps.next_key_not_in.
  Qed.

  Lemma next_key_chmap_exists :
    forall {V} (m : ChMap.t V),
    exists k, m #? (# k) = None.
  Proof.
    intros.
    exists (next_key_nat m); eauto using next_key_not_in.
  Qed.

  Lemma safe_invariant :
    invariantFor
      {| Initial := {(ru0, iu0, true)}; Step := @step t__hon t__adv  |}
      (fun st => safety st /\ alignment st /\ returns_align st).
  Proof.
    eapply invariant_weaken.

    - eapply multiStepClosure_ok; simpl.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      gen1.
      
    - intros.
      simpl in *.

      sets_invert; split_ex
      ; simpl in *; autounfold with core
      ; subst; simpl
      ; unfold safety, alignment, returns_align
      ; ( repeat simple apply conj
          ; [ solve_honest_actions_safe; clean_map_lookups; eauto 8
            | trivial
            | unfold labels_align; intros; rstep; subst; solve_labels_align
            | try solve [ intros; find_step_or_solve ] 
        ]).

      Unshelve.
      all: exact 0 || auto.

  Qed.

  Lemma U_good : @universe_starts_sane _ Unit b ru0.
  Proof.
    autounfold;
      unfold universe_starts_sane; simpl.
    repeat (apply conj); intros; eauto.
    - solve_perm_merges; eauto.
    - econstructor.
    - unfold AdversarySafety.keys_honest; rewrite Forall_natmap_forall; intros.
      unfold mkrUsr; simpl.
      rewrite !findUserKeys_add_reduce, findUserKeys_empty_is_empty; eauto.
    - unfold lameAdv; simpl; eauto.
  Qed.

  Lemma universe_starts_safe : universe_ok ru0.
  Proof.
    pose proof (adversary_is_lame_adv_univ_ok_clauses U_good).
    
    unfold universe_ok
    ; autounfold
    ; simpl
    ; intuition eauto
    .

    - econstructor; eauto.
    - unfold keys_and_permissions_good; solve_simple_maps; intuition eauto.
      solve_simple_maps; eauto.

      rewrite Forall_natmap_forall; intros.

      solve_simple_maps; simpl
      ; unfold permission_heap_good; intros;
        solve_simple_maps; solve_concrete_maps; eauto.

    - unfold user_cipher_queues_ok.
      rewrite Forall_natmap_forall; intros.
      focus_user
      ; simpl in *; econstructor; eauto.

    - unfold honest_nonces_ok, honest_user_nonces_ok, honest_nonces_ok
      ; repeat simple apply conj
      ; intros
      ; clean_map_lookups
      ; intros
      ; focus_user
      ; try contradiction; try discriminate; simpl;
        repeat (apply conj); intros; clean_map_lookups; eauto.

    - unfold honest_users_only_honest_keys; intros.
      focus_user;
        subst;
        simpl in *;
        clean_map_lookups;
        unfold mkrUsr; simpl; 
          rewrite !findUserKeys_add_reduce, findUserKeys_empty_is_empty;
          eauto;
          simpl in *;
          solve_perm_merges;
          solve_concrete_maps;
          solve_simple_maps;
          eauto.
  Qed.
  

End PGPProtocolSecure.
