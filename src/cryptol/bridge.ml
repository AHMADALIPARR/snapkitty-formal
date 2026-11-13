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

(** Cryptol CLI bridge. *)

let cryptol_bin () =
  Option.value (Sys.getenv_opt "CRYPTOL") ~default:"cryptol"

let run (args : string list) : int * string =
  let cmd = String.concat " " (cryptol_bin () :: args) in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 256 in
  (try
     while true do
       Buffer.add_string buf (input_line ic);
       Buffer.add_char buf '\n'
     done
   with End_of_file -> ());
  let status = Unix.close_process_in ic in
  ((match status with Unix.WEXITED c -> c | _ -> 1), Buffer.contents buf)

let check (cryfile : string) : bool =
  let code, _ = run [ "-b"; cryfile ] in
  code = 0

let eval (cryfile : string) (expr : string) : string =
  let _, out = run [ "-c"; cryfile; "-e"; expr ] in
  String.trim out

type status = Proved | Failed | Unknown | Unsupported

let status_to_string = function
  | Proved -> "proved"
  | Failed -> "failed"
  | Unknown -> "unknown"
  | Unsupported -> "unsupported"

let run_batch ?(root = ".") ?(file = "proofs/cryptol/Primitive.cry") () =
  let path = Filename.concat root file in
  if not (Sys.file_exists path) then
    (Unknown, Printf.sprintf "proof input not found: %s" path, "")
  else
    let code, out = run [ "-b"; path ] in
    if code = 0 then (Proved, out, "")
    else (Failed, out, Printf.sprintf "exit %d" code)

let verify_core ?(root = ".") () = run_batch ~root ()
