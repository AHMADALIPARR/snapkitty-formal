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

---

## Installation prerequisites

### Required

| Requirement | Notes |
|-------------|--------|
| **OCaml ≥ 4.14** | Tested against 4.14.x; 5.x should work if `bls12-381-unix` supports your switch |
| **Dune ≥ 3.10** | From the system package manager or `opam install dune` |
| **opam 2.x** | Needed for dependency resolution outside pure Nix builds |
| **bls12-381-unix ≥ 6.0.0** | Pulls in the blst C library; first install can take several minutes |
| **alcotest** | Test-only dependency (`opam install alcotest`) |

On Debian/Ubuntu before opam:

```bash
sudo apt-get update
sudo apt-get install -y build-essential m4 pkg-config libgmp-dev opam
```

On macOS (Homebrew):

```bash
brew install opam gmp pkg-config
```

Then:

```bash
opam init -y
opam switch create snapkitty 4.14.1   # or another ≥ 4.14
eval $(opam env)
```

### Optional (native proof tools)

Bridges degrade to `unknown` / `unsupported` when a tool is missing; the OCaml library still builds.

| Tool | Used by | Typical install |
|------|---------|-----------------|
| **ACL2** | `Acl2.Bridge` | Distro package or [acl2.org](https://www.acl2.org) build |
| **Coq / Rocq** (`coqc` or `rocq`) | `Rocq.Bridge` | `opam install coq` or Nix `coq` |
| **Cryptol** | `Cryptol.Bridge` | [Galois Cryptol releases](https://github.com/GaloisInc/cryptol) or Nix |
| **SAW** | `Saw.Bridge` | [Galois SAW](https://github.com/GaloisInc/saw-script) or Nix |
| **clang / LLVM** | Future SAW bitcode proofs against `fixtures/xor.c` | System LLVM packages |

Environment overrides (optional):

```bash
export ROCQ=coqc          # or path to rocq
export CRYPTOL=cryptol
export SAW=saw
export BLST_VERIFICATION_DIR=/path/to/reviewed/blst-verification
```

### Nix

If you use the flake, the dev shell aims to provide OCaml, dune, Coq, Cryptol, and SAW when those packages exist on your `nixpkgs` channel. Pin with:

```bash
nix flake lock
nix develop
```

Internet access is required the first time for `nix flake lock` / `opam update`.

### Disk / time

- Cold `opam install bls12-381-unix` can take 5–15 minutes (C + OCaml bindings).
- Full `nix develop` on a clean machine may download several hundred MB of store paths.


## Concrete build examples

### 1. Nix flake (recommended)

```bash
# Clone and enter the project
git clone https://github.com/AHMADALIPARR/snapkitty-formal.git
cd snapkitty-formal

# Pin the dependency graph (commit the resulting flake.lock)
nix flake lock

# Enter the dev shell (OCaml, dune, SAW, Cryptol, Coq, …)
nix develop

# Inside the shell:
dune build          # build the library
dune runtest        # run Alcotest suite
dune build @doc     # optional: odoc (if odoc is in the switch)

# Build the package derivation from outside the shell
nix build
./result/bin/…      # if the package exposes executables later
```

### 2. Plain opam + dune (no Nix)

```bash
# Requires OCaml ≥ 4.14 and opam 2.x
opam switch create snapkitty 4.14.1   # or use an existing switch
eval $(opam env)

# Install project dependencies from the local .opam file
opam install . --deps-only -y
# If bls12-381-unix is slow to build the first time, that is expected.

dune build
dune runtest
```

### 3. One-shot clean rebuild

```bash
dune clean
dune build -p snapkitty-formal -j $(nproc)
dune runtest -p snapkitty-formal
```

### 4. Interactive utop session

```bash
dune utop src
```

Then in utop:

```ocaml
open Snapkitty_formal;;

(* Core logic *)
Core.Logic.is_tautology
  (Core.Logic.Imp (Core.Logic.Atom "x", Core.Logic.Atom "x"));;
(* - : bool = true *)

(* BLST sanity *)
Blst.Bridge.pairing_sanity ();;
(* - : bool = true *)

(* Substrate: how many backends are registered? *)
List.length Substrate.Capability.all_backends;;
(* - : int = 4 *)

(* Dispatch a trivial defthm through LGRD *)
let form =
  Substrate.Syntax.Defthm {
    dt_name = "id_prop";
    dt_statement = Substrate.Syntax.List [
      Substrate.Syntax.Atom "implies";
      Substrate.Syntax.Atom "P";
      Substrate.Syntax.Atom "P";
    ];
    dt_hint = None;
  } in
Substrate.Compile.compile_form form;;
```

### 5. Drive native proof tools via bridges

From the project root (tools must be on `PATH`, or set `ROCQ` / `CRYPTOL` / `SAW`):

```bash
# After: dune build
dune exec -- ocaml <<'OCAML'
  #use "topfind";;
  #require "snapkitty-formal";;
  open Snapkitty_formal;;

  let (st, out, err) = Acl2.Bridge.verify_core ~root:"." () in
  Printf.printf "ACL2: %s\n%s%s\n"
    (Acl2.Bridge.status_to_string st) out err;;

  let (st, out, err) = Rocq.Bridge.verify_core ~root:"." () in
  Printf.printf "Rocq: %s\n%s%s\n"
    (Rocq.Bridge.status_to_string st) out err;;

  let (st, out, err) = Cryptol.Bridge.verify_core ~root:"." () in
  Printf.printf "Cryptol: %s\n%s%s\n"
    (Cryptol.Bridge.status_to_string st) out err;;

  let (st, out, err) = Saw.Bridge.verify_core ~root:"." () in
  Printf.printf "SAW: %s\n%s%s\n"
    (Saw.Bridge.status_to_string st) out err;;
OCAML
```

Or call the same APIs from a small `bin/` executable / test once you add one.

### 6. BLST external verification check

```bash
# Unset → Unsupported
unset BLST_VERIFICATION_DIR
dune utop src
# Blst.Bridge.check_external_verification ();;

# Point at a reviewed upstream checkout → Proved (config check only)
export BLST_VERIFICATION_DIR=/path/to/blst-verification
# Blst.Bridge.check_external_verification ();;
```

See `integrations/blst/README.md` — this adapter only checks that the directory exists; it does not claim a cryptographic proof of BLST.

### 7. Run a single Alcotest case

```bash
dune runtest --test-case "tautology"
dune runtest --test-case "pairing sanity"
```

### 8. Typical first-time failure modes

| Symptom | Fix |
|---------|-----|
| `bls12-381-unix` not found | `opam install bls12-381-unix` or use `nix develop` |
| `coqc: command not found` | Install Coq / Rocq, or rely on Nix `formalTools` |
| `cryptol` / `saw` missing | Same — Nix shell provides them when available in the channel |
| Tests fail on proof-file paths | Run tests from the **repo root** so `proofs/` resolves |
| `ACL2 bridge` Unknown | Install `acl2` or use the batch script only when the binary is present |

---

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
