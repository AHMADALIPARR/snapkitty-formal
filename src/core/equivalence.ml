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

(** Finite-domain equivalence: enumerate a finite list of inputs. *)
let check_equiv
    ~(inputs : 'a list)
    ~(spec : 'a -> 'b)
    ~(impl : 'a -> 'b)
    ~(eq : 'b -> 'b -> bool)
  : [ `Equivalent | `Diverges of 'a * 'b * 'b ] =
  let rec go = function
    | [] -> `Equivalent
    | x :: xs ->
      let a = spec x and b = impl x in
      if eq a b then go xs else `Diverges (x, a, b)
  in
  go inputs
