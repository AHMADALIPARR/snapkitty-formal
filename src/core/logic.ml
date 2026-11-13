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

type prop =
  | True
  | False
  | Atom of string
  | Not of prop
  | And of prop * prop
  | Or of prop * prop
  | Imp of prop * prop

let rec eval ~env (p : prop) : bool =
  match p with
  | True -> true
  | False -> false
  | Atom a -> (match List.assoc_opt a env with Some b -> b | None -> false)
  | Not q -> not (eval ~env q)
  | And (q, r) -> eval ~env q && eval ~env r
  | Or (q, r) -> eval ~env q || eval ~env r
  | Imp (q, r) -> (not (eval ~env q)) || eval ~env r

let atoms (p : prop) : string list =
  let rec go acc = function
    | True | False -> acc
    | Atom a -> if List.mem a acc then acc else a :: acc
    | Not q -> go acc q
    | And (q, r) | Or (q, r) | Imp (q, r) -> go (go acc q) r
  in
  List.rev (go [] p)

(** Exhaustive truth-table check: is [p] a tautology? *)
let is_tautology (p : prop) : bool =
  let vars = atoms p in
  let n = List.length vars in
  let rec loop i =
    if i >= (1 lsl n) then true
    else
      let env =
        List.mapi (fun k v -> (v, (i lsr k) land 1 = 1)) vars
      in
      eval ~env p && loop (i + 1)
  in
  loop 0

let equivalent (p : prop) (q : prop) : bool =
  is_tautology (And (Imp (p, q), Imp (q, p)))
