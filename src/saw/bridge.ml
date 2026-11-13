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

(** SAW CLI bridge: runs a SAW script; exit 0 means all prove/llvm_verify passed. *)

let saw_bin () = Option.value (Sys.getenv_opt "SAW") ~default:"saw"

let run_script (script : string) : int * string =
  let cmd =
    Printf.sprintf "%s %s" (saw_bin ()) (Filename.quote script)
  in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 512 in
  (try
     while true do
       Buffer.add_string buf (input_line ic);
       Buffer.add_char buf '\n'
     done
   with End_of_file -> ());
  let status = Unix.close_process_in ic in
  ((match status with Unix.WEXITED c -> c | _ -> 1), Buffer.contents buf)

let verify (script : string) : bool = fst (run_script script) = 0

(** llvm_ffi_setup is a SAW command; it cannot be evaluated outside a SAW script. *)
let llvm_ffi_setup_snippet ~(cryptol_fn : string) : string =
  Printf.sprintf "llvm_ffi_setup %s;" cryptol_fn

type status = Proved | Failed | Unknown | Unsupported

let status_to_string = function
  | Proved -> "proved"
  | Failed -> "failed"
  | Unknown -> "unknown"
  | Unsupported -> "unsupported"

let verify_core ?(root = ".") () =
  let path = Filename.concat root "proofs/saw/primitive.saw" in
  if not (Sys.file_exists path) then
    (Unknown, Printf.sprintf "proof input not found: %s" path, "")
  else
    let code, out = run_script path in
    if code = 0 then (Proved, out, "")
    else (Failed, out, Printf.sprintf "exit %d" code)
