(*
 * © 2019 XXX.
 * 
 * SPDX-License-Identifier: MIT
 * 
 *)
From Coq Require Import
     Classical
     Lists.List.

From SPICY Require Import
     MyPrelude
     Maps
     Keys
     Messages
     MessageEq
     Tactics
     Simulation
     RealWorld
     AdversarySafety

     ModelCheck.ModelCheck.

From SPICY Require
     IdealWorld.

From Frap Require
     Sets.

Import RealWorld.RealWorldNotations.

Set Implicit Arguments.

Definition adversary_is_lame {B : type} (b : << Base B >>) (adv : user_data B) : Prop :=
    adv.(key_heap) = $0
  /\ adv.(msg_heap) = []
  /\ adv.(c_heap) = []
  /\ lameAdv b adv.

Definition universe_starts_sane {A B : type} (b : << Base B >>) (U : universe A B) : Prop :=
  let honestk := findUserKeys U.(users)
  in  (forall u_id u, U.(users) $? u_id = Some u -> u.(RealWorld.msg_heap) = [])
      /\ ciphers_honestly_signed honestk U.(RealWorld.all_ciphers)
      /\ keys_honest honestk U.(RealWorld.all_keys)
      /\ adversary_is_lame b U.(adversary).

(* 
 * Our definition of a Safe Protocol.  For now, we assume a pretty boring initial
 * adversary state.  The constraints could be relaxed a bit, but it is unclear that
 * there is really any purpose in doing so.
 *)
Module Type SafeProtocol.

  Parameter A B : type.
  Parameter U__i : IdealWorld.universe A.
  Parameter U__r : universe A B.
  Parameter b : << Base B >>.
  Parameter R : simpl_universe A -> IdealWorld.universe A -> Prop.

  Axiom U_good : universe_starts_sane b U__r.

  Axiom R_silent_simulates : simulates_silent_step (lameAdv b) R.
  Axiom R_loud_simulates : simulates_labeled_step (lameAdv b) R.
  Axiom R_honest_actions_safe : honest_actions_safe B R.
  Axiom R_final_actions_align : ri_final_actions_align B R.
  Axiom universe_starts_safe : R (peel_adv U__r) U__i /\ universe_ok U__r.

End SafeProtocol.

(*
 * A Functor which lifts any 'SafeProtocol' into the state we really want,
 * namely a universe where there is an adversary executing arbitrary code.
 * This lifting is basically provided by the top level proofs of
 * AdversarySafety.
 *)

Module AdversarySafeProtocol ( Proto : SafeProtocol ).
  Import Proto.

  #[export] Hint Resolve
       R_silent_simulates
       R_loud_simulates
       R_honest_actions_safe
       R_final_actions_align
    : core.

  Lemma proto_lamely_refines :
    refines (lameAdv b) U__r U__i.
  Proof.
    exists R; unfold simulates.
    pose proof universe_starts_safe.
    intuition eauto.
  Qed.

  #[export] Hint Resolve proto_lamely_refines : core.

  Lemma proto_starts_ok : universe_starts_ok U__r.
  Proof.
    pose proof universe_starts_safe.
    pose proof U_good.
    unfold universe_starts_ok; intros.
    unfold universe_ok, universe_starts_sane in *; split_ex.
    intuition eauto.
  Qed.

  #[export] Hint Resolve proto_starts_ok : core.

  Theorem protocol_with_adversary_could_generate_spec :
    forall U__ra advcode acts__r,
      U__ra = add_adversary U__r advcode
      -> rCouldGenerate U__ra acts__r
      -> exists acts__i,
          iCouldGenerate U__i acts__i
          /\ traceMatches acts__r acts__i.
  Proof.
    intros.
    pose proof U_good as L; unfold universe_starts_sane, adversary_is_lame in L; split_ands.
    eapply refines_could_generate; eauto.
  Qed.
  
End AdversarySafeProtocol.

