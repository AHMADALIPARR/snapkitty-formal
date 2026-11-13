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

(** Bracket budget: >^(((())))) style.
    opens = unrolling steps in base_bound;
    closes - opens = extra retry budget (runback escape). *)

type bracket_budget = { opens : int; closes : int }

let parse_budget () : bracket_budget = { opens = 4; closes = 5 }

let base_bound (b : bracket_budget) : int = b.opens
let extra_retries (b : bracket_budget) : int = b.closes - b.opens
