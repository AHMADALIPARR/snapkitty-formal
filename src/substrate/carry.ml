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

type carry = {
  c_from : string;
  c_to : string;
  c_obligation : CapSet.t;
  c_lemma : string;
}

let emit_carry ~(f : form) ~(from_b : backend) ~(to_b : backend)
    (needs : CapSet.t) : carry =
  let lemma =
    match f with
    | Defun d ->
        Printf.sprintf "(* carry: %s in %s ≡ %s in %s *)" d.df_name
          from_b.b_name d.df_name to_b.b_name
    | Defthm t ->
        Printf.sprintf "(* carry: %s proved in %s, restated for %s *)"
          t.dt_name from_b.b_name to_b.b_name
  in
  {
    c_from = from_b.b_name;
    c_to = to_b.b_name;
    c_obligation = needs;
    c_lemma = lemma;
  }
