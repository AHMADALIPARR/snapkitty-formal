(*
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Copyright (C) 2026 Ahmad Ali Parr
 *
 * Custom substrate code — human-authored by Ahmad Ali Parr.
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

(** Custom raw-pointer arithmetic for SAW scripts.
    A raw pointer is a Cryptol term of type [64]. Cast to LLVMPointer
    happens only at the boundary. *)

type raw_ptr = string

let raw_add (p : raw_ptr) (k : int) : raw_ptr =
  Printf.sprintf "{{ (%s + %d) : [64] }}" p k

let raw_add_sym (p : raw_ptr) (q : raw_ptr) : raw_ptr =
  Printf.sprintf "{{ (%s + %s) : [64] }}" p q

let raw_mul (p : raw_ptr) (k : int) : raw_ptr =
  Printf.sprintf "{{ (%s * %d) : [64] }}" p k

let cast_to_llvm_ptr (p : raw_ptr) : string =
  Printf.sprintf "(llvm_term {{ %s : LLVMPointer 8 }})" p

let custom_ptr_at ~(base : raw_ptr) ~(stride : int) ~(index : int) : string =
  let addr = raw_add base (stride * index) in
  cast_to_llvm_ptr addr

let custom_ptr_at_sym ~(base : raw_ptr) ~(stride : int) ~(index : raw_ptr) : string =
  let offset = raw_mul index stride in
  let addr = raw_add_sym base offset in
  cast_to_llvm_ptr addr
