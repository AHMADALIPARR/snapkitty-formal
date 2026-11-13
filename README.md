# snapkitty-formal

Formal verification stack for **snapkitty** — OCaml library that drives ACL2, Rocq/Coq, Cryptol, SAW, and BLST with a shared capability-aware substrate.

## What this is

Snapkitty-formal is not a single prover. It is an **orchestration and routing layer**:

1. **Surface syntax** — ACL2-pattern `defun` / `defthm` forms (S-expressions).
2. **Capability extraction** — each form is analyzed for required capabilities (total/recursive functions, propositional structure, arithmetic, induction, extraction, finite words).
3. **LGRD (Lattice-Greedy Residue Dispatch)** — greedy set-cover over a capability lattice chooses the minimal set of backends that can discharge the form.
4. **Emitters + carry** — code is emitted for the chosen backend(s). When more than one backend is needed, a *carry* lemma is produced so obligations proven in one tool can be restated in another.
5. **Concrete bridges** — process-level drivers for ACL2, Rocq/Coq, Cryptol, SAW, and BLST (plus an external BLST-Verification checkout check).

Process exit status alone is **not** a soundness argument. Production use must parse native tool output and bind named theorems/properties before claiming them proved.

## Status semantics

| Status        | Meaning |
|---------------|---------|
| `proved`      | Configured process exited 0 for its configured input. Process-level only. |
| `failed`      | Non-zero exit code. |
| `unknown`     | Executable or proof input missing, or process could not start. |
| `unsupported` | Required external integration (e.g. `BLST_VERIFICATION_DIR`) not configured. |

## Quick start

```bash
nix flake lock
nix develop
dune build
dune runtest
nix build
```

Without Nix (opam switch with OCaml ≥ 4.14):

```bash
opam install . --deps-only -y
dune build
dune runtest
```

## Repository layout

```text
.
├── flake.nix / snapkitty-formal.opam / dune-project
├── src/
│   ├── dune                          # (include_subdirs qualified)
│   ├── core/
│   │   ├── logic.ml                  # prop, eval, is_tautology, equivalent
│   │   ├── invariants.ml             # Holds / Violated, run_all, report
│   │   └── equivalence.ml            # finite-domain check_equiv
│   ├── substrate/
│   │   ├── syntax.ml                 # sexp, defun, defthm AST
│   │   ├── capability.ml             # capability lattice + backends
│   │   ├── required.ml               # required-capability extraction
│   │   ├── lgrd.ml                   # Lattice-Greedy Residue Dispatch
│   │   ├── carry.ml                  # cross-backend obligation carry
│   │   ├── emit.ml                   # per-backend emitters
│   │   └── compile.ml                # compile_form → Single | Carried | Uncoverable
│   ├── acl2/bridge.ml                # TCP S-exp protocol + batch fallback
│   ├── rocq/bridge.ml                # coqc / rocq compile + extraction
│   ├── cryptol/bridge.ml             # cryptol -b / -e
│   ├── saw/bridge.ml                 # SAW script runner
│   └── blst/bridge.ml                # bls12-381-unix + external check
├── proofs/
│   ├── acl2/{core.lisp,invariants.lisp}
│   ├── rocq/{Core.v,invariants.v}
│   ├── cryptol/{Primitive.cry,invariants.cry}
│   └── saw/{primitive.saw,verify.saw}
├── fixtures/xor.c                    # C reference for future SAW LLVM proofs
├── integrations/blst/README.md       # external BLST-Verification notes
├── test/
└── artifacts/
```

## Substrate (LGRD) in brief

**Capabilities** (partial order under subsumption):

- `TotalFn`, `RecFn`, `Prop`, `Arith`, `Ind`, `Extr`, `FinWord`

**Backends and what they cover:**

| Backend  | Capabilities |
|----------|----------------|
| ACL2     | TotalFn, RecFn, Prop, Arith, Ind |
| Rocq     | TotalFn, RecFn, Prop, Arith, Ind, Extr |
| Cryptol  | TotalFn, RecFn, Prop, FinWord |
| SAW      | TotalFn, Prop, Arith, FinWord |

`compile_form` returns:

- `Single (backend, code)` — one backend covers all required capabilities
- `Carried ((primary, code), carries)` — split across backends with carry lemmas
- `Uncoverable gap` — no combination of backends can cover the residue

## Bridges

| Module | Role |
|--------|------|
| `Acl2.Bridge` | TCP S-expression client (ACL2 Bridge protocol) + `acl2 -qq` batch fallback |
| `Rocq.Bridge` | `coqc` / `rocq` compile and Extraction Language OCaml |
| `Cryptol.Bridge` | `cryptol -b` typecheck / batch; `-e` expression eval |
| `Saw.Bridge` | Run SAW scripts; `llvm_ffi_setup` snippet helper |
| `Blst.Bridge` | Thin `bls12-381-unix` wrapper + `BLST_VERIFICATION_DIR` configuration check |

Set optional env overrides: `ROCQ`, `CRYPTOL`, `SAW`, `BLST_VERIFICATION_DIR`.

## Proof artifacts

- **ACL2** — `sk-xor`, `xor-zero-right`, `xor-commutative`; add-zero identity
- **Rocq** — boolean XOR theorems; `add_zero` with extraction skeleton
- **Cryptol** — bit-level XOR properties; `[32]` add-zero property
- **SAW** — smoke-test script + commented LLVM/Cryptol verification skeleton
- **Fixture** — `fixtures/xor.c` for future SAW bitcode equivalence proofs

## Tests

```bash
dune runtest
```

Covers tautology checking, invariant runners, BLST pairing sanity, proof-file presence, and substrate backend registration.

## License

**GNU Affero General Public License v3.0 or later** (AGPL-3.0-or-later).

See [LICENSE](LICENSE). All OCaml sources carry SPDX headers.

## Novelty posture

No novelty is manufactured. The composition is built from known parts:

- ACL2-pattern surface syntax — established style
- Canonical AST + per-backend emitters — same class as F*, Why3, hs-to-coq
- Capability-residue routing — corresponds to greedy set cover (Chvátal 1979)
- Proof-obligation carry — named construction; pieces have precedent
- The package as a whole is a composition, not a claim of new mathematics
