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

type capability =
  | TotalFn  (** total function, no measure needed *)
  | RecFn    (** recursive; needs termination witness *)
  | Prop     (** propositional skeleton *)
  | Arith    (** nat/int arithmetic *)
  | Ind      (** induction over nat *)
  | Extr     (** extractable to OCaml *)
  | FinWord  (** finite-width word semantics *)

(** [subsumes a b] is true iff [a]'s presence entails [b]'s dischargeability. *)
let subsumes a b =
  match (a, b) with
  | Ind, Prop | Arith, Prop -> true
  | RecFn, TotalFn | Extr, TotalFn -> true
  | _ -> a = b

module CapSet = Set.Make (struct
  type t = capability
  let compare = compare
end)

type backend = { b_name : string; b_has : CapSet.t }

let acl2 =
  {
    b_name = "acl2";
    b_has = CapSet.of_list [ TotalFn; RecFn; Prop; Arith; Ind ];
  }

let rocq =
  {
    b_name = "rocq";
    b_has = CapSet.of_list [ TotalFn; RecFn; Prop; Arith; Ind; Extr ];
  }

let cryptol =
  {
    b_name = "cryptol";
    b_has = CapSet.of_list [ TotalFn; RecFn; Prop; FinWord ];
  }

let saw =
  {
    b_name = "saw";
    b_has = CapSet.of_list [ TotalFn; Prop; Arith; FinWord ];
  }

let all_backends = [ acl2; rocq; cryptol; saw ]
