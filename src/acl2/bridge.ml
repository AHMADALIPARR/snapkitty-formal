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

(** ACL2 Bridge client: TCP + S-expressions.
    Protocol: client sends one S-expression per line; server replies with one. *)

type sexp = Atom of string | List of sexp list

exception Parse_error of string

(* --- Minimal S-expression reader --- *)
let parse (s : string) : sexp =
  let n = String.length s in
  let i = ref 0 in
  let rec skip_ws () =
    while
      !i < n
      &&
      match s.[!i] with
      | ' ' | '\t' | '\n' | '\r' -> true
      | _ -> false
    do
      incr i
    done
  in
  let rec read () =
    skip_ws ();
    if !i >= n then raise (Parse_error "unexpected eof");
    match s.[!i] with
    | '(' ->
        incr i;
        let rec items acc =
          skip_ws ();
          if !i < n && s.[!i] = ')' then (
            incr i;
            List (List.rev acc))
          else items (read () :: acc)
        in
        items []
    | ')' -> raise (Parse_error "unexpected )")
    | _ ->
        let start = !i in
        while
          !i < n
          &&
          match s.[!i] with
          | ' ' | '\t' | '\n' | '\r' | '(' | ')' -> false
          | _ -> true
        do
          incr i
        done;
        Atom (String.sub s start (!i - start))
  in
  read ()

let rec to_string = function
  | Atom a -> a
  | List xs -> "(" ^ String.concat " " (List.map to_string xs) ^ ")"

(* --- Socket transport --- *)
type conn = { ic : in_channel; oc : out_channel; sock : Unix.file_descr }

let connect ~host ~port : conn =
  let addr = Unix.ADDR_INET (Unix.inet_addr_of_string host, port) in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.connect sock addr;
  let ic = Unix.in_channel_of_descr (Unix.dup sock) in
  let oc = Unix.out_channel_of_descr sock in
  { ic; oc; sock }

let close (c : conn) =
  close_in_noerr c.ic;
  close_out_noerr c.oc

let eval (c : conn) (form : string) : sexp =
  output_string c.oc (form ^ "\n");
  flush c.oc;
  let line = input_line c.ic in
  parse line

let eval_bool (c : conn) (form : string) : bool =
  match eval c form with
  | Atom "T" -> true
  | Atom "NIL" -> false
  | _ -> false

(* --- Batch fallback (no socket server required) --- *)
type status = Proved | Failed | Unknown | Unsupported

let status_to_string = function
  | Proved -> "proved"
  | Failed -> "failed"
  | Unknown -> "unknown"
  | Unsupported -> "unsupported"

let run_batch ?(root = ".") script =
  let path = Filename.concat root script in
  if not (Sys.file_exists path) then
    (Unknown, Printf.sprintf "proof input not found: %s" path, "")
  else
    let cmd = Printf.sprintf "acl2 -qq %s 2>&1" (Filename.quote path) in
    let ic = Unix.open_process_in cmd in
    let buf = Buffer.create 1024 in
    (try
       while true do
         Buffer.add_channel buf ic 4096
       done
     with End_of_file -> ());
    let output = Buffer.contents buf in
    match Unix.close_process_in ic with
    | Unix.WEXITED 0 -> (Proved, output, "")
    | Unix.WEXITED n -> (Failed, output, Printf.sprintf "exit %d" n)
    | _ -> (Unknown, output, "process terminated abnormally")

let verify_core ?(root = ".") () =
  run_batch ~root "proofs/acl2/core.lisp"
