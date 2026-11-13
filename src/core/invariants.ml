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

type verdict = Holds | Violated of string

type invariant = { name : string; check : unit -> verdict }

let make name f = { name; check = f }

let run (i : invariant) : verdict =
  try i.check () with exn -> Violated (Printexc.to_string exn)

let run_all (invs : invariant list) : (string * verdict) list =
  List.map (fun i -> (i.name, run i)) invs

let all_hold (invs : invariant list) : bool =
  List.for_all (fun (_, v) -> v = Holds) (run_all invs)

let report (invs : invariant list) : unit =
  List.iter
    (fun (name, v) ->
      match v with
      | Holds -> Printf.printf "✅ %s\n" name
      | Violated msg -> Printf.printf "❌ %s: %s\n" name msg)
    (run_all invs)
