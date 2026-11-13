(*
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Copyright (C) 2026 you
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *)

open Snapkitty_formal

let () =
  Alcotest.run "snapkitty-formal"
    [
      ( "logic",
        [
          Alcotest.test_case "tautology" `Quick (fun () ->
              Alcotest.(check bool) "x -> x" true
                (Core.Logic.is_tautology
                   (Core.Logic.Imp
                      (Core.Logic.Atom "x", Core.Logic.Atom "x"))));
          Alcotest.test_case "non-tautology" `Quick (fun () ->
              Alcotest.(check bool) "x" false
                (Core.Logic.is_tautology (Core.Logic.Atom "x")));
          Alcotest.test_case "true eval" `Quick (fun () ->
              Alcotest.(check bool) "True" true
                (Core.Logic.eval ~env:[] Core.Logic.True));
        ] );
      ( "invariants",
        [
          Alcotest.test_case "holds" `Quick (fun () ->
              Alcotest.(check bool) "all_hold" true
                (Core.Invariants.all_hold
                   [
                     Core.Invariants.make "t" (fun () ->
                         Core.Invariants.Holds);
                   ]));
        ] );
      ( "blst",
        [
          Alcotest.test_case "pairing sanity" `Quick (fun () ->
              Alcotest.(check bool) "e(g1,g2)*e(-g1,g2)=1" true
                (Blst.Bridge.pairing_sanity ()));
          Alcotest.test_case "g1 identity" `Quick (fun () ->
              let g = Blst.Bridge.g1_gen in
              Alcotest.(check bool) "g + (-g) = 0" true
                (Bls12_381.G1.is_zero
                   (Blst.Bridge.g1_add g (Blst.Bridge.g1_neg g))));
          Alcotest.test_case "external verification unset" `Quick (fun () ->
              (try Unix.putenv "BLST_VERIFICATION_DIR" "" with _ -> ());
              let st, _, _ = Blst.Bridge.check_external_verification () in
              Alcotest.(check bool) "Unsupported" true
                (st = Blst.Bridge.Unsupported));
        ] );
      ( "artifacts",
        [
          Alcotest.test_case "acl2 core present" `Quick (fun () ->
              Alcotest.(check bool) "core.lisp" true
                (Sys.file_exists "proofs/acl2/core.lisp"));
          Alcotest.test_case "rocq Core.v present" `Quick (fun () ->
              Alcotest.(check bool) "Core.v" true
                (Sys.file_exists "proofs/rocq/Core.v"));
          Alcotest.test_case "cryptol Primitive.cry present" `Quick (fun () ->
              Alcotest.(check bool) "Primitive.cry" true
                (Sys.file_exists "proofs/cryptol/Primitive.cry"));
          Alcotest.test_case "saw primitive.saw present" `Quick (fun () ->
              Alcotest.(check bool) "primitive.saw" true
                (Sys.file_exists "proofs/saw/primitive.saw"));
          Alcotest.test_case "xor fixture present" `Quick (fun () ->
              Alcotest.(check bool) "xor.c" true
                (Sys.file_exists "fixtures/xor.c"));
        ] );
      ( "substrate",
        [
          Alcotest.test_case "capability backends defined" `Quick (fun () ->
              Alcotest.(check int) "4 backends" 4
                (List.length Substrate.Capability.all_backends));
        ] );
    ]
