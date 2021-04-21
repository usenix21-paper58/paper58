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
     AdversaryUniverse
     Maps
     ChMaps
     Messages
     Keys
     Automation
     Tactics
     Simulation

     ModelCheck.UniverseEqAutomation
     ModelCheck.SafeProtocol
     ModelCheck.ProtocolFunctions
     ModelCheck.ProtocolAutomation.

From SPICY Require IdealWorld RealWorld.

Import IdealWorld.IdealNotations.
Import RealWorld.RealWorldNotations.

Set Implicit Arguments.

(* User ids *)
Definition A   := 0.
Definition B   := 1.

Notation owner  := {| IdealWorld.read := true; IdealWorld.write := true |}.
Notation reader := {| IdealWorld.read := true; IdealWorld.write := false |}.
Notation writer := {| IdealWorld.read := false; IdealWorld.write := true |}.

Section IdealWorldDefs.
  Import IdealWorld.

  Definition mkiU
             (cv : channels)
             (perms__a perms__b : permissions)
             (p__a p__b : cmd (Base Nat)) : universe Nat :=
    {| channel_vector := cv;
       users :=
         $0
          $+ (A,   {| perms := perms__a ; protocol := p__a |})
          $+ (B,   {| perms := perms__b ; protocol := p__b |})
    |}.
End IdealWorldDefs.

Section RealWorldDefs.
  Import RealWorld.

  Definition mkrUsr (ks : key_perms) (p : user_cmd (Base Nat)) :=
    {| key_heap  := ks ;
       protocol  := p ;
       msg_heap  := [] ;
       c_heap    := [] ;
       from_nons := [] ;
       sent_nons := [] ;
       cur_nonce := 0
    |}.

  Definition mkrU
             (gks : keys)
             (keys__a keys__b : key_perms)
             (p__a p__b : user_cmd (Base Nat)) (adv : user_data Unit) : universe Nat Unit :=
    {| users :=
         $0 $+ (A, mkrUsr keys__a p__a)
            $+ (B, mkrUsr keys__b p__b)
     ; adversary        := adv
     ; all_ciphers      := $0
     ; all_keys         := gks
    |}.
End RealWorldDefs.

#[export] Hint Unfold mkrU mkrUsr : user_build.

Module SignPingSendProtocol.

  Section IW.
    Import IdealWorld.

    Notation CH__A2B := (Single 0).
    Notation perms_CH__A2B := 0.

    Definition PERMS__a := $0 $+ (perms_CH__A2B, {| read := true; write := true |}). (* writer *)
    Definition PERMS__b := $0 $+ (perms_CH__A2B, {| read := true; write := false |}). (* reader *)

    Definition ideal_univ_start :=
      mkiU (#0 #+ (CH__A2B, [])) PERMS__a PERMS__b
           (* user A *)
           ( n <- Gen
           ; _ <- Send (Content n) CH__A2B
           ; Return n)

           (* user B *)
           ( m <- @Recv Nat CH__A2B
           ; ret (extractContent m)).

  End IW.

  Section RW.
    Import RealWorld.

    Definition KID1 : key_identifier := 0.

    Definition KEY1  := MkCryptoKey KID1 Signing AsymKey.
    Definition KEYS  := $0 $+ (KID1, KEY1).

    Definition A__keys := $0 $+ (KID1, true).
    Definition B__keys := $0 $+ (KID1, false).

    Definition real_univ_start :=
      mkrU KEYS A__keys B__keys
           (* user A *)
           ( n  <- Gen
           ; c  <- Sign KID1 B (message.Content n)
           ; _  <- Send B c
           ; Return n)

           (* user B *)
           ( c  <- @Recv Nat (Signed KID1 true)
           ; v  <- Verify KID1 c
           ; ret (if fst v
                  then match snd v with
                       | message.Content p => p
                       | _                 => 0
                       end
                  else 1)).
  
  End RW.

  #[export] Hint Unfold
       A B KID1 KEY1 KEYS A__keys B__keys
       PERMS__a PERMS__b
       real_univ_start mkrU mkrUsr
       ideal_univ_start mkiU : constants.
  
  Import SimulationAutomation.

  #[export] Hint Extern 0 (IdealWorld.lstep_universe _ _ _) =>
    progress(autounfold with constants; simpl) : core.

  #[export] Hint Extern 1 (PERMS__a $? _ = _) => unfold PERMS__a : core.
  #[export] Hint Extern 1 (PERMS__b $? _ = _) => unfold PERMS__b : core.

  #[export] Hint Extern 1 (istepSilent ^* _ _) =>
  autounfold with constants; simpl;
    repeat (ideal_single_silent_multistep A);
    repeat (ideal_single_silent_multistep B); solve_refl : core.
  
End SignPingSendProtocol.

Module EncPingSendProtocol.

  Section IW.
    Import IdealWorld.

    Definition CH__A2B : channel_id := Single 0.
    Definition perms_CH__A2B := 0.

    Definition PERMS__a := $0 $+ (perms_CH__A2B, {| read := false; write := true |}). (* writer *)
    Definition PERMS__b := $0 $+ (perms_CH__A2B, {| read := true; write := false |}). (* reader *)

    Definition ideal_univ_start :=
      mkiU (#0 #+ (CH__A2B, [])) PERMS__a PERMS__b
           (* user A *)
           ( n <- Gen
           ; _ <- Send (Content n) CH__A2B
           ; Return n)

           (* user B *)
           ( m <- @Recv Nat CH__A2B
           ; ret (extractContent m)).

  End IW.

  Section RW.
    Import RealWorld.

    Definition KID__A : key_identifier := 0.
    Definition KID__B : key_identifier := 1.

    Definition KEY__A  := MkCryptoKey KID__A Signing AsymKey.
    Definition KEY__B := MkCryptoKey KID__B Encryption AsymKey.
    Definition KEYS  := $0 $+ (KID__A, KEY__A) $+ (KID__B, KEY__B).

    Definition A__keys := $0 $+ (KID__A, true) $+ (KID__B, false).
    Definition B__keys := $0 $+ (KID__A, false) $+ (KID__B, true).

    Definition real_univ_start :=
      mkrU KEYS A__keys B__keys
           (* user A *)
           ( n  <- Gen
           ; c  <- SignEncrypt KID__A KID__B B (message.Content n)
           ; _  <- Send B c
           ; Return n)

           (* user B *)
           ( c  <- @Recv Nat (SignedEncrypted KID__A KID__B true)
           ; v  <- Decrypt c
           ; ret (extractContent v)).
  
  End RW.

  #[export] Hint Unfold
       A B KID__A KID__B KEY__A KEY__B KEYS A__keys B__keys
       PERMS__a PERMS__b
       real_univ_start mkrU mkrUsr
       ideal_univ_start mkiU : constants.
  
  Import SimulationAutomation.

  #[export] Hint Extern 0 (IdealWorld.lstep_universe _ _ _) =>
    progress(autounfold with constants; simpl) : core.

  #[export] Hint Extern 1 (PERMS__a $? _ = _) => unfold PERMS__a : core.
  #[export] Hint Extern 1 (PERMS__b $? _ = _) => unfold PERMS__b : core.

  #[export] Hint Extern 1 (istepSilent ^* _ _) =>
  autounfold with constants; simpl;
    repeat (ideal_single_silent_multistep A);
    repeat (ideal_single_silent_multistep B); solve_refl : core.
  
End EncPingSendProtocol.
