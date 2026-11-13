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

open Syntax
open Capability
open Required
open Lgrd
open Carry
open Emit

type dispatch =
  | Single of string * string
  | Carried of (string * string) * carry list
  | Uncoverable of CapSet.t

let compile_form (f : form) : dispatch =
  let required =
    match f with
    | Defun d -> required_caps d.df_body d.df_args
    | Defthm t -> required_caps t.dt_statement []
  in
  let cover, gap = greedy_cover required all_backends in
  if not (CapSet.is_empty gap) then Uncoverable gap
  else
    match cover with
    | [] -> Uncoverable required
    | [ b ] -> Single (b.b_name, emit_for b f)
    | primary :: rest ->
        let code = emit_for primary f in
        let carries =
          List.map
            (fun b ->
              emit_carry ~f ~from_b:primary ~to_b:b (covered required b))
            rest
        in
        Carried ((primary.b_name, code), carries)
