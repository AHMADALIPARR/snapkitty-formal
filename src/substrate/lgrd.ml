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

open Capability

(** Closure of [b]'s capabilities under subsumption. *)
let closed_supports (b : backend) : CapSet.t =
  CapSet.filter
    (fun c -> CapSet.exists (fun h -> subsumes h c) b.b_has)
    (CapSet.of_list [ TotalFn; RecFn; Prop; Arith; Ind; Extr; FinWord ])

let covered required b = CapSet.inter required (closed_supports b)
let residue required b = CapSet.diff required (closed_supports b)

(** Lattice-Greedy Residue Dispatch — greedy set cover over the capability lattice. *)
let greedy_cover required backends =
  let uncovered = ref required in
  let picked = ref [] in
  let remaining = ref backends in
  let progress = ref true in
  while !progress && not (CapSet.is_empty !uncovered) do
    progress := false;
    let scored =
      List.map
        (fun b -> (b, CapSet.cardinal (covered !uncovered b)))
        !remaining
    in
    match List.sort (fun (_, a) (_, b) -> compare b a) scored with
    | (best, n) :: _ when n > 0 ->
        picked := best :: !picked;
        uncovered := residue !uncovered best;
        remaining :=
          List.filter (fun b -> b.b_name <> best.b_name) !remaining;
        progress := true
    | _ -> progress := false
  done;
  (List.rev !picked, !uncovered)
