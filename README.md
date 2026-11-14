# snapkitty-formal

Formal verification stack for **snapkitty** — OCaml library that drives ACL2, Rocq/Coq, Cryptol, SAW, and BLST with a shared capability-aware substrate.

## What this is

Orchestration and routing layer: ACL2-pattern surface syntax, capability extraction, LGRD dispatch, emitters/carry, and concrete bridges. Process exit status alone is not a soundness argument.

## Status semantics

| Status | Meaning |
|--------|---------|
| `proved` | Process exited 0 (process-level only). |
| `failed` | Non-zero exit. |
| `unknown` | Tool or input missing. |
| `unsupported` | External integration not configured. |

---

## Custom code (human-authored)

**Author: Ahmad Ali Parr**

Prose specification (no embedded source): **[docs/CUSTOM_CALCULUS.md](docs/CUSTOM_CALCULUS.md)** — Galois/bitwise calculus C_⊕, optimized SKI/Unlambda compilation, Rocq field heart and soundness sketch, Cryptol/SAW primitives and axioms, and build steps.

### Implementations on this repository

| Path | Role |
|------|------|
| `docs/CUSTOM_CALCULUS.md` | Prose-only description |
| `hs/UnlambdaCompiler.hs` | Bracket abstraction + Unlambda / binary / arena emitters |
| `proofs/acl2/calculus.lisp` | SNAPKITTY-CALCULUS term/rewrite/SMT/VC |
| `proofs/rocq/GaloisHeart.v` | F_2^n add, clmul, reduce, inv |
| `proofs/rocq/BracketSoundness.v` | Denotational soundness sketch for B/C/η |
| `proofs/cryptol/CustomPrimitives.cry` | Uninterpreted custom ops, encrypt/decrypt axioms |
| `proofs/cryptol/ARXRound.cry` | ChaCha-style quarter_round + inverse |
| `proofs/cryptol/ChaChaDoubleRound.cry` | Compositional double_round |
| `proofs/cryptol/ChaChaAbstract.cry` | Uninterpreted quarter_round layer |
| `proofs/cryptol/Clmul.cry` | 64-bit carry-less multiply spec |
| `proofs/saw/arx_verify.saw` | SAW quarter_round contract |
| `proofs/saw/chacha_compositional.saw` | Compositional double_round |
| `proofs/saw/clmul.saw` | clmul vs C shim |
| `fixtures/arx_round.c` | C ARX / double_round |
| `fixtures/clmul_shim.c` | PCLMULQDQ shim |
| `src/substrate/{saw_ptr,budget,skip_loop,runback,pipeline}.ml` | SAW ptr + skip/runback pipeline |
| `test/test_substrate.ml` | Substrate unit tests |

---

## Installation prerequisites

OCaml ≥ 4.14, Dune ≥ 3.10, opam 2.x, bls12-381-unix, alcotest. Optional: ACL2, coqc/rocq, Cryptol, SAW.

```bash
sudo apt-get install -y build-essential m4 pkg-config libgmp-dev opam
opam init -y && opam switch create snapkitty 4.14.1 && eval $(opam env)
```

Nix: `nix flake lock && nix develop`

---

## Build

```bash
git clone https://github.com/AHMADALIPARR/snapkitty-formal.git
cd snapkitty-formal
nix develop   # or: opam install . --deps-only -y
dune build && dune runtest
```

Haskell combinator compiler: open `hs/UnlambdaCompiler.hs` in GHCi.

Cryptol: `cryptol -b proofs/cryptol/ARXRound.cry`

C → bitcode → SAW: compile fixtures under `fixtures/` to `artifacts/*.bc`, then run scripts under `proofs/saw/`.

---

## License

**GNU Affero General Public License v3.0 or later** — see [LICENSE](LICENSE).

Custom modules: copyright **Ahmad Ali Parr** (2026), same license.