Section SafeProtocolLemmas.

  Import RealWorld.

  Lemma adversary_is_lame_adv_univ_ok_clauses :
    forall A B (U : universe A B) b,
      universe_starts_sane b U
      -> permission_heap_good U.(all_keys) U.(adversary).(key_heap)
      /\ message_queues_ok U.(all_ciphers) U.(users) U.(all_keys)
      /\ adv_cipher_queue_ok U.(all_ciphers) U.(users) U.(adversary).(c_heap)
      /\ adv_message_queue_ok U.(users) U.(all_ciphers) U.(all_keys) U.(adversary).(msg_heap)
      /\ adv_no_honest_keys (findUserKeys U.(users)) U.(adversary).(key_heap).
  Proof.
    unfold universe_starts_sane, adversary_is_lame; intros; split_ands.
    repeat match goal with
           | [ H : _ (adversary _) = _ |- _ ] => rewrite H; clear H
           end.
    repeat (simple apply conj); try solve [ econstructor; clean_map_lookups; eauto ].

    - unfold message_queues_ok.
      rewrite Forall_natmap_forall; intros.
      specialize (H _ _ H2); rewrite H; econstructor.
    - unfold adv_no_honest_keys; intros.
      cases (findUserKeys (users U) $? k_id); eauto.
      destruct b0; eauto.
      right; right; apply conj; eauto.
      clean_map_lookups.

      Unshelve.
      exact (MkCryptoKey 1 Encryption SymKey).
  Qed.

End SafeProtocolLemmas.

Import Sets.
Module Foo <: EMPTY.
End Foo.
Module Import SN := SetNotations(Foo).

Definition ModelState {t__hon t__adv : type} := (RealWorld.universe t__hon t__adv * IdealWorld.universe t__hon * bool)%type.

Definition safety {t__hon t__adv} (st : @ModelState t__hon t__adv) : Prop :=
  let '(ru, iu, b) := st
  in  honest_cmds_safe ru.

Definition labels_align {t__hon t__adv} (st : @ModelState t__hon t__adv) : Prop :=
  let '(ru, iu, b) := st
  in  forall uid ru' ra,
      indexedRealStep uid (Action ra) ru ru'
      -> exists ia iu' iu'',
        (indexedIdealStep uid Silent) ^* iu iu'
        /\ indexedIdealStep uid (Action ia) iu' iu''
        /\ action_matches ru.(RealWorld.all_ciphers) ru.(RealWorld.all_keys) (uid,ra) ia.

