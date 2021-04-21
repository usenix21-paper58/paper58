(* 
 * © 2019 XXX.
 * 
 * SPDX-License-Identifier: MIT
 * 
 *)
From Coq Require Import
     List
.

From SPICY Require Import
     MyPrelude
     Maps
     Keys
     Tactics
     Messages
     MessageEq
     Automation
     Simulation
     AdversaryUniverse
     
     Theory.CipherTheory
     Theory.KeysTheory
     Theory.MessagesTheory
     Theory.UsersTheory
.

Set Implicit Arguments.

#[export] Hint Resolve in_eq in_cons : core.
#[export] Remove Hints absurd_eq_true trans_eq_bool : core.

Module SafetyAutomation.

  Import RealWorld.

  Ltac dismiss_adv :=
    repeat
      match goal with
      | [ LAME : lameAdv _ (adversary ?ru), STEP : step_user _ None _ _ |- _ ] =>
        destruct ru; unfold build_data_step in *; unfold lameAdv in LAME; simpl in *
      | [ LAME : lameAdv _ _, STEP : step_user _ None _ _ |- _ ] =>
        unfold build_data_step in *; unfold lameAdv in LAME; simpl in *
      | [ ADVP : protocol ?adv = Return _, STEP : step_user _ None (_,_,_,_,_,_,_,_,_,_,protocol ?adv) _ |- _ ] =>
        rewrite ADVP in STEP; invert STEP
      end.

  Ltac process_keys_messages1 :=
    match goal with
    | [ H : msg_honestly_signed _ _ ?msg = _ |- _ ] => unfold msg_honestly_signed in H
    | [ |- context [ msg_honestly_signed _ _ ?msg ] ] => unfold msg_honestly_signed; destruct msg; try discriminate; simpl in *
    | [ |- let (_,_) := ?x in _] => destruct x
    | [ H : context [ honest_keyb _ _ = _ ] |- _ ] => unfold honest_keyb in H
    | [ |- context [ honest_keyb _ _ ] ] => unfold honest_keyb
    | [ H : (if ?b then _ else _) = _ |- _ ] => is_var b; destruct b
    | [ H : (match ?honk $? ?k with _ => _ end) = _ |- _ ] => cases (honk $? k)
    | [ |- context [ if ?b then _ else _ ] ] => is_var b; destruct b
    | [ |- context [ match ?c with _ => _ end ] ] =>
      match type of c with
      | cipher => destruct c
      end
    end.

  Ltac process_keys_messages :=
    repeat process_keys_messages1;
    clean_context;
    repeat solve_simple_maps1;
    try discriminate; try contradiction; context_map_rewrites.

  #[export] Hint Resolve msg_honestly_signed_signing_key_honest : core.

  Ltac user_cipher_queue_lkup TAG :=
    match goal with
    | [ H : user_cipher_queue ?usrs ?uid = Some ?mycs |- _ ] =>
      assert (exists cmd qmsgs ks froms sents cur_n,
                 usrs $? uid = Some {| key_heap := ks
                                     ; msg_heap := qmsgs
                                     ; protocol := cmd
                                     ; c_heap := mycs
                                     ; from_nons := froms
                                     ; sent_nons := sents
                                     ; cur_nonce := cur_n |})
        as TAG by (unfold user_cipher_queue in H;
                   cases (usrs $? uid); try discriminate;
                   match goal with
                   | [ H1 : Some _ = Some _ |- exists t v w x y z, Some ?u = _ ] => invert H1; destruct u; repeat eexists; reflexivity
                   end)
    end.

  Ltac user_keys_lkup TAG :=
    match goal with
    | [ H : user_keys ?usrs ?uid = Some ?ks |- _ ] =>
      assert (exists cmd mycs qmsgs froms sents cur_n,
                 usrs $? uid = Some {| key_heap := ks
                                     ; msg_heap := qmsgs
                                     ; protocol := cmd
                                     ; c_heap := mycs
                                     ; from_nons := froms
                                     ; sent_nons := sents
                                     ; cur_nonce := cur_n |})
        as TAG by (unfold user_keys in H;
                   cases (usrs $? uid); try discriminate;
                   match goal with
                   | [ H1 : Some _ = Some _ |- exists t v w x y z, Some ?u = _ ] => invert H1; destruct u; repeat eexists; reflexivity
                   end)
    end.


  Ltac user_cipher_queues_prop :=
    match goal with
    | [ OK : user_cipher_queues_ok ?cs ?honk ?us |- _ ] =>
      match goal with
      | [ H : us $? _ = Some ?u |- _ ] =>
        prop_not_unifies (user_cipher_queue_ok cs honk (c_heap u));
        generalize (Forall_natmap_in_prop _ OK H); simpl; intros
      | _ => let USR := fresh "USR"
            in user_cipher_queue_lkup USR;
            do 6 (destruct USR as [?x USR]);
               generalize (Forall_natmap_in_prop _ OK USR); simpl; intros
      end
    end;
    repeat match goal with
           | [ H : user_cipher_queue_ok _ _ ?mycs, H1 : List.In _ ?mycs |- _ ] =>
             unfold user_cipher_queue_ok in H;
             rewrite Forall_forall in H;
             specialize (H _ H1);
             split_ex; split_ands; clean_map_lookups
           | [ H : honest_keyb _ _ = true |- _] => apply honest_keyb_true_honestk_has_key in H
           | [ H : cipher_honestly_signed _ _ = true |- _ ] => simpl in H
           end.

  Ltac permission_heaps_prop :=
    match goal with
    | [ OK : Forall_natmap (fun _ => permission_heap_good ?gks _) ?us |- _ ] => 
      match goal with
      | [ H : us $? _ = Some ?u |- _ ] =>
        prop_not_unifies (permission_heap_good gks (key_heap u));
        generalize (Forall_natmap_in_prop _ OK H); simpl; intros
      | _ => let USR := fresh "USR"
            in user_keys_lkup USR;
               do 6 (destruct USR as [?x USR]);
               generalize (Forall_natmap_in_prop _ OK USR); simpl; intros
      end
    end.
  
  Ltac keys_and_permissions_prop :=
    match goal with
    | [ H : keys_and_permissions_good ?gks ?usrs ?adv |- _ ] =>
      assert (keys_and_permissions_good gks usrs adv) as KPG by assumption; unfold keys_and_permissions_good in KPG; split_ands;
      match goal with
      | [ H : Forall_natmap (fun _ => permission_heap_good ?gks _) ?usrs |- _ ] =>
        assert_if_new (permission_heap_good gks (findUserKeys usrs)) eauto
      end;
      permission_heaps_prop
    end.

  Ltac refine_signed_messages :=
    repeat
      match goal with
      | [ H1 : msg_pattern_safe ?honk _ ,
          H2 : msg_accepted_by_pattern _ _ _ _ ?msg,
          H3 : match ?msg with _ => _ end
          |- _ ] => assert (msg_honestly_signed honk msg = true) as HON_SIGN by eauto 2;
                  unfold msg_honestly_signed in *;
                  split_ands;
                  destruct msg;
                  try discriminate;
                  split_ands
      | [ COND : honest_keyb ?honk ?kid = _
        , H : if honest_keyb ?honk ?kid then _ else _ |- _ ] => rewrite COND in H
      end; split_ands.

  #[export] Hint Resolve
       clean_honest_key_permissions_distributes
       adv_no_honest_key_honest_key
       honest_cipher_filter_fn_proper
       honest_cipher_filter_fn_filter_proper
       honest_cipher_filter_fn_filter_transpose
       honest_cipher_filter_fn_filter_proper_eq
       honest_cipher_filter_fn_filter_transpose_eq
       findUserKeys_foldfn_proper
       findUserKeys_foldfn_transpose
       findUserKeys_foldfn_proper_Equal
       findUserKeys_foldfn_transpose_Equal
  : core.

  Lemma users_permission_heaps_good_merged_permission_heaps_good :
    forall {A} (usrs : honest_users A) gks,
      Forall_natmap (fun u : user_data A => permission_heap_good gks (key_heap u)) usrs
      -> permission_heap_good gks (findUserKeys usrs).
  Proof.
    induction usrs using P.map_induction_bis; intros; Equal_eq; eauto.
    - unfold findUserKeys, fold, Raw.fold, permission_heap_good; simpl;
        intros; clean_map_lookups.

    - apply Forall_natmap_split in H0; auto; split_ands.
      specialize (IHusrs _ H0); clear H0.
      unfold permission_heap_good; intros.
      unfold permission_heap_good in H1.
      unfold findUserKeys in H0; rewrite fold_add in H0; eauto; rewrite findUserKeys_notation in H0.

      eapply merge_perms_split in H0; split_ors; eauto.
  Qed.

  #[export] Hint Resolve users_permission_heaps_good_merged_permission_heaps_good : core.

  #[export] Hint Extern 1 (_ $+ (?k, _) $? _ = Some _) => progress (clean_map_lookups; trivial) : core.
  #[export] Hint Extern 1 (honest_keyb _ _ = true) => rewrite <- honest_key_honest_keyb : core.
  #[export] Hint Extern 1 (_ && _ = true) => rewrite andb_true_iff : core.

  #[export] Hint Extern 1 (honest_key_filter_fn _ _ _ = _) => unfold honest_key_filter_fn; context_map_rewrites : core.
  #[export] Hint Extern 1 (honest_perm_filter_fn _ _ _ = _) => unfold honest_perm_filter_fn; context_map_rewrites : core.

  #[export] Hint Extern 1 (user_cipher_queue _ _ = _) => unfold user_cipher_queue; context_map_rewrites : core.
  #[export] Hint Extern 1 (user_keys _ _ = Some _ ) => unfold user_keys; context_map_rewrites : core.

End SafetyAutomation.
