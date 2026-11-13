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

let is_arith_op = function
  | "+" | "-" | "*" | "/" | "mod" | "rem" | "<" | "<=" | ">" | ">=" | "="
  | "equal" ->
      true
  | _ -> false

let rec required_caps (e : sexp) (bound : string list) : CapSet.t =
  match e with
  | Atom a when List.mem a bound -> CapSet.empty
  | Atom _ -> CapSet.empty
  | List [] -> CapSet.empty
  | List [ Atom "if"; c; t; e ] ->
      CapSet.add Prop
        (CapSet.union (required_caps c bound)
           (CapSet.union (required_caps t bound) (required_caps e bound)))
  | List [ Atom "let"; Atom v; rhs; body ] ->
      CapSet.union (required_caps rhs bound)
        (required_caps body (v :: bound))
  | List (Atom op :: args) when is_arith_op op ->
      CapSet.add Arith
        (List.fold_left CapSet.union CapSet.empty
           (List.map (fun a -> required_caps a bound) args))
  | List (Atom fn :: args) when List.mem fn bound ->
      CapSet.add RecFn
        (List.fold_left CapSet.union CapSet.empty
           (List.map (fun a -> required_caps a bound) args))
  | List (Atom "natp" :: _) -> CapSet.singleton Ind
  | List (Atom "implies" :: _) -> CapSet.singleton Prop
  | List (Atom _ :: args) ->
      List.fold_left CapSet.union CapSet.empty
        (List.map (fun a -> required_caps a bound) args)
  | List _ -> CapSet.empty
