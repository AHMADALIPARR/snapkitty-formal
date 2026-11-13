# snapkitty-formal

Formal verification stack for **snapkitty** — OCaml library that drives ACL2, Rocq/Coq, Cryptol, SAW, and BLST with a shared capability-aware substrate.

## What this is

Snapkitty-formal is not a single prover. It is an **orchestration and routing layer**:

1. **Surface syntax** — ACL2-pattern `defun` / `defthm` forms (S-expressions).
2. **Capability extraction** — each form is analyzed for required capabilities.
3. **LGRD (Lattice-Greedy Residue Dispatch)** — greedy set-cover over a capability lattice.
4. **Emitters + carry** — per-backend emission and cross-backend obligation carry.
5. **Concrete bridges** — ACL2, Rocq/Coq, Cryptol, SAW, BLST drivers.

Process exit status alone is **not** a soundness argument.

## Status semantics

| Status | Meaning |
|--------|---------|
| `proved` | Process exited 0 for its configured input (process-level only). |
| `failed` | Non-zero exit code. |
| `unknown` | Executable or proof input missing. |
| `unsupported` | External integration (e.g. `BLST_VERIFICATION_DIR`) not configured. |

---

## Custom code (human-authored)

**Author: Ahmad Ali Parr**

The following components are **custom, human-created** work by **Ahmad Ali Parr**.
They extend the substrate with a symbolic term calculus (ACL2), SAW raw-pointer
arithmetic, skip-predicate loops, runback escalation, and a bracket-budget
pipeline operator.

### Symbolic term calculus (ACL2)

`proofs/acl2/calculus.lisp` — package `SNAPKITTY-CALCULUS`:

| Layer | Role |
|-------|------|
| Term calculus | `:var` `:const` `:not` `:and` `:or` `:xor` `:eq` `:ite` `:add` `:mul` |
| Substitution | environment lookup + recursive substitute |
| Boolean semantics | `bool-eval` under an environment |
| Rewrite | `rewrite-once` / `rewrite-fuel` (xor-self → false, const folding) |
| SMT-style constraints | `constraint-system`, `satisfiable-under`, `counterexample-p` |
| Verification conditions | `verification-condition`, `verify-vc` |
| Proof judgments | `derivation`, `proof-obligation` |
| Examples | `*xor-self*`, `xor-self-rewrites-to-false`, integrity theorems |

### SAW pointer + skip / runback pipeline (OCaml)

| Module | Role |
|--------|------|
| `Substrate.Saw_ptr` | Custom `[64]` pointer arithmetic; single boundary cast to `LLVMPointer 8` |
| `Substrate.Budget` | Bracket budget `opens=4` / `closes=5` → base bound + extra retries |
| `Substrate.Skip_loop` | Injectable `fold` over a loop predicate: skip / verify / unroll |
| `Substrate.Runback` | Escalate bound on exhaust; rewind checkpoint state |
| `Substrate.Pipeline` | `spec >^ pipeline` — alloc, custom `points_to`, loop comments, post |

Example emitted SAW fragment (G1 layout, stride 144):

```saw
llvm_alloc : LLVMPointer 8;
llvm_points_to (llvm_term {{ ({{ base_addr }} + 0) : LLVMPointer 8 }}) ...;
llvm_points_to (llvm_term {{ ({{ base_addr }} + 144) : LLVMPointer 8 }}) ...;
// SKIPPED at iter 4: predicate folds to True
llvm_verify m "bls_g1_read" ...;
```

### Fixture

`fixtures/factorial.sexp` — ACL2-pattern factorial + positivity theorem for LGRD routing demos.

### Tests

```bash
dune runtest   # includes test_substrate: budget, raw_ptr, skip_loop, runback, pipeline
```

---

## Installation prerequisites

### Required

| Requirement | Notes |
|-------------|--------|
| **OCaml ≥ 4.14** | Tested against 4.14.x |
| **Dune ≥ 3.10** | |
| **opam 2.x** | |
| **bls12-381-unix ≥ 6.0.0** | First install can take several minutes |
| **alcotest** | Test-only |

```bash
# Debian/Ubuntu
sudo apt-get install -y build-essential m4 pkg-config libgmp-dev opam
opam init -y && opam switch create snapkitty 4.14.1 && eval $(opam env)
```

### Optional tools

ACL2, Coq/Rocq (`coqc`), Cryptol, SAW — bridges degrade to `unknown` when missing.

Env: `ROCQ`, `CRYPTOL`, `SAW`, `BLST_VERIFICATION_DIR`.

### Nix

```bash
nix flake lock && nix develop
```

---

## Concrete build examples

```bash
git clone https://github.com/AHMADALIPARR/snapkitty-formal.git
cd snapkitty-formal
nix flake lock && nix develop
dune build && dune runtest
```

Without Nix:

```bash
opam install . --deps-only -y
dune build && dune runtest
```

Interactive:

```bash
dune utop src
# open Snapkitty_formal;;
# Substrate.Budget.parse_budget ();;
# Substrate.Saw_ptr.raw_add "{{ p }}" 144;;
```

---

## Repository layout

```text
src/substrate/
  syntax, capability, required, lgrd, carry, emit, compile
  budget, saw_ptr, skip_loop, runback, pipeline   # custom (Ahmad Ali Parr)
proofs/acl2/calculus.lisp                        # custom calculus
fixtures/factorial.sexp
test/test_substrate.ml
```

## License

**GNU Affero General Public License v3.0 or later** — see [LICENSE](LICENSE).

Custom modules carry copyright **Ahmad Ali Parr** (2026) under the same license.
