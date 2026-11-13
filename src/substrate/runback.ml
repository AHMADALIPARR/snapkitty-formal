(*
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Copyright (C) 2026 Ahmad Ali Parr
 *
 * Custom substrate code — human-authored by Ahmad Ali Parr.
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

(** Runback: escalate unrolling bound on Exhausted, rewinding checkpoint
    state (asserts / points_to) while advancing the unrolled counter. *)

type symbolic_state = {
  ss_asserts : string list;
  ss_points_to : string list;
  ss_unrolled : int;
}

type checkpoint = { cp : symbolic_state }

let empty_state = { ss_asserts = []; ss_points_to = []; ss_unrolled = 0 }
let checkpoint_of s = { cp = s }

let rewind (ck : checkpoint) ~(unrolled : int) : symbolic_state =
  { ck.cp with ss_unrolled = unrolled }

let runback
    ~(fold : Skip_loop.fold)
    ~(ck : checkpoint)
    ~(pred : string)
    ~(emit_body : int -> string)
    ~(base_bound : int)
    ~(extra_retries : int)
    ~(stride : int)
  : Skip_loop.loop_result =
  let max_bound = base_bound + (extra_retries * stride) in
  let rec escalate b =
    match
      Skip_loop.skip_predicate_loop ~fold ~pred ~emit_body ~max_bound
        ~start_bound:b
    with
    | (Skip_loop.Skipped _ | Skip_loop.Verified _) as r -> r
    | Skip_loop.Exhausted { bound = _ } when b < max_bound ->
        ignore (rewind ck ~unrolled:(b + stride));
        escalate (b + stride)
    | Skip_loop.Exhausted _ as r -> r
  in
  escalate base_bound
