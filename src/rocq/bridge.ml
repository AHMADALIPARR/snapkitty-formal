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

(** Rocq (Coq) extraction / compilation bridge. *)

let rocq_bin () =
  match Sys.getenv_opt "ROCQ" with
  | Some b -> b
  | None ->
      if Sys.command "command -v rocq >/dev/null 2>&1" = 0 then "rocq"
      else if Sys.command "command -v coqc >/dev/null 2>&1" = 0 then "coqc"
      else "coqc"

let run (args : string list) : int * string =
  let bin = rocq_bin () in
  let cmd = String.concat " " (bin :: args) in
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

let extract ~(vfile : string) ~(mlfile : string) : bool =
  let script =
    Printf.sprintf
      "Require Extraction. Extraction Language OCaml. Load \"%s\". Extraction \"%s\"."
      vfile mlfile
  in
  let tmp = Filename.temp_file "rocq_extract" ".v" in
  let oc = open_out tmp in
  output_string oc script;
  close_out oc;
  let code, _ = run [ "-batch"; "-l"; tmp ] in
  Sys.remove tmp;
  code = 0 && Sys.file_exists mlfile

type status = Proved | Failed | Unknown | Unsupported

let status_to_string = function
  | Proved -> "proved"
  | Failed -> "failed"
  | Unknown -> "unknown"
  | Unsupported -> "unsupported"

let compile ?(root = ".") ?(file = "proofs/rocq/Core.v") () =
  let path = Filename.concat root file in
  if not (Sys.file_exists path) then
    (Unknown, Printf.sprintf "proof input not found: %s" path, "")
  else
    let bin = rocq_bin () in
    let args =
      if String.contains bin ' ' then
        [ "-q"; path ]
      else [ "-q"; path ]
    in
    let code, out = run (if bin = "coqc" then args else "-q" :: [ path ]) in
    if code = 0 then (Proved, out, "")
    else (Failed, out, Printf.sprintf "exit %d" code)

let verify_core ?(root = ".") () = compile ~root ()
