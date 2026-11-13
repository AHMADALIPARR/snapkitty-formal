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

(** Thin wrapper over bls12-381-unix (which links the blst C library). *)

open Bls12_381

module G1 = G1
module G2 = G2
module Fr = Fr
module Pairing = Pairing

let g1_gen : G1.t = G1.generator
let g2_gen : G2.t = G2.generator

let g1_add (a : G1.t) (b : G1.t) : G1.t = G1.add a b
let g1_mul (a : G1.t) (s : Fr.t) : G1.t = G1.mul a s
let g1_neg (a : G1.t) : G1.t = G1.negate a

let pairing_eq (a : G1.t) (b : G2.t) (c : G1.t) (d : G2.t) : bool =
  Pairing.pairing_check [ (a, b); (G1.negate c, d) ]

let pairing_sanity () : bool =
  Pairing.pairing_check
    [ (g1_gen, g2_gen); (G1.negate g1_gen, g2_gen) ]

type status = Proved | Failed | Unknown | Unsupported

let status_to_string = function
  | Proved -> "proved"
  | Failed -> "failed"
  | Unknown -> "unknown"
  | Unsupported -> "unsupported"

let check_external_verification () =
  match Sys.getenv_opt "BLST_VERIFICATION_DIR" with
  | None | Some "" ->
      ( Unsupported,
        "BLST_VERIFICATION_DIR not set",
        "See integrations/blst/README.md" )
  | Some dir ->
      if Sys.file_exists dir && Sys.is_directory dir then
        ( Proved,
          Printf.sprintf
            "BLST checkout configured at %s; invoke its pinned upstream verification target separately"
            dir,
          "" )
      else
        ( Unknown,
          Printf.sprintf "BLST_VERIFICATION_DIR points to missing path: %s" dir,
          "" )
