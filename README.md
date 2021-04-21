# Secure Protocols Implemented CorrectlY (SPICY)

This repository contains the main developments of the SPICY protocol development and specification tool.

## Repository Layout

This repository has three top-level directories:
* Frap -- we bootstrapped the project by using some developments from the FRAP library
* src -- core library code, including Domain Specific Languages (DSLs), their semantics, and the safety theorem
* protocols -- several test protocols proven correct

Some good places to start to get a feel for the formalized languages and main safety result:

* src/IdealWorld.v -- formalization of the Ideal World language.
* src/RealWorld.v -- formalization of the Real World language.
* src/Simulation.v -- development of our simulation statements between the Ideal and Real worlds (the actual simulation definitions can be found in the "Simulation" section).
* src/AdversarySafety.v -- the main theorems and lemmas stating the safety result.

The main safety results within AdversarySafety warrant some further discussion.
The last theorem (`refines_could_generate`) is the statement that if a Real
World protocol refines an Ideal World protocol, then traces in the Real World
can be reproduced in the Ideal World. A few hundred lines up from there, in
`refines_ok_with_adversary` is the main lemma supporting
`refines_could_generate` where we show that, starting from a refinement
condition in a universe with no adversary, we can inject arbitrary adversary
code and obtain a refinement condition within this new universe.

Using the above library code, we have verified several exemplar protocols. Some of them are split across three files so that we could test out the performance of different model checking techniques.  The 'SS' ones are the correct ones to focus on, since they do some model search pruning.

* protocols/PGP.v (protocol impl) and protocols/PGPSS.v (correctness proof) -- describes a secret sharing protocol inspired by the PGP protocol.
* protocols/SecureDNS.v (protocol impl) and protocols/SecureDNSSS.v (correctness proof) -- describes a protocol similar in spirit to (but much simplified) Daniel Bernstein's DNSCurve for encrypted DNS.
* protocols/AvgSalary.v -- describes a simple aggregation service, interesting because it involves more than two parties.
* protocols/P2P.v -- describes a network authentication protocol by a trusted third party (inspired by Kerberos)

## Setup

Setup notes for future me.


### Installing coq

Make sure coq is installed an on the path.  I find it convenient to
install via opam, using switches.  Some quick notes on how to do that:

The *first* time you use opam, you need to set up your environment.

```bash
opam init

opam repo add coq-released https://coq.inria.fr/opam/released --set-default
```

Now, whenever you want to install a new version, just do:

```bash
opam update

opam switch create coq-<ver> ocaml-base-compiler.4.08.1

opam install coq.<ver>
opam pin add coq <ver>
```

### Compiling Project

```bash
'clone repo'

# Pull in submodules
git submodule update --init --recursive

make paper-fast
```

## Disclaimer

© 2019-2021 XXX

The software/firmware is provided to you on an As-Is basis
