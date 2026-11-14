# Custom calculus, primitives, axioms, and proofs

**Author: Ahmad Ali Parr (human-authored)**

This document is prose only. Implementation sources live under `hs/`, `proofs/`, and `fixtures/`. It describes the Galois / bitwise reduction calculus, Unlambda compilation, Cryptol/SAW/Rocq primitives and axioms, and how to build and discharge the associated obligations.

---

## 1. Galois / Bitwise Reduction Calculus

We work with a minimal calculus C_⊕ whose terms are built from variables, the constants 0 and 1, exclusive-or (⊕), and a carry-less shift (◃). The equational theory has three core rules:

1. Self-annihilation: x ⊕ x reduces to 0.
2. Identity: x ⊕ 0 reduces to x.
3. LFSR / field feedback step: (x ◃ 1) ⊕ x reduces to a designated step of x over F_2^n.

These rules are the algebraic backbone for XOR-based rewriting, GF(2) linear feedback, and the later field-arithmetic heart used for AES-style and GCM-style polynomials.

To run the calculus in a variable-free setting (Unlambda), terms are compiled into the SKI basis via Schönfinkel/Curry bracket abstraction. Church encodings of bits are used so that diagonal application of ⊕ to a single term reduces to the zero combinator.

---

## 2. Optimized bracket abstraction (B, C, η)

Naive bracket abstraction produces quadratic blow-up by inserting S and K at every spine node. Turner’s B and C combinators together with η-contraction keep compiled graphs linear in the size of the source AST:

- If x is not free in M and N is exactly x, η-reduce to M.
- If x is free in neither M nor N, hoist with K.
- If x is free only in N, use B (right-threaded composition).
- If x is free only in M, use C (left-threaded swap).
- If x is free in both, use S (diagonal fork).

In Unlambda, B and C may be expanded to pure SK macros, or kept as native opcodes in a binary VM. Native B and C each allocate a single new graph node per reduction step, versus two for S and many more if expanded fully to SK.

The Haskell module `hs/UnlambdaCompiler.hs` lowers algebraic primitives (XOR, AND, bits, delay, call/cc) into a combinator AST, runs the optimized abstractor, and emits three targets: Unlambda ASCII prefix code, a packed 3-bit opcode stream, and a flat (L, R) arena table for in-place graph reduction. Compiling the closed term λx. (x ⊕ x) under the optimized regime produces a compact combinator graph rather than a large nested S/K tree.

---

## 3. Denotational soundness (Rocq)

Soundness of the optimized abstractor is stated as denotational equivalence: evaluating the compiled combinator on a value v in an environment agrees with evaluating the source lambda term in the environment extended by binding x to v.

The development in `proofs/rocq/BracketSoundness.v` introduces source lambda syntax, target combinators (I, K, S, B, C), a functional value domain, and the intended theorem form. The inductive argument on the source term follows the usual cases:

- Variable: I or K according to whether the name matches x.
- Application: K when x is free in neither subterm; B or C when free in exactly one; S when free in both.
- Each case mirrors environment update in the denotation of the corresponding combinator.

---

## 4. Algebraic heart of F_2^n (Rocq)

For AES-style fields (degree 8, irreducible 0x11B) and related GCM polynomials, the core field operations reduce to machine-word primitives over binary naturals:

- Field addition is bitwise XOR.
- Carry-less multiplication is shift-and-XOR convolution without carry.
- Modular reduction is a polynomial remainder modulo the chosen irreducible.
- Multiplicative inverse uses Fermat’s little theorem over the field (exponent 2^n − 2).

`proofs/rocq/GaloisHeart.v` packages these definitions in a module parameterized by an irreducible polynomial, with kernel-level lemmas for commutativity of addition and self-annihilation (a ⊕ a = 0).

Extraction is configured so that Rocq N maps to strict Haskell words and bit operations, yielding a self-contained extracted module. Dense unboxed functors over Word8 then lift the extracted field operations for block and matrix arithmetic. A 65,536-entry multiplication LUT can be reflection-checked against the bit-serial specification; Barrett reduction with a hardware clmul primitive is stated as equivalent for the AES polynomial once exhaustive or modular bounds are discharged.

