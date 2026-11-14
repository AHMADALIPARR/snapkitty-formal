# snapkitty-formal

**Formal verification orchestration for cryptographic and bit-level software**

`snapkitty-formal` is an OCaml-centred formal verification **orchestration stack**. It does not replace ACL2, Rocq/Coq, Cryptol, SAW, or BLST. It **routes**, **emits**, **drives**, and **records** work across those tools under a shared capability model, with human-authored custom calculus and SAW/Cryptol/Rocq extensions by **Ahmad Ali Parr**.

Process exit codes are **not** treated as cryptographic soundness. Production assurance must bind named theorems and properties in native tool output before any claim that a specific property is proved.

| Item | Value |
|------|--------|
| Primary language | OCaml (≥ 4.14) |
| Build | Dune ≥ 3.10, optional Nix flake |
| License | AGPL-3.0-or-later |
| Custom author | Ahmad Ali Parr |
| Prose custom spec | [docs/CUSTOM_CALCULUS.md](docs/CUSTOM_CALCULUS.md) |
| Repository | https://github.com/AHMADALIPARR/snapkitty-formal |

---

## Table of contents

1. [Purpose and non-goals](#1-purpose-and-non-goals)
2. [Architecture overview](#2-architecture-overview)
3. [Status model](#3-status-model)
4. [Repository map](#4-repository-map)
5. [Substrate and LGRD](#5-substrate-and-lgrd)
6. [Core library modules](#6-core-library-modules)
7. [Backend bridges](#7-backend-bridges)
8. [Custom calculus and primitives](#8-custom-calculus-and-primitives)
9. [Proof artifacts and fixtures](#9-proof-artifacts-and-fixtures)
10. [Installation prerequisites](#10-installation-prerequisites)
11. [Build and test](#11-build-and-test)
12. [Benchmark methodology and reporting](#12-benchmark-methodology-and-reporting)
13. [Operational guidance](#13-operational-guidance)
14. [Novelty posture and attribution](#14-novelty-posture-and-attribution)
15. [License](#15-license)

---

## 1. Purpose and non-goals

### Purpose

Cryptographic software and low-level bit-manipulation code often require more than one formal tool. ACL2 is strong at executable models and induction over integers. Rocq is strong at constructive proofs and extraction. Cryptol is strong at size-indexed bitvector specifications. SAW connects Cryptol to LLVM. BLST and related pairing libraries sit at the C and assembly boundary.

`snapkitty-formal` provides a uniform surface for forms in an ACL2-pattern style; capability extraction so each form declares what kind of reasoning it needs; Lattice-Greedy Residue Dispatch (LGRD) to select a minimal covering set of backends; emitters that produce backend-specific text, plus carry lemmas when obligations must move between tools; process bridges that invoke tools and return a disciplined status enum; and custom extensions (calculus, Unlambda compilation, Galois field heart, ARX/ChaCha Cryptol, SAW pipelines) authored by Ahmad Ali Parr.

### Non-goals

Replacing any backend prover or claiming that a green process exit proves a named cryptographic theorem without parsing native certificates. Vendoring BLST-Verification or asserting that the full BLST implementation is proved. Guaranteeing that SAW, Cryptol, Coq, or ACL2 are installed on every machine; missing tools yield `unknown` or `unsupported`, not silent success. Manufacturing mathematical novelty; the stack is an explicit composition of known techniques.

---

## 2. Architecture overview

```text
                    ┌─────────────────────────────────────┐
                    │     Surface forms (S-exp AST)       │
                    │   defun / defthm  |  custom calculus │
                    └──────────────────┬──────────────────┘
                                       │
                                       ▼
                    ┌─────────────────────────────────────┐
                    │     required capabilities           │
                    │  TotalFn RecFn Prop Arith Ind Extr  │
                    │              FinWord                │
                    └──────────────────┬──────────────────┘
                                       │
                                       ▼
                    ┌─────────────────────────────────────┐
                    │   LGRD  (greedy cover + residue)    │
                    │   Single | Carried | Uncoverable    │
                    └──────────────────┬──────────────────┘
                                       │
              ┌────────────┬───────────┼───────────┬────────────┐
              ▼            ▼           ▼           ▼            ▼
          ┌──────┐    ┌──────┐    ┌────────┐  ┌─────┐     ┌──────┐
          │ ACL2 │    │ Rocq │    │Cryptol │  │ SAW │     │ BLST │
          └──┬───┘    └──┬───┘    └───┬────┘  └──┬──┘     └──┬───┘
             │           │            │          │           │
             └───────────┴────────────┴──────────┴───────────┘
                                       │
                                       ▼
                    ┌─────────────────────────────────────┐
                    │  Status: proved | failed | unknown  │
                    │           | unsupported             │
                    └─────────────────────────────────────┘
```

A form is parsed into the substrate AST. Required capabilities are inferred from operators and binding structure. LGRD scores each backend by how many required capabilities it covers under subsumption, greedily picks the best backend, removes the covered set, and repeats. If a single backend remains, emission is Single. If several are required, the primary emission is paired with carry comments that document cross-backend restatement. Bridges then run external processes and map outcomes into the status enum.

Custom modules sit both beside this path (ACL2 calculus, Haskell Unlambda compiler, Rocq Galois heart) and inside the SAW-oriented substrate (raw pointer arithmetic, skip-predicate loops, runback escalation, pipeline operator).

---

## 3. Status model

| Status | Meaning | Typical cause |
|--------|---------|----------------|
| `proved` | Configured process exited 0 for its configured input | Tool ran and returned success |
| `failed` | Non-zero exit code | Type error, proof failure |
| `unknown` | Executable or proof input missing | Tool not on PATH |
| `unsupported` | Required external integration not configured | BLST_VERIFICATION_DIR unset |

`proved` at this layer means the driver observed a successful process outcome. It does not automatically mean a named theorem is established in the backend kernel. Assurance records should store command lines, commit hashes, logs, and named theorem identifiers.

---

## 4. Repository map

```text
snapkitty-formal/
├── README.md
├── docs/CUSTOM_CALCULUS.md
├── LICENSE
├── flake.nix / dune-project / snapkitty-formal.opam
├── hs/UnlambdaCompiler.hs
├── src/   core | substrate | acl2 | rocq | cryptol | saw | blst
├── proofs/  acl2 | rocq | cryptol | saw
├── fixtures/
├── integrations/blst/
├── test/
└── artifacts/
```

| Directory | Responsibility |
|-----------|----------------|
| `src/core` | Propositional checking, invariants, finite-domain equivalence |
| `src/substrate` | Syntax, capabilities, LGRD, emit, carry; budget, saw_ptr, skip_loop, runback, pipeline |
| `src/*/bridge.ml` | Process or socket integration per backend |
| `proofs/` | Native proof scripts and specs |
| `hs/` | Standalone Haskell combinator compiler |
| `docs/` | Prose custom calculus description |
| `fixtures/` | C and S-expression inputs |
| `test/` | Automated regression |

---

## 5. Substrate and LGRD

### Capabilities

| Capability | Intent |
|------------|--------|
| `TotalFn` | Total function |
| `RecFn` | Recursion with termination witness |
| `Prop` | Propositional structure |
| `Arith` | Integer/natural arithmetic |
| `Ind` | Induction over naturals |
| `Extr` | Extractable definitions |
| `FinWord` | Finite-width word semantics |

### Backend coverage

| Backend | TotalFn | RecFn | Prop | Arith | Ind | Extr | FinWord |
|---------|---------|-------|------|-------|-----|------|---------|
| ACL2 | yes | yes | yes | yes | yes | | |
| Rocq | yes | yes | yes | yes | yes | yes | |
| Cryptol | yes | yes | yes | | | | yes |
| SAW | yes | | yes | yes | | | yes |

### Dispatch outcomes

| Outcome | Meaning |
|---------|---------|
| `Single` | One backend covers all required capabilities |
| `Carried` | Multiple backends with carry documentation |
| `Uncoverable` | Residue remains after greedy cover |

LGRD is a greedy set cover heuristic over the capability lattice, not a completeness theorem for formal methods.

### Custom SAW-oriented substrate

| Module | Role |
|--------|------|
| `Saw_ptr` | Addresses as Cryptol [64]; cast boundary to LLVMPointer 8 |
| `Budget` | opens = base unrolling bound; extra closes = retry budget |
| `Skip_loop` | Injectable fold: skip / verify / unroll |
| `Runback` | Escalate bound; rewind checkpoint state |
| `Pipeline` | spec >^ pipeline composition |

---

## 6. Core library modules

| Module | API focus |
|--------|-----------|
| `Core.Logic` | prop AST, evaluation, tautology, equivalence |
| `Core.Invariants` | Holds / Violated named checks |
| `Core.Equivalence` | Finite-domain spec vs impl comparison |

---

## 7. Backend bridges

| Module | Mechanism |
|--------|-----------|
| `Acl2.Bridge` | TCP S-exp and/or acl2 batch |
| `Rocq.Bridge` | coqc / rocq; extraction helper |
| `Cryptol.Bridge` | cryptol -b / expression eval |
| `Saw.Bridge` | SAW script runner |
| `Blst.Bridge` | bls12-381-unix + external dir check |

Environment overrides: `ROCQ`, `CRYPTOL`, `SAW`, `BLST_VERIFICATION_DIR`.

---

## 8. Custom calculus and primitives

**Author: Ahmad Ali Parr.** Full prose: [docs/CUSTOM_CALCULUS.md](docs/CUSTOM_CALCULUS.md).

Bitwise reduction calculus C_⊕ uses variables, constants 0/1, XOR, and carry-less shift, with self-annihilation, identity, and LFSR-style feedback rules. `hs/UnlambdaCompiler.hs` lowers algebraic expressions through Church encodings, applies B/C/η-optimized bracket abstraction, and emits Unlambda ASCII, packed opcodes, and arena tables. `proofs/rocq/GaloisHeart.v` defines field addition, carry-less multiply, modular reduction, and Fermat inverse over a parameterized irreducible. Cryptol modules provide CustomPrimitives, ARXRound, ChaCha double-round and abstract layers, and Clmul. SAW scripts stage quarter_round, compositional double_round, and clmul-versus-C verification. ACL2 `calculus.lisp` develops term predicates, substitution, rewrite-with-fuel, constraints, and verification conditions.

| Artifact | Role |
|----------|------|
| `CustomPrimitives.cry` | Uninterpreted ops; encrypt/decrypt axiom shape |
| `ARXRound.cry` | quarter_round and inverse |
| `ChaChaDoubleRound.cry` | Eight-step double_round |
| `ChaChaAbstract.cry` | Uninterpreted quarter_round |
| `Clmul.cry` | 64-bit clmul specification |

---

## 9. Proof artifacts and fixtures

| Path | Content |
|------|---------|
| `proofs/acl2/core.lisp` | XOR lemmas |
| `proofs/rocq/Core.v` | Boolean XOR theorems |
| `proofs/cryptol/Primitive.cry` | Bit-level XOR properties |
| `fixtures/xor.c` | C XOR reference |
| `fixtures/arx_round.c` | quarter_round and double_round |
| `fixtures/clmul_shim.c` | PCLMULQDQ surface |
| `fixtures/factorial.sexp` | Factorial routing demo |

---

## 10. Installation prerequisites

| Requirement | Notes |
|-------------|--------|
| OCaml ≥ 4.14 | |
| Dune ≥ 3.10 | |
| opam 2.x | |
| bls12-381-unix ≥ 6.0.0 | Cold build can take minutes |
| alcotest | Tests only |

Optional: ACL2, Coq/Rocq, Cryptol, SAW, clang/LLVM, GHC. Debian/Ubuntu: build-essential, m4, pkg-config, libgmp-dev, opam. macOS Homebrew: opam, gmp, pkg-config.

---

## 11. Build and test

```bash
git clone https://github.com/AHMADALIPARR/snapkitty-formal.git
cd snapkitty-formal
nix flake lock && nix develop   # or opam install . --deps-only -y
dune build && dune runtest
```

| Suite | Focus |
|-------|--------|
| `test_snapkitty` | Logic, invariants, BLST sanity, artifact presence |
| `test_substrate` | Budget, raw_ptr, skip_loop, runback, pipeline |

Interactive: `dune utop src`. Haskell: `ghci hs/UnlambdaCompiler.hs`. Cryptol: `cryptol -b proofs/cryptol/ARXRound.cry`. Bitcode from fixtures via clang into `artifacts/`, then SAW scripts.

---

## 12. Benchmark methodology and reporting

This section defines **how** to measure the stack. Numeric cells must be filled from measured runs on pinned hardware and tool versions before external citation. Do not treat empty cells as published performance claims.

### What to measure

| Metric | Unit | Notes |
|--------|------|-------|
| Cold `dune build` | seconds | Clean tree, warm switch |
| Incremental `dune build` | seconds | Touch one module |
| `dune runtest` | seconds | Full Alcotest |
| LGRD per form | microseconds | Synthetic suite |
| Bridge spawn overhead | milliseconds | Separate tool-internal time when possible |
| Cryptol `-b` | seconds | Per module |
| SAW script wall time | seconds | Solver settings recorded |
| Rocq GaloisHeart compile | seconds | Version pinned |
| UnlambdaCompiler compileExpr | microseconds | Fixed closed terms |
| Arena reduction steps | count | Fixed reducer |

### Environment block (always report)

| Field | Source |
|-------|--------|
| CPU model and frequency | lscpu / system_profiler |
| RAM | |
| OS and kernel | |
| OCaml, Dune, GHC, coqc, Cryptol, SAW, clang | version flags |
| Git commit | `git rev-parse HEAD` |

### Harness profile table (fill after measurement)

| Workload | n | mean | stdev | notes |
|----------|---|------|-------|-------|
| dune build cold | 5 | | | exclude dep compile |
| dune runtest | 5 | | | |
| compile_form × 1000 | 5 | | | pure OCaml |
| cryptol -b ARXRound | 5 | | | |
| SAW quarter_round | 3 | | | timeouts noted |
| gf_mul bit-serial vs LUT | 5 | | | extracted Haskell |

### Combinator compiler profile

Measure node counts for λx. x ⊕ x under naïve versus B/C/η abstraction; measure emitUnlambda length; measure arena length and reduction steps. Expect near-linear growth in combinator size versus AST size when B/C/η are enabled.

### Cryptol / SAW / LLVM profile

Cryptol typecheck should be fast for executable specs. SAW quarter_round is solver-bound; report Z3/ABC parameters. Compositional double_round with overrides should avoid re-expanding eight bodies if overrides apply. clmul verification requires bitcode built with PCLMUL support.

### Field arithmetic profile

Compare gf_add (XOR), bit-serial gf_mul, LUT gf_mul (64 KiB table), and Barrett+clmul64 hardware paths. Exhaustive 65,536-pair correctness belongs in Rocq reflection or offline jobs; throughput belongs in timed harnesses on pinned CPUs.

### Reporting rules

1. Pin commit SHA and tool versions.
2. Separate correctness jobs from throughput jobs.
3. Never upgrade process-level proved into a named cryptographic theorem claim without native certificates.
4. Label incomplete measurement preliminary.

---

## 13. Operational guidance

| CI job | Steps |
|--------|-------|
| ocaml | deps, dune build, dune runtest |
| cryptol | cryptol -b on each .cry (skip if absent) |
| haskell | ghc -c or GHCi load UnlambdaCompiler |
| saw-optional | bitcode + SAW only on equipped runners |

| Symptom | Action |
|---------|--------|
| bls12-381-unix failure | Check gmp and C toolchain |
| proofs path missing in tests | Run from repo root |
| Bridge unknown | Install tool or accept degradation |
| SAW import errors | Working directory and Cryptol paths |
| PCLMUL errors | -mpclmul and CPU flags |

Assurance records should include commits, commands, environment, tool versions, logs, exit codes, named theorems from native output, and explicit trusted admits.

---

## 14. Novelty posture and attribution

No novelty is manufactured for academic priority. ACL2-pattern surface, multi-backend emission, capability residue routing (greedy set cover), B/C/η abstraction, Cryptol+SAW patterns, and GF(2^n) XOR/clmul/reduce are standard. Custom human-authored material by **Ahmad Ali Parr** includes SNAPKITTY-CALCULUS, UnlambdaCompiler as integrated here, GaloisHeart/BracketSoundness sketches, Cryptol ARX/ChaCha/Clmul/CustomPrimitives, SAW scripts and C fixtures, OCaml substrate budget/saw_ptr/skip_loop/runback/pipeline, and docs/CUSTOM_CALCULUS.md.

---

## 15. License

**GNU Affero General Public License v3.0 or later.** See [LICENSE](LICENSE). Custom modules: copyright Ahmad Ali Parr (2026), same license. Network deployment triggers AGPL source-offer obligations; read the full license before distribution.

---

## Appendix A — Quick command card

| Task | Command |
|------|---------|
| Build | `dune build` |
| Test | `dune runtest` |
| Utop | `dune utop src` |
| Nix shell | `nix develop` |
| Cryptol | `cryptol -b proofs/cryptol/ARXRound.cry` |
| GHC | `ghci hs/UnlambdaCompiler.hs` |
| Prose custom | `docs/CUSTOM_CALCULUS.md` |

## Appendix B — Glossary

| Term | Meaning |
|------|---------|
| LGRD | Lattice-Greedy Residue Dispatch |
| Carry | Cross-backend obligation restatement |
| FinWord | Finite-width word capability |
| Uninterpreted primitive | Symbol without body; axiom-driven |
| Process-level proved | Exit code success only |
| Arena | Flat L/R table for combinator reduction |

## Appendix C — Document control

| Field | Value |
|-------|--------|
| Scope | Full repository orientation |
| Companion | docs/CUSTOM_CALCULUS.md |
| Benchmarks | Methodology mandatory; numbers from measured runs |

## Appendix D — Security and assurance notes

Formal tools reduce classes of implementation error; they do not remove the need for secure key management, side-channel analysis, or adversarial testing. BLST pairing sanity checks validate linkage at smoke level only. Production pairing protocols need pinned dependencies, independent review of specifications, SAW or equivalent proofs for shipped object code, and operational monitoring. Document every admitted axiom. Prefer explicit Cryptol widths and join/split at byte-oriented boundaries. Keep model, implementation, and deployment scope distinct in reports so proved relationships are not overstated.

---

*End of README.*
