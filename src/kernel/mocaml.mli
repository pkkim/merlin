(* Build settings *)
val setup_config : Mconfig.t -> unit

(* Instance of environment cache & btype unification log  *)
type typer_state

val new_state : unit_name:string -> typer_state
val with_state : typer_state -> (unit -> 'a) -> 'a
val is_current_state : typer_state -> bool

(* Replace Outcome printer *)
val default_printer :
  Format.formatter -> Extend_protocol.Reader.outcometree -> unit

val with_printer :
  (Format.formatter -> Extend_protocol.Reader.outcometree -> unit) ->
  (unit -> 'a) -> 'a

(* Clear caches, remove all items *)
val clear_caches : unit -> unit

(* Flush caches, remove outdated items *)
val flush_caches : unit -> unit