A C shim exposing 64-bit carry-less multiply (PCLMULQDQ) can be bound from Haskell and verified against a Cryptol specification of clmul64 via SAW over LLVM bitcode.

---

## 5. Cryptol custom primitives and axioms

Custom Cryptol modules under `proofs/cryptol/` declare uninterpreted primitives and executable ARX/ChaCha specs:

- Unary and binary custom operators, and an explicit state-step primitive, for compositional reasoning without unfolding bodies.
- Encrypt/decrypt primitives with the intended axiom that decryption inverts encryption for all keys, tweaks, and blocks.
- Unary involution axiom: applying a custom unary twice yields the identity.
- Executable quarter-round and double-round specifications for ChaCha-style ARX, including an inverse quarter-round and a left-inverse property.
- Abstract ChaCha modules where quarter_round remains primitive so higher layers reason by congruence without expanding the ARX body.
- A pure Cryptol specification of 64-bit carry-less multiply for SAW contracts against C/LLVM implementations.

Trusted axioms are introduced with explicit admit-style justifications in SAW scripts; subsequent goals are discharged by simplification under those rules (for example nested encrypt/decrypt round-trips collapse to the identity).

---

## 6. SAW verification patterns

SAW scripts under `proofs/saw/` load Cryptol specs and LLVM bitcode and state functional equivalence:

- Stage 1: verify a single quarter_round against the Cryptol ARX spec over all 2^128 state patterns (modulo solver capacity and overrides).
- Stage 2: verify double_round compositionally, supplying the stage-1 override so each of the eight quarter-round calls uses the proven contract rather than re-expanding the body.
- Uninterpreted mode: assume a contract for quarter_round (or an external/HW hash) and verify the outer fold while keeping the primitive opaque to the SMT solver.
- clmul: verify a C PCLMUL shim against the Cryptol clmul64 specification.

Bitcode is produced from the C fixtures under `fixtures/` (for example with clang -O1 -g -emit-llvm, and -mpclmul where required).

---

## 7. Build steps (summary)

Haskell combinator compiler: load `hs/UnlambdaCompiler.hs` in GHC or GHCi; call compileExpr / emitUnlambda / emitArena on closed algebraic terms (for example λx. x ⊕ x).

Rocq field heart: compile `proofs/rocq/GaloisHeart.v` (and extraction scripts when present); instantiate the AES polynomial module; optionally extract to Haskell and link dense unboxed wrappers.

Cryptol: typecheck modules under `proofs/cryptol/` with cryptol -b; use uninterpreted primitives with prove_print and admit only for explicitly trusted axioms.

C to bitcode: compile fixtures under `fixtures/` to `artifacts/*.bc`, then run the corresponding SAW scripts under `proofs/saw/`.

Full stack: prefer the project Nix shell or an opam switch with OCaml, dune, and optional coq, cryptol, and saw on PATH, as described in the main README installation and build sections.

---

## 8. File map (implementations, not this document)

| Area | Location |
|------|----------|
| Unlambda / SKI compiler | `hs/UnlambdaCompiler.hs` |
| Bitwise / XOR calculus (ACL2) | `proofs/acl2/calculus.lisp` |
| Galois field heart | `proofs/rocq/GaloisHeart.v` |
| Bracket soundness sketch | `proofs/rocq/BracketSoundness.v` |
| Cryptol primitives / ARX / ChaCha / clmul | `proofs/cryptol/*.cry` |
| SAW scripts | `proofs/saw/arx_verify.saw`, `chacha_compositional.saw`, `clmul.saw` |
| C fixtures | `fixtures/arx_round.c`, `fixtures/clmul_shim.c` |
| Substrate SAW pipeline (OCaml) | `src/substrate/{saw_ptr,budget,skip_loop,runback,pipeline}.ml` |

All of the above custom material is human-authored by Ahmad Ali Parr under AGPL-3.0-or-later.
