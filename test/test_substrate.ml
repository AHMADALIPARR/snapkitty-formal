(*
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Copyright (C) 2026 Ahmad Ali Parr
 *
 * Custom substrate tests — human-authored by Ahmad Ali Parr.
 *)

open Snapkitty_formal

let contains_substr hay needle =
  let hlen = String.length hay and nlen = String.length needle in
  let rec go i =
    if i + nlen > hlen then false
    else if String.sub hay i nlen = needle then true
    else go (i + 1)
  in
  go 0

let stub_fold_after (n : int) : Substrate.Skip_loop.fold =
  fun _pred ->
    if n >= 4 then Substrate.Skip_loop.Const_true
    else Substrate.Skip_loop.Symbolic "residual"

let () =
  Alcotest.run "substrate"
    [
      ( "budget",
        [
          Alcotest.test_case "parse budget opens/closes" `Quick (fun () ->
              let b = Substrate.Budget.parse_budget () in
              Alcotest.(check int) "opens" 4 b.Substrate.Budget.opens;
              Alcotest.(check int) "closes" 5 b.Substrate.Budget.closes;
              Alcotest.(check int) "base_bound" 4
                (Substrate.Budget.base_bound b);
              Alcotest.(check int) "extra_retries" 1
                (Substrate.Budget.extra_retries b));
        ] );
      ( "raw_ptr",
        [
          Alcotest.test_case "add" `Quick (fun () ->
              Alcotest.(check string) "p + 144"
                "{{ ({{ p }} + 144) : [64] }}"
                (Substrate.Saw_ptr.raw_add "{{ p }}" 144));
          Alcotest.test_case "cast" `Quick (fun () ->
              Alcotest.(check string) "cast"
                "(llvm_term {{ {{ p }} : LLVMPointer 8 }})"
                (Substrate.Saw_ptr.cast_to_llvm_ptr "{{ p }}"));
          Alcotest.test_case "custom_ptr_at stride=144 i=2" `Quick (fun () ->
              Alcotest.(check string) "p+288 cast"
                "(llvm_term {{ {{ ({{ p }} + 288) : [64] }} : LLVMPointer 8 }})"
                (Substrate.Saw_ptr.custom_ptr_at ~base:"{{ p }}" ~stride:144
                   ~index:2));
        ] );
      ( "skip_loop",
        [
          Alcotest.test_case "skip on Const_true" `Quick (fun () ->
              let r =
                Substrate.Skip_loop.skip_predicate_loop
                  ~fold:(fun _ -> Substrate.Skip_loop.Const_true)
                  ~pred:"P"
                  ~emit_body:(fun _ -> "")
                  ~max_bound:4 ~start_bound:0
              in
              match r with
              | Substrate.Skip_loop.Skipped { at_iter = 0; _ } -> ()
              | _ -> Alcotest.fail "expected Skipped at iter 0");
          Alcotest.test_case "verify on Const_false" `Quick (fun () ->
              let r =
                Substrate.Skip_loop.skip_predicate_loop
                  ~fold:(fun _ -> Substrate.Skip_loop.Const_false)
                  ~pred:"P"
                  ~emit_body:(fun _ -> "")
                  ~max_bound:4 ~start_bound:0
              in
              match r with
              | Substrate.Skip_loop.Verified { at_iter = 0 } -> ()
              | _ -> Alcotest.fail "expected Verified at iter 0");
          Alcotest.test_case "exhaust symbolic" `Quick (fun () ->
              let r =
                Substrate.Skip_loop.skip_predicate_loop
                  ~fold:(fun _ -> Substrate.Skip_loop.Symbolic "x")
                  ~pred:"P"
                  ~emit_body:(fun _ -> "")
                  ~max_bound:4 ~start_bound:0
              in
              match r with
              | Substrate.Skip_loop.Exhausted { bound = 4 } -> ()
              | _ -> Alcotest.fail "expected Exhausted at bound 4");
        ] );
      ( "runback",
        [
          Alcotest.test_case "escalates once, then skips" `Quick (fun () ->
              let calls = ref 0 in
              let fold _pred =
                incr calls;
                if !calls <= 5 then Substrate.Skip_loop.Symbolic "r"
                else Substrate.Skip_loop.Const_true
              in
              let r =
                Substrate.Runback.runback ~fold
                  ~ck:
                    (Substrate.Runback.checkpoint_of
                       Substrate.Runback.empty_state)
                  ~pred:"P"
                  ~emit_body:(fun _ -> "")
                  ~base_bound:4 ~extra_retries:1 ~stride:4
              in
              match r with
              | Substrate.Skip_loop.Skipped _ -> ()
              | _ -> Alcotest.fail "expected Skipped after escalation");
        ] );
      ( "pipeline",
        [
          Alcotest.test_case "full script emits points_to + skip" `Quick
            (fun () ->
              let sp : Substrate.Pipeline.spec =
                {
                  sp_name = "f";
                  sp_alloc = "llvm_alloc : LLVMPointer 8";
                  sp_pre = [];
                  sp_fn = "f";
                  sp_post = [ "llvm_verify m \"f\" ...;" ];
                }
              in
              let lines =
                sp
                Substrate.Pipeline.>^ Substrate.Pipeline.verifier_pipeline
                  ~fold:(stub_fold_after 4) ~base_ptr:"{{ base }}" ~stride:144
                  ~n_elems:4 ~pred:"i < 4" ~base_bound:4 ~extra_retries:1
              in
              let body = String.concat "\n" lines in
              Alcotest.(check bool) "has skip marker" true
                (contains_substr body "SKIPPED at iter"));
        ] );
    ]