Definition returns_align {t__hon t__adv} (st : @ModelState t__hon t__adv) : Prop :=
  let '(ru, iu, b) := st
  in (forall uid lbl ru', indexedRealStep uid lbl ru ru' -> False)
     -> forall uid ud__r r__r,
      ru.(RealWorld.users) $? uid = Some ud__r
      -> ud__r.(RealWorld.protocol) = RealWorld.Return r__r
      -> exists (iu' : IdealWorld.universe t__hon) ud__i r__i,
          istepSilent ^* iu iu'
          /\ iu'.(IdealWorld.users) $? uid = Some ud__i
          /\ ud__i.(IdealWorld.protocol) = IdealWorld.Return r__i
          /\ Rret_val_to_val r__r = Iret_val_to_val r__i.

Inductive step {t__hon t__adv : type} :
    @ModelState t__hon t__adv 
  -> @ModelState t__hon t__adv
  -> Prop :=
| RealSilent : forall ru ru' suid iu b,
    RealWorld.step_universe suid ru Silent ru'
    -> step (ru, iu, b) (ru', iu, b)
| BothLoud : forall uid ru ru' iu iu' iu'' ra ia b,
    indexedRealStep uid (Action ra) ru ru'
    -> (indexedIdealStep uid Silent) ^* iu iu'
    -> indexedIdealStep uid (Action ia) iu' iu''
    -> action_matches ru.(all_ciphers) ru.(all_keys) (uid,ra) ia
    -> labels_align (ru, iu, b)
    -> step (ru, iu, b) (ru', iu'', b)
| MisalignedCanStep : forall uid ru ru' iu iu' iu'' ra ia b,
    indexedRealStep uid (Action ra) ru ru'
    -> (indexedIdealStep uid Silent) ^* iu iu'
    -> indexedIdealStep uid (Action ia) iu' iu''
    -> ~ labels_align (ru, iu, b)
    -> step (ru, iu, b) (ru', iu'', false)
| MisalignedCantStep : forall uid ru ru' iu iu' ra b,
    indexedRealStep uid (Action ra) ru ru'
    -> (indexedIdealStep uid Silent) ^* iu iu'
    -> (forall lbl iu'', indexedIdealStep uid lbl iu' iu'' -> False)
    -> ~ labels_align (ru, iu, b)
    -> step (ru, iu, b) (ru', iu, false)
.

Inductive indexedModelStep {t__hon t__adv : type} (uid : user_id) :
    @ModelState t__hon t__adv 
  -> @ModelState t__hon t__adv
  -> Prop :=
| RealSilenti : forall ru ru' iu b,
    indexedRealStep uid Silent ru ru'
    -> indexedModelStep uid (ru, iu, b) (ru', iu, b)
| BothLoudi : forall ru ru' iu iu' iu'' ra ia b,
    indexedRealStep uid (Action ra) ru ru'
    -> (indexedIdealStep uid Silent) ^* iu iu'
    -> indexedIdealStep uid (Action ia) iu' iu''
    -> action_matches ru.(all_ciphers) ru.(all_keys) (uid,ra) ia
    -> labels_align (ru, iu, b)
    -> indexedModelStep uid (ru, iu, b) (ru', iu'', b)
| MisalignedCanStepi : forall ru ru' iu iu' iu'' ra ia b,
    indexedRealStep uid (Action ra) ru ru'
    -> (indexedIdealStep uid Silent) ^* iu iu'
    -> indexedIdealStep uid (Action ia) iu' iu''
    -> ~ labels_align (ru, iu, b)
    -> indexedModelStep uid (ru, iu, b) (ru', iu'', false)
| MisalignedCantStepi : forall ru ru' iu iu' ra b,
    indexedRealStep uid (Action ra) ru ru'
    -> (indexedIdealStep uid Silent) ^* iu iu'
    -> (forall lbl iu'', indexedIdealStep uid lbl iu' iu'' -> False)
    -> ~ labels_align (ru, iu, b)
    -> indexedModelStep uid (ru, iu, b) (ru', iu, false)
.

Lemma indexedModelStep_step :
  forall t__hon t__adv uid st st',
    @indexedModelStep t__hon t__adv uid st st'
    -> step st st'.
Proof.
  intros.
  invert H; [
    econstructor 1
  | econstructor 2
  | econstructor 3
  | econstructor 4 ]; eauto.

  invert H0; econstructor; eauto.
Qed.

Definition alignment {t__hon t__adv} (st : @ModelState t__hon t__adv) : Prop :=
  snd st = true
  /\ labels_align st.

Definition TrS {t__hon t__adv} (ru0 : RealWorld.universe t__hon t__adv) (iu0 : IdealWorld.universe t__hon) :=
  {| Initial := {(ru0, iu0, true)};
     Step    := @step t__hon t__adv |}.

Module Type AutomatedSafeProtocol.

  Parameter t__hon : type.
  Parameter t__adv : type.
  Parameter b : << Base t__adv >>.
  Parameter iu0 : IdealWorld.universe t__hon.
  Parameter ru0 : RealWorld.universe t__hon t__adv.

  Notation SYS := (TrS ru0 iu0).

  Axiom U_good : universe_starts_sane b ru0.
  Axiom universe_starts_safe : universe_ok ru0.

  Axiom safe_invariant : invariantFor
                           SYS
                           (fun st => safety st /\ alignment st /\ returns_align st).

End AutomatedSafeProtocol.

Section RealWorldLemmas.

  Import
    RealWorld
    RealWorldNotations.

  Lemma user_step_preserves_lame_adv' :
    forall A B C lbl u_id bd bd',
      step_user lbl (Some u_id) bd bd'
      -> forall (usrs usrs' : honest_users A) (adv adv' : user_data B) (cmd cmd' : user_cmd C) ud
          cs cs' gks gks' ks ks' qmsgs qmsgs' mycs mycs' froms froms' sents sents' n n',
        usrs $? u_id = Some ud
        -> bd = (usrs,adv,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
        -> bd' = (usrs',adv',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd')
        -> adv.(protocol) = adv'.(protocol).
  Proof.
    induction 1; inversion 2; inversion 1;
      intros;
      repeat match goal with
             | [ H : (_,_,_,_,_,_,_,_,_,_,_) = _ |- _ ] => invert H
             end;
      eauto.
  Qed.

  Lemma user_step_preserves_lame_adv :
    forall A B (usrs usrs' : honest_users A) (adv adv' : user_data B) (cmd cmd' : user_cmd (Base A)) uid ud
      cs cs' gks gks' ks ks' qmsgs qmsgs' mycs mycs' froms froms' sents sents' n n' lbl b,

      usrs $? uid = Some ud
      -> step_user lbl (Some uid) 
                  (usrs,adv,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
                  (usrs',adv',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd')
      -> lameAdv b adv
      -> lameAdv b adv'.
  Proof.
    unfold lameAdv; intros.
    eapply user_step_preserves_lame_adv' in H0; eauto.
    rewrite <- H0; assumption.
  Qed.

  Lemma universe_step_preserves_lame_adv :
    forall {t__h t__a} (U U' : universe t__h t__a) suid lbl b,
      lameAdv b U.(adversary)
      -> step_universe suid U lbl U'
      -> lameAdv b U'.(adversary).
  Proof.
    intros * LAME STEP.
    destruct U , U'; simpl in *.
    invert STEP;
      unfold build_data_step, buildUniverse in *; simpl in *.

    invert H1;
      eauto using user_step_preserves_lame_adv.

    unfold lameAdv in LAME; rewrite LAME in H; invert H.
  Qed.
  
End RealWorldLemmas.

Module ProtocolSimulates (Proto : AutomatedSafeProtocol).
  Import Proto Simulation.

  Lemma safety_inv : invariantFor SYS safety.
  Proof. eapply invariant_weaken; [ apply safe_invariant | firstorder idtac]. Qed.

  Lemma labels_align_inv : invariantFor SYS alignment.
  Proof. eapply invariant_weaken; [ apply safe_invariant | firstorder idtac]. Qed.

  Lemma returns_align_inv : invariantFor SYS returns_align.
  Proof. eapply invariant_weaken; [ apply safe_invariant | firstorder idtac]. Qed.
  
  #[export] Hint Resolve safety_inv labels_align_inv returns_align_inv : core.

  Definition reachable_from := (fun ru iu ru' iu' b b' => SYS.(Step)^* (ru, iu, b) (ru', iu', b')).
  Definition reachable := (fun ru iu => reachable_from ru0 iu0 ru iu).

  Tactic Notation "invar" constr(invar_lem) :=
    eapply use_invariant
    ; [ eapply invar_lem
      | eauto
      |]
    ; simpl
    ; eauto.

  Tactic Notation "invar" :=
    eapply use_invariant
    ; [ eauto .. |]
    ; simpl
    ; eauto.

  Inductive R :
    RealWorld.simpl_universe t__hon
    -> IdealWorld.universe t__hon
    -> Prop :=
  | RStep : forall ru iu v,
      SYS.(Step) ^* (ru0,iu0,true) (ru,iu,v)
      -> R (@RealWorld.peel_adv _ t__adv ru) iu.

  Lemma single_step_stays_lame :
    forall st st',
      SYS.(Step) st st'
      -> lameAdv b (adversary (fst (fst st)))
      -> lameAdv b (adversary (fst (fst st'))).
  Proof.
    intros.
    invert H;
      simpl in *;
      try match goal with
          | [ H : indexedRealStep _ _ _ _ |- _ ] => invert H
          end;
      eauto using user_step_preserves_lame_adv, universe_step_preserves_lame_adv.
  Qed.
  
  Lemma always_lame' :
    forall st st',
      SYS.(Step) ^* st st'
      -> forall (ru ru' : RealWorld.universe t__hon t__adv) (iu iu' : IdealWorld.universe t__hon) v v',
          st = (ru,iu,v)
        -> st' = (ru',iu',v')
        -> lameAdv b (adversary ru)
        -> lameAdv b (adversary ru').
  Proof.
    unfold SYS; simpl; intros *; intro H.
    eapply trc_ind with (P:=fun st st' => lameAdv b (adversary (fst (fst st))) -> lameAdv b (adversary (fst (fst st')))) in H;
      intros;
      subst;
      simpl in *;
      eauto.

    destruct x; destruct y; simpl in *.
    apply single_step_stays_lame in H0; eauto.
  Qed.

  Lemma always_lame :
    forall (ru ru' : RealWorld.universe t__hon t__adv) (iu iu' : IdealWorld.universe t__hon) v v',
      lameAdv b (adversary ru)
      -> SYS.(Step) ^* (ru,iu,v) (ru',iu',v')
      -> lameAdv b (adversary ru').
  Proof.
    intros; eauto using always_lame'.
  Qed.

  #[export] Hint Resolve always_lame : safe.

  Lemma lame_adv_no_impact_silent_step' :
    forall A B C u_id bd bd',
      step_user Silent (Some u_id) bd bd'
      -> forall (usrs usrs' : honest_users A) (adv adv' advx : user_data B) (cmd cmd' : user_cmd C)
          cs cs' gks gks' ks ks' qmsgs qmsgs' mycs mycs' froms froms' sents sents' n n',
        bd = (usrs,adv,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
        -> bd' = (usrs',adv',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd')
        -> exists advx',
            step_user Silent (Some u_id)
                      (usrs,advx,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
                      (usrs',advx',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd').
  Proof.
    induction 1; inversion 1; inversion 1;
      intros;
      repeat match goal with
             | [ H : (_,_,_,_,_,_,_,_,_,_,_) = _ |- _ ] => invert H
             end;
      try solve [eexists; subst; econstructor; eauto].

    specialize (IHstep_user _ _ _ _ advx _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ eq_refl eq_refl); split_ex.
    eexists; eapply StepBindRecur; eauto.
  Qed.

  Lemma lame_adv_no_impact_silent_step :
    forall A B C u_id
      (usrs usrs' : honest_users A) (adv adv' advx : user_data B) (cmd cmd' : user_cmd C)
      cs cs' gks gks' ks ks' qmsgs qmsgs' mycs mycs' froms froms' sents sents' n n',
      step_user Silent (Some u_id)
                (usrs,adv,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
                (usrs',adv',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd')
      -> exists advx',
        step_user Silent (Some u_id)
                  (usrs,advx,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
                  (usrs',advx',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd').
  Proof.
    intros; eauto using lame_adv_no_impact_silent_step'.
  Qed.

  Lemma lame_adv_no_impact_labeled_step' :
    forall A B C u_id bd bd' a__r,
      step_user (Action a__r) (Some u_id) bd bd'
      -> forall (usrs usrs' : honest_users A) (adv adv' advx : user_data B) (cmd cmd' : user_cmd C)
          cs cs' gks gks' ks ks' qmsgs qmsgs' mycs mycs' froms froms' sents sents' n n',
        bd = (usrs,adv,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
        -> bd' = (usrs',adv',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd')
        -> exists advx',
            step_user (Action a__r) (Some u_id)
                      (usrs,advx,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
                      (usrs',advx',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd').
  Proof.
    induction 1; inversion 1; inversion 1;
      intros;
      repeat match goal with
             | [ H : (_,_,_,_,_,_,_,_,_,_,_) = _ |- _ ] => invert H
             end;
      try solve [eexists; subst; econstructor; eauto].

    specialize (IHstep_user _ _ _ _ advx _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ eq_refl eq_refl); split_ex.
    eexists; eapply StepBindRecur; eauto.
  Qed.

  Lemma lame_adv_no_impact_labeled_step :
    forall A B C u_id a__r
      (usrs usrs' : honest_users A) (adv adv' advx : user_data B) (cmd cmd' : user_cmd C)
      cs cs' gks gks' ks ks' qmsgs qmsgs' mycs mycs' froms froms' sents sents' n n',
      step_user (Action a__r) (Some u_id)
                (usrs,adv,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
                (usrs',adv',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd')
      -> exists advx',
        step_user (Action a__r) (Some u_id)
                  (usrs,advx,cs,gks,ks,qmsgs,mycs,froms,sents,n,cmd)
                  (usrs',advx',cs',gks',ks',qmsgs',mycs',froms',sents',n',cmd').
  Proof.
    intros; eauto using lame_adv_no_impact_labeled_step'.
  Qed.

  Lemma reachable_from_silent_step :
    forall iu (ru U U' : RealWorld.universe t__hon t__adv) suid v v',
      SYS.(Step) ^* (ru0,iu0,v) (ru,iu,v')
      -> step_universe suid U Silent U'
      -> lameAdv b U.(adversary)
      -> ru.(users) = U.(users)
      -> ru.(all_ciphers) = U.(all_ciphers)
      -> ru.(all_keys) = U.(all_keys)
      -> exists U'',
          step_universe suid ru Silent U''
          /\ peel_adv U' = peel_adv U''.
  Proof.
    intros.
    assert (lameAdv b ru.(adversary))
      by (pose proof U_good; unfold universe_starts_sane, adversary_is_lame in *; split_ands; eauto with safe).
    
    destruct ru; destruct U; simpl in *; subst.
    invert H0.
    - destruct userData; unfold build_data_step in *; simpl in *.
      unfold mkULbl; destruct lbl; invert H6.
      eapply lame_adv_no_impact_silent_step in H3; split_ex.
      eexists; split.
      eapply StepUser; unfold build_data_step; eauto; simpl in *.
      unfold buildUniverse, peel_adv; simpl; trivial.
      
    - unfold lameAdv, build_data_step in *; simpl in *.
      rewrite H1 in H2.
      invert H2.
  Qed.
  
  Lemma reachable_from_labeled_step :
    forall iu (ru U U' : RealWorld.universe t__hon t__adv) uid a__r v,
      SYS.(Step) ^* (ru0,iu0,true) (ru,iu,v)
      -> indexedRealStep uid (Action a__r) U U'

      -> lameAdv b U.(adversary)
      -> ru.(users) = U.(users)
      -> ru.(all_ciphers) = U.(all_ciphers)
      -> ru.(all_keys) = U.(all_keys)
      -> exists U'',
          indexedRealStep uid (Action a__r) ru U''
          /\ peel_adv U' = peel_adv U''.
  Proof.
    intros.
    assert (lameAdv b ru.(adversary))
      by (pose proof U_good; unfold universe_starts_sane, adversary_is_lame in *; split_ands; eauto with safe).
    
    destruct ru; destruct U; simpl in *; subst.
    invert H0.

    destruct userData; unfold build_data_step in *; simpl in *.

    eapply lame_adv_no_impact_labeled_step in H3; split_ex.
    eexists; split.
    econstructor; unfold build_data_step; eauto; simpl in *.
    unfold buildUniverse, peel_adv; simpl; trivial.
  Qed.

  Lemma simsilent : simulates_silent_step (lameAdv b) R.
  Proof.
    hnf
    ; intros * REL UOK LAME * STEP
    ; invert REL.

    generalize (reachable_from_silent_step H3 STEP LAME H H1 H2);
      intros; split_ex.

    rewrite H4.
    eexists; split; eauto.
    econstructor.

    eapply trcEnd_trc.
    generalize (trc_trcEnd H3); intros.
    econstructor; eauto.
    unfold SYS; simpl.
    destruct ru, U__r; simpl in *; subst.
    econstructor 1; eauto.
  Qed.

  #[export] Hint Constructors action_matches : safe.
  
  Lemma action_matches_adv_change :
    forall {t1 t2} (U U' : RealWorld.universe t1 t2) a__r a__i,
      action_matches U.(RealWorld.all_ciphers) U.(RealWorld.all_keys) a__r a__i
      -> users U = users U'
      -> all_ciphers U = all_ciphers U'
      -> all_keys U = all_keys U'
      -> action_matches U'.(RealWorld.all_ciphers) U'.(RealWorld.all_keys) a__r a__i.
  Proof.
    intros * AM RWU RWC RWK.
    rewrite <- RWC, <- RWK; invert AM; eauto with safe.
  Qed.

  Lemma simlabeled : simulates_labeled_step (lameAdv b) R.
  Proof.
    hnf
    ; intros * REL UOK LAME * STEP
    ; invert REL.

    generalize (reachable_from_labeled_step H3 STEP LAME H H1 H2);
      intros; split_ex.

    pose proof labels_align_inv.
    unfold invariantFor, SYS in H5; simpl in H5.
    assert ( (ru0,iu0,true) = (ru0,iu0,true) \/ False ) as ARG by eauto.
    specialize (H5 _ ARG _ H3).
    unfold alignment in H5; simpl in H5; subst.
    split_ex; subst.
    specialize (H6 _ _ _ H0).

    split_ex.
    destruct (classic (labels_align (ru,U__i,true))).

    - do 3 eexists; rewrite H4; repeat apply conj; eauto.

      econstructor.

      eapply trcEnd_trc.
      generalize (trc_trcEnd H3); intros.
      econstructor; eauto.
      unfold SYS; simpl.
      destruct U__r, ru; simpl in *; subst.
      econstructor 2; eauto.

    - do 3 eexists; rewrite H4; repeat apply conj; eauto.

      econstructor.

      eapply trcEnd_trc.
      generalize (trc_trcEnd H3); intros.
      econstructor; eauto.
      unfold SYS; simpl.
      destruct U__r, ru; simpl in *; subst.
      
      econstructor 3; eauto.
  Qed.

  Lemma sim_final : ri_final_actions_align t__adv R.
  Proof.
    hnf
    ; intros * REL UOK NOSTEP * USR PROTO
    ; invert REL.

    pose proof returns_align_inv as ALIGN.
    unfold invariantFor, SYS in ALIGN; simpl in ALIGN.
    apply ALIGN in H3; eauto; clear ALIGN.
    unfold returns_align in H3.

    rewrite <- H in USR.
    eapply H3 in USR; eauto.

    intros.
    invert H0; eauto.
    unfold build_data_step in H5; simpl in H5.
    rewrite H, H1, H2 in H5
    ; rewrite H in H4
    ; destruct lbl
    ; [ eapply lame_adv_no_impact_silent_step in H5
      | eapply lame_adv_no_impact_labeled_step in H5]
    ; split_ex
    ; eapply NOSTEP
    ; econstructor 1
    ; eauto.
  Qed.
  
  Lemma honest_cmds_safe_adv_change :
    forall {t1 t2} (U U' : RealWorld.universe t1 t2),
      honest_cmds_safe U
      -> users U = users U'
      -> all_ciphers U = all_ciphers U'
      -> all_keys U = all_keys U'
      -> honest_cmds_safe U'.
  Proof.
    intros * HCS RWU RWC RWK.
    unfold honest_cmds_safe in *
    ; intros
    ; rewrite <- ?RWU, <- ?RWC, <- ?RWK in *
    ; eauto.
  Qed.

  #[export] Hint Resolve honest_cmds_safe_adv_change : safe.

  Lemma simsafe : honest_actions_safe t__adv R.
  Proof.
    hnf
    ; intros * REL UOK AUOK
    ; invert REL.

    pose proof safety_inv.
    unfold invariantFor, SYS in H0; simpl in H0.
    assert ( (ru0,iu0,true) = (ru0,iu0,true) \/ False ) as ARG by eauto.
    specialize (H0 _ ARG _ H3).
    unfold safety in *; eauto with safe.
  Qed.

  #[export] Hint Resolve simsilent simlabeled sim_final simsafe : safe.

  Lemma proto_lamely_refines :
    refines (lameAdv b) ru0 iu0.
  Proof.
    exists R; unfold simulates.

    pose proof safe_invariant.
    pose proof universe_starts_safe; split_ands.
    
    unfold invariantFor in H; simpl in H.
    assert ( (ru0,iu0,true) = (ru0,iu0,true) \/ False ) as ARG by eauto.
    specialize (H _ ARG); clear ARG.

    #[export] Hint Constructors R : safe.

    unfold simulates_silent_step, simulates_labeled_step;
      intuition eauto with safe.
  Qed.

  #[export] Hint Resolve proto_lamely_refines : safe.

  Lemma proto_starts_ok : universe_starts_ok ru0.
  Proof.
    pose proof universe_starts_safe.
    pose proof U_good.
    unfold universe_starts_ok; intros.
    unfold universe_ok, universe_starts_sane in *; split_ex.
    intuition eauto.
  Qed.

  #[export] Hint Resolve proto_starts_ok : safe.

  Theorem protocol_with_adversary_could_generate_spec :
    forall U__ra advcode acts__r,
      U__ra = add_adversary ru0 advcode
      -> rCouldGenerate U__ra acts__r
      -> exists acts__i,
          iCouldGenerate iu0 acts__i
          /\ traceMatches acts__r acts__i.
  Proof.
    intros.
    pose proof U_good as L; unfold universe_starts_sane, adversary_is_lame in L; split_ands.
    eapply refines_could_generate; eauto with safe.
  Qed.

End ProtocolSimulates.
