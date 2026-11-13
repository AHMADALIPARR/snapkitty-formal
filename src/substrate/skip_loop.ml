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

(** Skip-predicate loop: fold a loop guard; skip body when Const_true,
    terminate when Const_false, else unroll one step. *)

type pred_result = Const_true | Const_false | Symbolic of string

type loop_result =
  | Skipped of { at_iter : int; why : string }
  | Verified of { at_iter : int }
  | Exhausted of { bound : int }

type fold = string -> pred_result

let skip_predicate_loop
    ~(fold : fold)
    ~(pred : string)
    ~(emit_body : int -> string)
    ~(max_bound : int)
    ~(start_bound : int)
  : loop_result =
  let rec go i =
    if i > max_bound then Exhausted { bound = max_bound }
    else
      match fold pred with
      | Const_true ->
          Skipped { at_iter = i; why = "predicate folds to True" }
      | Const_false -> Verified { at_iter = i }
      | Symbolic _ ->
          ignore (emit_body i);
          go (i + 1)
  in
  go start_bound
