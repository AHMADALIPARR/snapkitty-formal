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

(** Pipeline operator and verifier assembly: alloc + custom ptr points_to
    + skip/runback loop comments + postconditions. *)

open Saw_ptr

type spec = {
  sp_name : string;
  sp_alloc : string;
  sp_pre : string list;
  sp_fn : string;
  sp_post : string list;
}

type pipeline = spec -> string list

let ( >^ ) (sp : spec) (p : pipeline) : string list = p sp

let verifier_pipeline
    ~(fold : Skip_loop.fold)
    ~(base_ptr : raw_ptr)
    ~(stride : int)
    ~(n_elems : int)
    ~(pred : string)
    ~(base_bound : int)
    ~(extra_retries : int)
  : pipeline =
  fun sp ->
    let allocs = [ sp.sp_alloc ] in
    let points_to =
      List.init n_elems (fun i ->
          let loc = custom_ptr_at ~base:base_ptr ~stride ~index:i in
          Printf.sprintf "llvm_points_to %s (llvm_term {{ val_%d }});" loc i)
    in
    let emit_body i =
      Printf.sprintf "// iteration %d: obligation on %s[%d]" i sp.sp_name i
    in
    let loop =
      Runback.runback ~fold
        ~ck:(Runback.checkpoint_of Runback.empty_state)
        ~pred ~emit_body ~base_bound ~extra_retries ~stride
    in
    let loop_comment =
      match loop with
      | Skip_loop.Skipped { at_iter; why } ->
          [ Printf.sprintf "// SKIPPED at iter %d: %s" at_iter why ]
      | Skip_loop.Verified { at_iter } ->
          [ Printf.sprintf "// VERIFIED at iter %d" at_iter ]
      | Skip_loop.Exhausted { bound } ->
          [ Printf.sprintf "// EXHAUSTED at bound %d" bound ]
    in
    allocs @ points_to @ loop_comment @ sp.sp_post
