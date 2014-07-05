(* {{{ COPYING *(

  This file is part of Merlin, an helper for ocaml editors

  Copyright (C) 2013  Frédéric Bour  <frederic.bour(_)lakaban.net>
                      Thomas Refis  <refis.thomas(_)gmail.com>
                      Simon Castellan  <simon.castellan(_)iuwt.fr>

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  The Software is provided "as is", without warranty of any kind, express or
  implied, including but not limited to the warranties of merchantability,
  fitness for a particular purpose and noninfringement. In no event shall
  the authors or copyright holders be liable for any claim, damages or other
  liability, whether in an action of contract, tort or otherwise, arising
  from, out of or in connection with the software or the use or other dealings
  in the Software.

)* }}} *)

open Std
exception Warning of Location.t * string

let warnings : exn list ref option fluid = fluid None

let raise_warning exn =
  match ~!warnings with
  | None -> raise exn
  | Some l -> l := exn :: !l

let prerr_warning loc w =
  match ~!warnings with
  | None -> Location.print_warning loc Format.err_formatter w
  | Some l ->
    let ppf, to_string = Format.to_string () in
    Location.print_warning loc ppf w;
    match to_string () with
      | "" -> ()
      | s ->  l := Warning (loc,s) :: !l

let () = Location.prerr_warning_ref := prerr_warning

let catch_warnings f =
  let caught = ref [] in
  let result =
    Either.try' (fun () -> Fluid.let' warnings (Some caught) f)
  in
  !caught, result

let location_union a b =
  let open Location in
  match a,b with
  | a, { loc_ghost = true } -> a
  | { loc_ghost = true }, b -> b
  | a,b ->
    let loc_start =
      if Lexing.split_pos a.loc_start <= Lexing.split_pos b.loc_start
      then a.loc_start
      else b.loc_start
    and loc_end =
      if Lexing.split_pos a.loc_end <= Lexing.split_pos b.loc_end
      then b.loc_end
      else a.loc_end
    in
    { loc_start ; loc_end ; loc_ghost = a.loc_ghost && b.loc_ghost }

(* Atrocious hack to store one more data in location while keeping
   compatibility with unmarshalled Location.t generated by compiler *)
let location_size = Obj.(size (repr Location.none))

let with_bag_of_holding (t : Location.t) exn : Location.t =
  let t = Obj.repr t in
  let t' = Obj.new_block 0 (succ location_size) in
  for i = 0 to (pred location_size) do
    Obj.set_field t' i (Obj.field t i)
  done;
  Obj.set_field t' location_size (Obj.repr exn);
  Obj.obj t'

let bag_of_holding (t : Location.t) : exn =
  let t = Obj.repr t in
  if Obj.size t > location_size
  then (Obj.obj (Obj.field t location_size) : exn)
  else Not_found

exception Fake_start of Lexing.position
let pack_fake_start t pos = with_bag_of_holding t (Fake_start pos)
let unpack_fake_start t =
  match bag_of_holding t with
  | Fake_start pos -> pos
  | _ -> t.Location.loc_start


let compare_pos pos loc =
  let open Location in
  let pos = Lexing.split_pos pos in
  if pos < Lexing.split_pos loc.loc_start
  then -1
  else if pos > Lexing.split_pos loc.loc_end
  then 1
  else 0