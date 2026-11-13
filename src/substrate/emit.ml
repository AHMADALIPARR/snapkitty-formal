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

let emit_acl2_defun d =
  let m =
    match d.df_measure with
    | Some x -> " :measure " ^ sexp_to_string x
    | None -> ""
  in
  Printf.sprintf "(defun %s (%s)%s\n %s)" d.df_name
    (String.concat " " d.df_args) m (sexp_to_string d.df_body)

let emit_acl2_defthm t =
  Printf.sprintf "(defthm %s\n %s)" t.dt_name
    (sexp_to_string t.dt_statement)

let rec sexp_to_rocq = function
  | Atom "zp" -> failwith "zp has no Rocq analogue; must be expanded"
  | Atom a -> a
  | List [ Atom "if"; c; t; e ] ->
      Printf.sprintf "(if %s then %s else %s)" (sexp_to_rocq c)
        (sexp_to_rocq t) (sexp_to_rocq e)
  | List (Atom "implies" :: args) ->
      let rec fold = function
        | [ x ] -> sexp_to_rocq x
        | x :: rest ->
            Printf.sprintf "(%s -> %s)" (sexp_to_rocq x) (fold rest)
        | [] -> "True"
      in
      fold args
  | List (Atom op :: args) when is_arith_op op ->
      Printf.sprintf "(%s)"
        (String.concat " " (op :: List.map sexp_to_rocq args))
  | List xs ->
      "(" ^ String.concat " " (List.map sexp_to_rocq xs) ^ ")"

let emit_rocq_defun d =
  Printf.sprintf
    "Fixpoint %s (%s : nat) {struct %s} : nat :=\n %s." d.df_name
    (String.concat " " (List.map (fun a -> a ^ " : nat") d.df_args))
    (List.hd d.df_args) (sexp_to_rocq d.df_body)

let emit_rocq_defthm t =
  Printf.sprintf "Lemma %s : %s.\nProof. (* hint *) Admitted." t.dt_name
    (sexp_to_rocq t.dt_statement)

let emit_cryptol_defun d =
  Printf.sprintf "%s : [32] -> [32]\n%s x = %s\n" d.df_name d.df_name
    (sexp_to_string d.df_body)

let emit_saw_defthm t =
  Printf.sprintf "prove_print abc {{ %s }};" (sexp_to_rocq t.dt_statement)

let emit_for (b : backend) (f : form) =
  match (b.b_name, f) with
  | "acl2", Defun d -> emit_acl2_defun d
  | "acl2", Defthm t -> emit_acl2_defthm t
  | "rocq", Defun d -> emit_rocq_defun d
  | "rocq", Defthm t -> emit_rocq_defthm t
  | "cryptol", Defun d -> emit_cryptol_defun d
  | "saw", Defthm t -> emit_saw_defthm t
  | name, _ -> failwith ("backend " ^ name ^ " cannot express this form")
