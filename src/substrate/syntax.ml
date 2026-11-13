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

type sexp = Atom of string | List of sexp list

let rec sexp_to_string = function
  | Atom a -> a
  | List xs -> "(" ^ String.concat " " (List.map sexp_to_string xs) ^ ")"

type defun = {
  df_name : string;
  df_args : string list;
  df_body : sexp;
  df_measure : sexp option;
}

type defthm = {
  dt_name : string;
  dt_statement : sexp;
  dt_hint : sexp option;
}

type form = Defun of defun | Defthm of defthm
