# snapkitty-formal

Formal verification stack for snapkitty (ACL2, Rocq, Cryptol, SAW, BLST).

OCaml library with a **substrate** layer (ACL2-pattern surface syntax, capability
lattice, Lattice-Greedy Residue Dispatch, proof-obligation carry) plus concrete
bridges to native proof tools.

## Status semantics

| Status        | Meaning |
|---------------|---------|
| `proved`      | Configured process exited successfully for its input. Process-level only. |
| `failed`      | Process returned non-zero exit code. |
| `unknown`     | Executable or proof input missing / could not be started. |
| `unsupported` | Required external integration (e.g. `BLST_VERIFICATION_DIR`) not configured. |

Production use must parse native tool output and identify exact theorem /
property names before reporting named properties as proved.

## Quick start

```bash
nix flake lock
nix develop
dune build
dune runtest
nix build
```

## Layout

```text
.
├── flake.nix
├── dune-project
├── snapkitty-formal.opam
├── src/
│   ├── dune                    # (include_subdirs qualified)
│   ├── core/
│   │   ├── logic.ml
│   │   ├── invariants.ml
│   │   └── equivalence.ml
│   ├── substrate/
│   │   ├── syntax.ml
│   │   ├── capability.ml
│   │   ├── required.ml
│   │   ├── lgrd.ml
│   │   ├── carry.ml
│   │   ├── emit.ml
│   │   └── compile.ml
│   ├── acl2/bridge.ml
│   ├── rocq/bridge.ml
│   ├── cryptol/bridge.ml
│   ├── saw/bridge.ml
│   └── blst/bridge.ml
├── proofs/
├── fixtures/xor.c
├── integrations/blst/
├── test/
└── artifacts/
```

## Substrate (LGRD)

Forms are written in an ACL2-pattern surface syntax (`defun` / `defthm`).
Required capabilities are extracted, then Lattice-Greedy Residue Dispatch
selects a minimal covering set of backends. When more than one backend is
needed, a **carry** lemma is emitted so obligations proven in one backend
can be restated in another.

## License

GNU Affero General Public License v3.0 or later — see [LICENSE](LICENSE).
