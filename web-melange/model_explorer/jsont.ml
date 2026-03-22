(* Jsont shim for Melange — encodes directly to Js.Json.t.
   Implements the subset of the Jsont API used by model_explorer. *)

type 'a t = 'a -> Js.Json.t

let string s = Js.Json.string s
let bool b = Js.Json.boolean b

let list (t : 'a t) (items : 'a list) =
  Js.Json.array (Array.of_list (List.map t items))

module Object = struct
  (* ('o, 'dec) map accumulates field encoders for an object of type 'o.
     'dec is a phantom type tracking the decoder constructor — unused for
     encoding, but required for type compatibility with the jsont API. *)
  type ('o, _) map = { encs : 'o -> (string * Js.Json.t) list }

  let map ~kind:_ (_dec : 'dec) : ('o, 'dec) map = { encs = (fun _ -> []) }

  let mem (name : string) (t : 'a t) ~enc:(accessor : 'o -> 'a)
      (m : ('o, 'a -> 'b) map) : ('o, 'b) map =
    { encs = (fun o -> m.encs o @ [ (name, t (accessor o)) ]) }

  let opt_mem (name : string) (t : 'a t) ~enc:(accessor : 'o -> 'a option)
      (m : ('o, 'a option -> 'b) map) : ('o, 'b) map =
    {
      encs =
        (fun o ->
          m.encs o
          @ match accessor o with Some v -> [ (name, t v) ] | None -> []);
    }

  let finish (m : ('o, 'o) map) : 'o t =
   fun o ->
    let d = Js.Dict.empty () in
    List.iter (fun (k, v) -> Js.Dict.set d k v) (m.encs o);
    Js.Json.object_ d

  module String_map = Map.Make (String)

  let as_string_map ~kind:_ (t : 'a t) : 'a String_map.t t =
   fun m ->
    let d = Js.Dict.empty () in
    String_map.iter (fun k v -> Js.Dict.set d k (t v)) m;
    Js.Json.object_ d
end
