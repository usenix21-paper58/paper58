(*
 * © 2019 XXX.
 * 
 * SPDX-License-Identifier: MIT
 * 
 *)
From Coq Require Import
     List
     Morphisms
     Eqdep
.

From SPICY Require Import
     MyPrelude
     Maps
     Messages
     Keys
     Automation
     Tactics
     RealWorld
     AdversaryUniverse
     Simulation.

Set Implicit Arguments.

Section FindKeysLemmas.

  Hint Constructors
       msg_pattern_safe
  : core.

  Lemma findUserKeys_foldfn_proper :
    forall {A},
      Proper (eq ==> eq ==> eq ==> eq) (fun (_ : NatMap.Map.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u).
  Proof. solve_proper. Qed.

  Lemma findUserKeys_foldfn_proper_Equal :
    forall {A},
      Proper (eq ==> eq ==> Equal ==> Equal) (fun (_ : NatMap.Map.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u).
  Proof.
    unfold Proper, respectful; intros; subst; Equal_eq; unfold Equal; intros; trivial.
  Qed.

  Lemma findUserKeys_foldfn_transpose :
    forall {A},
      transpose_neqkey eq (fun (_ : NatMap.Map.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u).
  Proof.
    unfold transpose_neqkey; intros.
    rewrite !merge_perms_assoc,merge_perms_sym with (ks1:=key_heap e'); trivial.
  Qed.

  Lemma findUserKeys_foldfn_transpose_Equal :
    forall {A},
      transpose_neqkey Equal (fun (_ : NatMap.Map.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u).
  Proof.
    unfold transpose_neqkey; intros; unfold Equal; intros.
    rewrite !merge_perms_assoc,merge_perms_sym with (ks1:=key_heap e'); trivial.
  Qed.

  Hint Resolve findUserKeys_foldfn_proper findUserKeys_foldfn_transpose
       findUserKeys_foldfn_proper_Equal findUserKeys_foldfn_transpose_Equal
    : core.

  Lemma findUserKeys_notation :
    forall {A} (usrs : honest_users A),
      fold (fun (_ : NatMap.Map.key) (u : user_data A) (ks : key_perms) => ks $k++ key_heap u) usrs $0 = findUserKeys usrs.
    unfold findUserKeys; trivial.
  Qed.

  Lemma user_keys_of_empty_is_None :
    forall {A} u_id,
      user_keys (@empty (user_data A)) u_id = None.
  Proof. unfold user_keys; intros; rewrite lookup_empty_none; trivial. Qed.

  Ltac solve_find_user_keys1 u_id usrs IHusrs :=
    match goal with
    | [ H : user_keys $0 _ = Some _ |- _ ] => rewrite user_keys_of_empty_is_None in H
    | [ |- context [ usrs $+ (_,_) $+ (u_id,_) ]] => rewrite map_ne_swap by auto 2
    | [ H : ?x <> u_id |- context [ fold _ (_ $+ (?x, _)) _]] => rewrite fold_add with (k := x); auto 2
    | [ H : usrs $? u_id = None |- context [ fold _ (_ $+ (u_id,_)) _]] => rewrite !fold_add; auto 2
    | [ |- context [ fold _ (_ $+ (u_id,_)) _]] => rewrite !findUserKeys_notation, <- IHusrs
    | [ |- context [ fold _ (_ $+ (u_id,_)) _]] => rewrite !findUserKeys_notation, IHusrs
    | [ H : context [ fold _ (_ $+ (u_id,_)) _] |- _ ] => rewrite !findUserKeys_notation, <- IHusrs in H
    | [ H : context [ fold _ (_ $+ (u_id,_)) _] |- _ ] => rewrite !findUserKeys_notation, IHusrs in H
    | [ H : context [ fold _ _ _ ] |- _ ] => rewrite !findUserKeys_notation in H
    | [ |- context [ fold _ _ _ ] ] => rewrite !findUserKeys_notation
    | [ |- _ $? _ <> _ ] => unfold not; intros
    end.

  Ltac solve_find_user_keys u_id usrs IHusrs :=
    repeat (solve_simple_maps1 || solve_perm_merges1 || maps_equal1  || solve_find_user_keys1 u_id usrs IHusrs || (progress (simpl in *))).

  Lemma findUserKeys_readd_user_same_keys_idempotent :
    forall {A} (usrs : honest_users A) u_id u_d proto msgs mycs froms sents cur_n,
      usrs $? u_id = Some u_d
      -> findUserKeys usrs = findUserKeys (usrs $+ (u_id, {| key_heap  := key_heap u_d
                                                          ; protocol  := proto
                                                          ; msg_heap  := msgs
                                                          ; c_heap    := mycs
                                                          ; from_nons := froms
                                                          ; sent_nons := sents
                                                          ; cur_nonce := cur_n
                                                         |} )).
  Proof.
    induction usrs using map_induction_bis; intros; Equal_eq;
      unfold findUserKeys;
      solve_find_user_keys u_id usrs IHusrs; eauto.
  Qed.

  Lemma findUserKeys_readd_user_same_keys_idempotent' :
    forall {A} (usrs : honest_users A) u_id ks proto msgs mycs froms sents cur_n,
      user_keys usrs u_id = Some ks
      -> findUserKeys (usrs $+ (u_id, {| key_heap  := ks
                                      ; protocol  := proto
                                      ; msg_heap  := msgs
                                      ; c_heap    := mycs
                                      ; from_nons := froms
                                      ; sent_nons := sents
                                      ; cur_nonce := cur_n |})) = findUserKeys usrs.
  Proof.
    unfold user_keys;
      induction usrs using map_induction_bis; intros; Equal_eq; auto;
        unfold findUserKeys;
        solve_find_user_keys u_id usrs IHusrs; eauto.
  Qed.

  Lemma findUserKeys_readd_user_addnl_keys :
    forall {A} (usrs : honest_users A) u_id proto msgs ks ks' mycs froms sents cur_n,
      user_keys usrs u_id = Some ks
      -> findUserKeys (usrs $+ (u_id, {| key_heap  := ks $k++ ks'
                                      ; protocol  := proto
                                      ; msg_heap  := msgs
                                      ; c_heap    := mycs
                                      ; from_nons := froms
                                      ; sent_nons := sents
                                      ; cur_nonce := cur_n |})) = findUserKeys usrs $k++ ks'.
  Proof.
    unfold user_keys;
      induction usrs using map_induction_bis; intros; Equal_eq; auto;
        unfold findUserKeys;
        solve_find_user_keys u_id usrs IHusrs;
        simpl; eauto;
          match goal with
          | [ |- ?ks1 $k++ (?ks2 $k++ ?ks3) = ?ks1 $k++ ?ks2 $k++ ?ks3 ] =>
            symmetry; apply merge_perms_assoc
          | [ |- ?kks1 $k++ ?kks2 $k++ ?kks3 = ?kks1 $k++ ?kks3 $k++ ?kks2 ] =>
            rewrite merge_perms_assoc, merge_perms_sym with (ks1 := kks2), <- merge_perms_assoc; trivial
          end.
  Qed.

  Lemma findUserKeys_readd_user_private_key :
    forall {A} (usrs : honest_users A) u_id proto msgs k_id ks mycs froms sents cur_n,
      user_keys usrs u_id = Some ks
      -> findUserKeys (usrs $+ (u_id, {| key_heap  := add_key_perm k_id true ks
                                      ; protocol  := proto
                                      ; msg_heap  := msgs
                                      ; c_heap    := mycs
                                      ; from_nons := froms
                                      ; sent_nons := sents
                                      ; cur_nonce := cur_n  |})) = findUserKeys usrs $+ (k_id,true).
  Proof.
    unfold user_keys;
      induction usrs using map_induction_bis; intros; Equal_eq; 
        clean_map_lookups; eauto.

    unfold findUserKeys;
      solve_find_user_keys u_id usrs IHusrs;
      eauto;
      try rewrite findUserKeys_notation;
      solve_perm_merges;
      eauto.
  Qed.

  Lemma findUserKeys_has_key_of_user :
    forall {A} (usrs : honest_users A) u_id u_d ks k kp,
      usrs $? u_id = Some u_d
      -> ks = key_heap u_d
      -> ks $? k = Some kp
      -> findUserKeys usrs $? k <> None.
  Proof.
    intros.
    induction usrs using map_induction_bis; intros; Equal_eq;
      subst; clean_map_lookups; eauto;
        unfold findUserKeys;
        solve_find_user_keys u_id usrs IHusrs;
        eauto.
  Qed.

  Hint Extern 1 (match _ $? _ with _ => _ end = _) => context_map_rewrites : core.
  Hint Extern 1 (match ?m $? ?k with _ => _ end = _) =>
    match goal with
    | [ H : ?m $? ?k = _ |- _ ] => rewrite H
    end : core.

  Lemma findUserKeys_has_private_key_of_user :
    forall {A} (usrs : honest_users A) u_id u_d ks k,
      usrs $? u_id = Some u_d
      -> ks = key_heap u_d
      -> ks $? k = Some true
      -> findUserKeys usrs $? k = Some true.
  Proof.
    induction usrs using map_induction_bis; intros; Equal_eq; subst;
      unfold findUserKeys;
      solve_find_user_keys u_id usrs IHusrs; eauto.

    specialize (IHusrs _ _ _ _ H0 (eq_refl (key_heap u_d)) H2); clean_map_lookups; eauto.
    specialize (IHusrs _ _ _ _ H0 (eq_refl (key_heap u_d)) H2); clean_map_lookups; eauto.
    specialize (IHusrs _ _ _ _ H0 (eq_refl (key_heap u_d)) H2); clean_map_lookups; eauto.
    specialize (IHusrs _ _ _ _ H0 (eq_refl (key_heap u_d)) H2); clean_map_lookups; eauto.
  Qed.

  Lemma findUserKeys_readd_user_same_key_heap_idempotent :
    forall {A} (usrs : honest_users A) u_id ks,
      user_keys usrs u_id = Some ks
      -> findUserKeys usrs $k++ ks = findUserKeys usrs.
  Proof.
    unfold user_keys;
      induction usrs using map_induction_bis; intros * UKS; unfold user_keys in UKS;
        Equal_eq; clean_map_lookups; eauto.

    unfold findUserKeys;
      solve_find_user_keys u_id usrs IHusrs;
      eauto.

    - rewrite merge_perms_assoc, merge_perms_refl. trivial.
    - rewrite merge_perms_assoc, merge_perms_sym with (ks1 := key_heap e), <- merge_perms_assoc;
        erewrite IHusrs; eauto.
  Qed.

  Lemma honest_key_after_new_keys :
    forall honestk msgk k_id,
        honest_key honestk k_id
      -> honest_key (honestk $k++ msgk) k_id.
  Proof.
    intros
    ; solve_perm_merges
    ; eauto.
  Qed.

  Hint Resolve honest_key_after_new_keys : core.

  Lemma honest_keyb_after_new_keys :
    forall honestk msgk k_id,
      honest_keyb honestk k_id = true
      -> honest_keyb (honestk $k++ msgk) k_id = true.
  Proof.
    intros; rewrite <- honest_key_honest_keyb in *; eauto.
  Qed.

  Hint Resolve honest_keyb_after_new_keys : core.

  Lemma message_honestly_signed_after_add_keys :
    forall {t} (msg : crypto t) cs honestk ks,
      msg_honestly_signed honestk cs msg = true
      -> msg_honestly_signed (honestk $k++ ks) cs msg = true.
  Proof.
    intros.
    destruct msg; unfold msg_honestly_signed in *; simpl in *;
      try discriminate;
      solve_simple_maps; eauto.
  Qed.

  Lemma message_honestly_signed_after_remove_pub_keys :
    forall {t} (msg : crypto t) honestk cs pubk,
      msg_honestly_signed (honestk $k++ pubk) cs msg = true
      -> (forall k kp, pubk $? k = Some kp -> kp = false)
      -> msg_honestly_signed honestk cs msg = true.
  Proof.
    intros.
    destruct msg; simpl in *; eauto;
      unfold msg_honestly_signed, honest_keyb in *;
      simpl in *;
      solve_perm_merges; eauto.

    specialize (H0 _ _ H1); destruct b; subst; auto.
    specialize (H0 _ _ H1); subst; eauto.
  Qed.

  Lemma cipher_honestly_signed_after_msg_keys :
    forall honestk msgk c,
      cipher_honestly_signed honestk c = true
      -> cipher_honestly_signed (honestk $k++ msgk) c = true.
  Proof.
    unfold cipher_honestly_signed. intros; cases c; trivial;
      rewrite <- honest_key_honest_keyb in *; eauto.
  Qed.

  Hint Resolve cipher_honestly_signed_after_msg_keys : core.

  Lemma ciphers_honestly_signed_after_msg_keys :
    forall honestk msgk cs,
      ciphers_honestly_signed honestk cs
      -> ciphers_honestly_signed (honestk $k++ msgk) cs.
  Proof.
    induction 1; econstructor; eauto.
  Qed.

  Hint Extern 1 (Some _ = Some _) => f_equal : core.

End FindKeysLemmas.

Ltac solve_findUserKeys_rewrites :=
  repeat
    match goal with
    | [ |- context [RealWorld.user_keys] ] => unfold RealWorld.user_keys
    | [ |- context [ _ $? _] ] => progress clean_map_lookups
    | [ |- context [match _ $? _ with _ => _ end]] => context_map_rewrites
    end; simpl; trivial.

Hint Rewrite @findUserKeys_readd_user_same_keys_idempotent' using solve [ solve_findUserKeys_rewrites ] : find_user_keys .
Hint Rewrite @findUserKeys_readd_user_addnl_keys using solve [ solve_findUserKeys_rewrites ] : find_user_keys.
Hint Rewrite @findUserKeys_readd_user_private_key using solve [ solve_findUserKeys_rewrites ] : find_user_keys.

Section CleanKeys.

  Lemma honest_key_filter_fn_proper :
    forall honestk,
      Proper (eq  ==>  eq  ==>  eq) (honest_key_filter_fn honestk).
  Proof.
    solve_proper.
  Qed.

  Lemma honest_key_filter_fn_filter_proper :
    forall honestk,
      Proper (eq  ==>  eq  ==>  eq  ==>  eq) (fun k v m => if honest_key_filter_fn honestk k v then m $+ (k,v) else m).
  Proof.
    solve_proper.
  Qed.

  Ltac keys_solver1 honestk :=
    match goal with
    | [ H : (if ?b then _ else _) = _ |- _ ] => destruct b
    | [ |- context [ if ?b then _ else _ ] ] => destruct b
    | [ H : filter _ _ $? _ = Some _ |- _ ] => rewrite <- find_mapsto_iff, filter_iff in H by auto 1
    | [ |- filter _ _ $? _ = Some _ ] => rewrite <- find_mapsto_iff, filter_iff by auto 1
    | [ |- filter _ _ $? _ = None ] => rewrite <- not_find_in_iff; unfold not; intros
    | [ RW : (forall k, ?m $? k = _ $? k), H : ?m $? _ = _ |- _ ] => rewrite RW in H
    end
    || solve_simple_maps1.
  
  Ltac simplify_filter1 :=
    match goal with
    | [ H : context[fold _ (_ $+ (_, _)) _] |- _] => rewrite fold_add in H by auto 2 
    | [ H : context[if ?cond then (fold _ _ _) $+ (_, _) else (fold _ _ _)] |- _ ] => cases cond
    end.

  Ltac keys_solver honestk :=
    repeat (keys_solver1 honestk || solve_perm_merges1 || simplify_filter1).

  Lemma honest_key_filter_fn_filter_transpose :
    forall honestk,
      transpose_neqkey eq (fun k v m => if honest_key_filter_fn honestk k v then m $+ (k,v) else m).
  Proof.
    unfold transpose_neqkey, honest_key_filter_fn; intros.
    keys_solver honestk; eauto.
  Qed.

  Lemma honest_key_filter_fn_filter_proper_Equal :
    forall honestk,
      Proper (eq  ==>  eq  ==>  Equal  ==>  Equal) (fun k v m => if honest_key_filter_fn honestk k v then m $+ (k,v) else m).
  Proof.
    unfold Equal, Proper, respectful; intros; subst.
    keys_solver honestk; eauto.
  Qed.

  Lemma honest_key_filter_fn_filter_transpose_Equal :
    forall honestk,
      transpose_neqkey Equal (fun k v m => if honest_key_filter_fn honestk k v then m $+ (k,v) else m).
  Proof.
    unfold transpose_neqkey, Equal, honest_key_filter_fn; intros.
    keys_solver honestk; eauto.
  Qed.

  Hint Resolve
       honest_key_filter_fn_proper
       honest_key_filter_fn_filter_proper honest_key_filter_fn_filter_transpose
       honest_key_filter_fn_filter_proper_Equal honest_key_filter_fn_filter_transpose_Equal
    : core.

  Lemma clean_keys_inv :
    forall honestk k_id k ks,
      clean_keys honestk ks $? k_id = Some k
      -> ks $? k_id = Some k
      /\ honest_key_filter_fn honestk k_id k = true.
  Proof.
    unfold clean_keys; intros; keys_solver honestk; eauto.
  Qed.
  
  Lemma clean_keys_inv' :
    forall honestk k_id k ks,
      clean_keys honestk ks $? k_id = None
      -> ks $? k_id = Some k
      -> honest_key_filter_fn honestk k_id k = false.
  Proof.
    induction ks using map_induction_bis; intros; Equal_eq;
      unfold clean_keys, filter in *; keys_solver honestk; eauto.
  Qed.

  Lemma clean_keys_keeps_honest_key :
    forall honestk k_id k ks,
        ks $? k_id = Some k
      -> honest_key_filter_fn honestk k_id k = true
      -> clean_keys honestk ks $? k_id = Some k.
  Proof.
    unfold clean_keys; intros; keys_solver honestk; eauto.
  Qed.

  Lemma clean_keys_drops_dishonest_key :
    forall honestk k_id k ks,
        ks $? k_id = Some k
      -> honest_key_filter_fn honestk k_id k = false
      -> clean_keys honestk ks $? k_id = None.
  Proof.
    unfold clean_keys; intros;
      keys_solver honestk; eauto.
  Qed.

  Lemma clean_keys_adds_no_keys :
    forall honestk k_id ks,
        ks $? k_id = None
      -> clean_keys honestk ks $? k_id = None.
  Proof.
    induction ks using map_induction_bis; intros; Equal_eq;
      unfold clean_keys in *;
      keys_solver honestk; eauto.
  Qed.

  Hint Resolve clean_keys_adds_no_keys : core.

  Lemma clean_keys_idempotent :
    forall honestk ks,
      clean_keys honestk (clean_keys honestk ks) = clean_keys honestk ks.
  Proof.
    intros;
      apply map_eq_Equal; unfold Equal; intros.
    cases (clean_keys honestk ks $? y); eauto.
    eapply clean_keys_keeps_honest_key; auto.
    unfold clean_keys in *; keys_solver honestk; eauto.
  Qed.

  Lemma honest_perm_filter_fn_proper :
    forall honestk,
      Proper (eq  ==>  eq  ==>  eq) (honest_perm_filter_fn honestk).
  Proof.
    solve_proper.
  Qed.

  Lemma honest_perm_filter_fn_filter_proper :
    forall honestk,
      Proper (eq  ==>  eq  ==>  eq  ==>  eq) (fun k v m => if honest_perm_filter_fn honestk  k v then m $+ (k,v) else m).
  Proof.
    solve_proper.
  Qed.

  Lemma honest_perm_filter_fn_filter_transpose :
    forall honestk,
      transpose_neqkey eq (fun k v m => if honest_perm_filter_fn honestk k v then m $+ (k,v) else m).
  Proof.
    unfold transpose_neqkey, honest_perm_filter_fn; intros;
      keys_solver honestk; eauto.
  Qed.

  Lemma honest_perm_filter_fn_filter_proper_Equal :
    forall honestk,
      Proper (eq  ==>  eq  ==>  Equal  ==>  Equal) (fun k v m => if honest_perm_filter_fn honestk k v then m $+ (k,v) else m).
  Proof.
    unfold Equal, Proper, respectful; intros; subst.
    keys_solver honestk; eauto.
  Qed.

  Lemma honest_perm_filter_fn_filter_transpose_Equal :
    forall honestk,
      transpose_neqkey Equal (fun k v m => if honest_perm_filter_fn honestk k v then m $+ (k,v) else m).
  Proof.
    unfold transpose_neqkey, Equal, honest_perm_filter_fn; intros;
      keys_solver honestk; eauto.
  Qed.

  Hint Resolve
       honest_perm_filter_fn_proper
       honest_perm_filter_fn_filter_proper honest_perm_filter_fn_filter_transpose
       honest_perm_filter_fn_filter_proper_Equal honest_perm_filter_fn_filter_transpose_Equal
    : core.

  Lemma clean_key_permissions_inv :
    forall honestk k_id k ks,
      clean_key_permissions honestk ks $? k_id = Some k
      -> ks $? k_id = Some k
      /\ honest_perm_filter_fn honestk k_id k = true.
  Proof.
    unfold clean_key_permissions; intros;
      keys_solver honestk; eauto.
  Qed.

  Lemma clean_key_permissions_inv' :
    forall honestk k_id k ks,
      clean_key_permissions honestk ks $? k_id = None
      -> ks $? k_id = Some k
      -> honest_perm_filter_fn honestk k_id k = false.
  Proof.
    induction ks using map_induction_bis; intros; Equal_eq;
      unfold clean_key_permissions,filter in *;
      keys_solver honestk; eauto.
  Qed.

  Lemma clean_key_permissions_inv'' :
    forall honestk k_id ks,
      clean_key_permissions honestk ks $? k_id = None
      -> honestk $? k_id = Some true
      -> ks $? k_id = None.
  Proof.
    induction ks using map_induction_bis; intros; Equal_eq;
      unfold clean_key_permissions,filter in *;
      keys_solver honestk; eauto.

    unfold honest_perm_filter_fn in Heq; context_map_rewrites; discriminate.
  Qed.

  Lemma clean_key_permissions_adds_no_permissions :
    forall honestk k_id ks,
        ks $? k_id = None
      -> clean_key_permissions honestk ks $? k_id = None.
  Proof.
    induction ks using map_induction_bis; intros; Equal_eq;
      unfold clean_key_permissions in *;
      keys_solver honestk; eauto.
  Qed.

  Lemma clean_key_permissions_keeps_honest_permission :
    forall honestk k_id k ks,
        ks $? k_id = Some k
      -> honest_perm_filter_fn honestk k_id k = true
      -> clean_key_permissions honestk ks $? k_id = Some k.
  Proof.
    unfold clean_key_permissions; intros;
      keys_solver honestk; eauto.
  Qed.

  Lemma clean_key_permissions_drops_dishonest_permission :
    forall honestk k_id k ks,
        ks $? k_id = Some k
      -> honest_perm_filter_fn honestk k_id k = false
      -> clean_key_permissions honestk ks $? k_id = None.
  Proof.
    unfold clean_key_permissions; intros;
      keys_solver honestk; eauto.
  Qed.

  Hint Resolve
       clean_key_permissions_inv
       clean_key_permissions_adds_no_permissions
       clean_key_permissions_keeps_honest_permission
       clean_key_permissions_drops_dishonest_permission
  : core.

  Lemma clean_key_permissions_idempotent :
    forall honestk ks,
      clean_key_permissions honestk ks = clean_key_permissions honestk (clean_key_permissions honestk ks).
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    symmetry; cases (clean_key_permissions honestk ks $? y);
      eauto;
      match goal with
      | [ H : clean_key_permissions _ _ $? _ = Some _ |- _ ] =>
        generalize (clean_key_permissions_inv _ _ _ H); intros; split_ands
      end; eauto.
  Qed.

  Ltac clean_keys_reasoner1 :=
    match goal with 
    | [ H : clean_key_permissions _ ?perms $? _ = Some _ |- _ ] => apply clean_key_permissions_inv in H
    | [ H : clean_key_permissions _ ?perms $? ?k = None |- _ ] =>
      is_var perms;
      match goal with
      | [ H1 : perms $? k = None |- _ ] => clear H
      | [ H1 : perms $? k = Some _ |- _ ] => eapply clean_key_permissions_inv' in H; eauto 2
      | _ => cases (perms $? k)
      end
    | [ H : clean_key_permissions _ (?perms1 $k++ ?perms2) $? _ = None |- _ ] =>
      match goal with
      | [ H1 : perms1 $? _ = Some _ |- _] => eapply clean_key_permissions_inv' in H; swap 1 2; [solve_perm_merges|]; eauto
      | [ H1 : perms2 $? _ = Some _ |- _] => eapply clean_key_permissions_inv' in H; swap 1 2; [solve_perm_merges|]; eauto
      end
    | [ H : honest_perm_filter_fn _ _ _ = _ |- _ ] => unfold honest_perm_filter_fn in H
    | [ H : forall k_id kp, ?pubk $? k_id = Some kp -> _, ARG : ?pubk $? _ = Some _ |- _ ] => specialize (H _ _ ARG)
    end.

  Lemma clean_key_permissions_distributes_merge_key_permissions :
    forall honestk perms1 perms2,
      clean_key_permissions honestk (perms1 $k++ perms2) =
      clean_key_permissions honestk perms1 $k++ clean_key_permissions honestk perms2.
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    cases (clean_key_permissions honestk perms1 $? y);
      cases (clean_key_permissions honestk perms2 $? y);
      cases (clean_key_permissions honestk (perms1 $k++ perms2) $? y);
      repeat (keys_solver1 honestk
              || solve_perm_merges1
              || discriminate
              || clean_keys_reasoner1); eauto.
  Qed.

  Lemma clean_honest_key_permissions_distributes :
    forall honestk perms pubk,
      (forall k_id kp, pubk $? k_id = Some kp -> honestk $? k_id = Some true /\ kp = false)
      -> clean_key_permissions honestk (perms $k++ pubk) = clean_key_permissions honestk perms $k++ pubk.
  Proof.
    intros.
    rewrite clean_key_permissions_distributes_merge_key_permissions.
    apply map_eq_Equal; unfold Equal; intros y.
    cases (clean_key_permissions honestk perms $? y);
      cases (clean_key_permissions honestk pubk $? y);
      cases (clean_key_permissions honestk (perms $k++ pubk) $? y);
      repeat (keys_solver1 honestk
              || solve_perm_merges1
              || discriminate
              || clean_keys_reasoner1); eauto.
  Qed.

  Lemma adv_no_honest_key_honest_key :
    forall honestk pubk,
      (forall k_id kp, pubk $? k_id = Some kp -> honestk $? k_id = Some true /\ kp = false)
      -> forall k_id kp, pubk $? k_id = Some kp -> honestk $? k_id = Some true.
  Proof.
    intros * H * H0.
    specialize (H _ _ H0); intuition idtac.
  Qed.

  Lemma clean_keys_drops_added_dishonest_key :
    forall honestk gks k_id ku kt,
      ~ In k_id gks
      -> honestk $? k_id = None
      -> clean_keys honestk (gks $+ (k_id, {| keyId := k_id; keyUsage := ku; keyType := kt |}))
        = clean_keys honestk gks.
  Proof.
    intros; unfold clean_keys, filter; apply map_eq_Equal; unfold Equal; intros.
    rewrite fold_add; eauto.
    unfold honest_key_filter_fn; context_map_rewrites; trivial.
  Qed.

End CleanKeys.

Section MergeCleanKeysLemmas.

  Lemma merge_keys_addnl_honest :
    forall ks1 ks2,
      (forall k_id kp, ks2 $? k_id = Some kp -> ks1 $? k_id = Some true)
      -> ks1 $k++ ks2 = ks1.
  Proof.
    intros; apply map_eq_Equal; unfold Equal; intros.
    cases (ks1 $? y); cases (ks2 $? y); subst;
      try
        match goal with
        | [ H1 : ks2 $? _ = Some ?b
                 , H2 : (forall _ _, ks2 $? _ = Some _ -> _) |- _ ]  => generalize (H2 _ _ H1); intros
        end; solve_perm_merges; intuition eauto.
  Qed.

  Lemma honestk_merge_new_msgs_keys_same :
    forall honestk cs  {t} (msg : crypto t),
      message_no_adv_private honestk cs msg
      -> (honestk $k++ findKeysCrypto cs msg) = honestk.
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    solve_perm_merges; eauto;
      specialize (H _ _ Heq0); clean_map_lookups; eauto.
  Qed.

  Lemma honestk_merge_new_msgs_keys_dec_same :
    forall honestk {t} (msg : message t),
      (forall k_id kp, findKeysMessage msg $? k_id = Some kp -> honestk $? k_id = Some true)
      -> (honestk $k++ findKeysMessage msg) = honestk.
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    solve_perm_merges; eauto;
      specialize (H _ _ Heq0); clean_map_lookups; eauto.
  Qed.

  Lemma add_key_perm_add_private_key :
    forall ks k_id,
      add_key_perm k_id true ks = ks $+ (k_id,true).
  Proof.
    intros; unfold add_key_perm; cases (ks $? k_id); subst; clean_map_lookups; eauto.
  Qed.

  Hint Resolve
       honest_key_filter_fn_proper
       honest_key_filter_fn_filter_proper honest_key_filter_fn_filter_transpose
       honest_key_filter_fn_filter_proper_Equal honest_key_filter_fn_filter_transpose_Equal
       honest_perm_filter_fn_proper
       honest_perm_filter_fn_filter_proper honest_perm_filter_fn_filter_transpose
       honest_perm_filter_fn_filter_proper_Equal honest_perm_filter_fn_filter_transpose_Equal
    : core.

  Lemma message_no_adv_private_merge :
    forall honestk t (msg : crypto t) cs,
      message_no_adv_private honestk cs msg
      -> honestk $k++ findKeysCrypto cs msg = honestk.
  Proof.
    intros.
    unfold message_no_adv_private in *.
    maps_equal.
    cases (findKeysCrypto cs msg $? y); solve_perm_merges; eauto.
    specialize (H _ _ Heq); split_ands; subst; clean_map_lookups; eauto.
    specialize (H _ _ Heq); split_ands; clean_map_lookups; eauto.
  Qed.


  Lemma message_only_honest_merge :
    forall honestk t (msg : message t),
      (forall k_id kp, findKeysMessage msg $? k_id = Some kp -> honestk $? k_id = Some true)
      -> honestk $k++ findKeysMessage msg = honestk.
  Proof.
    intros.
    maps_equal.
    cases (findKeysMessage msg $? y); solve_perm_merges; eauto.
    specialize (H _ _ Heq); split_ands; subst; clean_map_lookups; eauto.
    specialize (H _ _ Heq); split_ands; clean_map_lookups; eauto.
  Qed.

  Lemma honest_keyb_true_honestk_has_key :
    forall honestk k,
      honest_keyb honestk k = true -> honestk $? k = Some true.
  Proof. intros * H; rewrite <- honest_key_honest_keyb in H; assumption. Qed.

  Lemma clean_key_permissions_new_honest_key' :
    forall honestk k_id gks,
      gks $? k_id = None
      -> clean_key_permissions (honestk $+ (k_id, true)) gks = clean_key_permissions honestk gks.
  Proof.
    intros.
    unfold clean_key_permissions, filter.
    apply P.fold_rec_bis; intros; Equal_eq; eauto.
    subst; simpl.

    rewrite fold_add; eauto.
    assert (honest_perm_filter_fn (honestk $+ (k_id,true)) k e = honest_perm_filter_fn honestk k e)
      as RW.

    unfold honest_perm_filter_fn; destruct (k_id ==n k); subst; clean_map_lookups; eauto.
    apply find_mapsto_iff in H0; contra_map_lookup.
    rewrite RW; trivial.
  Qed.

  Lemma clean_key_permissions_new_honest_key :
    forall honestk k_id ks,
      ~ In k_id ks
      -> clean_key_permissions (honestk $+ (k_id, true)) (add_key_perm k_id true ks) =
        add_key_perm k_id true (clean_key_permissions honestk ks).
  Proof.
    intros; clean_map_lookups.
    unfold add_key_perm, greatest_permission.
    assert (clean_key_permissions honestk ks $? k_id = None)
      as CKP
        by (apply clean_key_permissions_adds_no_permissions; auto);
      rewrite CKP, H.
    unfold clean_key_permissions at 1; unfold filter; rewrite fold_add; eauto.
    unfold honest_perm_filter_fn; clean_map_lookups; eauto.

    apply map_eq_Equal; unfold Equal; intros.
    destruct (k_id ==n y); subst; clean_map_lookups; eauto.
    pose proof clean_key_permissions_new_honest_key';
      unfold clean_key_permissions, filter, honest_perm_filter_fn in *; eauto.
    rewrite H0; eauto.
  Qed.

  Lemma clean_key_permissions_nochange_pubk :
    forall honestk pubk perms,
      (forall k kp, pubk $? k = Some kp -> honestk $? k = Some true /\ kp = false)
      -> clean_key_permissions (honestk $k++ pubk) perms = clean_key_permissions honestk perms.
  Proof.
    intros.
    apply map_eq_Equal; unfold Equal; intros.
    cases (clean_key_permissions honestk perms $? y).
    - apply clean_key_permissions_inv in Heq; split_ands.
      apply clean_key_permissions_keeps_honest_permission; eauto.
      unfold honest_perm_filter_fn in *.
      cases (honestk $? y); try destruct b0; try discriminate.
      cases (pubk $? y); solve_perm_merges; eauto.
    - cases (perms $? y).
      + eapply clean_key_permissions_inv' in Heq; eauto.
        eapply clean_key_permissions_drops_dishonest_permission; eauto.
        unfold honest_perm_filter_fn in *.
        specialize (H y).
        cases (honestk $? y); try destruct b0; try discriminate.
        cases (pubk $? y);
          match goal with
          | [ PUB : pubk $? y = Some ?b, H : (forall kp, Some ?b = Some kp -> ?conc) |- _ ] =>
            assert (Some b = Some b) as SOME by trivial; apply H in SOME; split_ands; discriminate
          | _ => solve_perm_merges
          end; eauto.
        cases (pubk $? y);
          match goal with
          | [ PUB : pubk $? y = Some ?b, H : (forall kp, Some ?b = Some kp -> ?conc) |- _ ] =>
            assert (Some b = Some b) as SOME by trivial; apply H in SOME; split_ands; discriminate
          | _ => solve_perm_merges
          end; eauto.
      + apply clean_key_permissions_adds_no_permissions; eauto.
  Qed.

  Lemma clean_keys_nochange_pubk :
    forall honestk pubk ks,
      (forall k kp, pubk $? k = Some kp -> honestk $? k = Some true /\ kp = false)
      -> clean_keys (honestk $k++ pubk) ks = clean_keys honestk ks.
  Proof.
    intros; unfold clean_keys, filter.

    induction ks using P.map_induction_bis; intros; Equal_eq; eauto.
    rewrite !fold_add; eauto.
    rewrite IHks; trivial.

    assert (honest_key_filter_fn (honestk $k++ pubk) x e = honest_key_filter_fn honestk x e).
    unfold honest_key_filter_fn.
    specialize (H x).
    cases (honestk $? x); cases (pubk $? x); subst;
      try match goal with
          | [ PUB : pubk $? x = Some ?b, H : (forall kp, Some ?b = Some kp -> ?conc) |- _ ] =>
            assert (Some b = Some b) as SOME by trivial; apply H in SOME; split_ands; try discriminate
          end;
      solve_perm_merges; eauto.

    rewrite H1; trivial.
  Qed.

  Lemma adv_key_not_honestk :
    forall k_id honestk advk,
      advk $? k_id = Some true
      -> adv_no_honest_keys honestk advk
      -> honest_keyb honestk k_id = false.
  Proof.
    unfold adv_no_honest_keys, honest_keyb; intros.
    specialize (H0 k_id); split_ors; split_ands;
      context_map_rewrites; auto;
        contradiction.
  Qed.

  Lemma clean_keys_new_honest_key' :
    forall honestk k_id gks,
      gks $? k_id = None
      -> clean_keys (honestk $+ (k_id, true)) gks = clean_keys honestk gks.
  Proof.
    intros.
    unfold clean_keys, filter.
    apply P.fold_rec_bis; intros; Equal_eq; eauto.
    subst; simpl.

    rewrite fold_add; eauto.
    assert (honest_key_filter_fn (honestk $+ (k_id,true)) k e = honest_key_filter_fn honestk k e)
      as RW.

    unfold honest_key_filter_fn; destruct (k_id ==n k); subst; clean_map_lookups; eauto.
    apply find_mapsto_iff in H0; contra_map_lookup.
    rewrite RW; trivial.
  Qed.

  Lemma clean_keys_new_honest_key :
    forall honestk k_id k gks,
      gks $? k_id = None
      -> permission_heap_good gks honestk
      -> clean_keys (honestk $+ (k_id, true)) (gks $+ (k_id,k)) =
        clean_keys honestk gks $+ (k_id, k).
  Proof.
    intros.

    apply map_eq_Equal; unfold Equal; intros.
    destruct (k_id ==n y); subst; clean_map_lookups; eauto.
    - apply clean_keys_keeps_honest_key; clean_map_lookups; eauto.
      unfold honest_key_filter_fn; clean_map_lookups; eauto.
    - unfold clean_keys at 1.
      unfold filter.
      rewrite fold_add; eauto.
      unfold honest_key_filter_fn; clean_map_lookups; eauto.
      unfold clean_keys, filter, honest_key_filter_fn; eauto.
      pose proof (clean_keys_new_honest_key' honestk k_id gks H).
      unfold clean_keys, filter, honest_key_filter_fn in H1.
      rewrite H1; trivial.
  Qed.

End MergeCleanKeysLemmas.

