(* Jsont shim for Melange — encodes directly to Js.Json.t.
   Implements the subset of the Jsont API used by model_explorer. *)

type 'a t = 'a -> Js.Json.t

let string s = Js.Json.string s
let bool b = Js.Json.boolean b
let number f = Js.Json.number f
let map ?kind:_ ?doc:_ ?dec:_ ~enc t = fun b -> t (enc b)

let list (t : 'a t) (items : 'a list) =
  Js.Json.array (Array.of_list (List.map t items))

let any ~kind:_ ~dec_string:_ ~dec_object:_ ~enc () : 'a t = fun v -> enc v v

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

  (* Discriminated-union ("case") object members, e.g. { "type": "node_ids", ... }.
     Only the encoding direction is implemented — Melange never decodes. *)
  module Case = struct
    (* A case pairs a tag (the value carried by the variant constructor, e.g.
       [NodeAttributeValueType.NodeIds]) with the jsont for its payload. *)
    type ('a, 'tag, 't) case = { tag : 'tag; payload : 'a t }

    let map (tag : 'tag) (payload : 'a t) ~dec:(_dec : 'a -> 't) :
        ('a, 'tag, 't) case =
      { tag; payload }

    (* An encoded case: the tag plus the payload already turned into JSON. *)
    type ('tag, 't) value = { value_tag : 'tag; value_json : Js.Json.t }

    let value (case : ('a, 'tag, 't) case) (payload : 'a) : ('tag, 't) value =
      { value_tag = case.tag; value_json = case.payload payload }

    (* Erased case, used by the real jsont to look cases up while decoding;
       unused here. *)
    type ('tag, 't) t = unit

    let make (_case : ('a, 'tag, 't) case) : ('tag, 't) t = ()
  end

  let case_mem (name : string) (tag_t : 'tag t) ~enc:(accessor : 'o -> 'o)
      ~enc_case:(enc_case : 'o -> ('tag, 'o) Case.value)
      (_cases : ('tag, 'o) Case.t list) (m : ('o, 'o -> 'b) map) : ('o, 'b) map
      =
    {
      encs =
        (fun o ->
          let case_value = enc_case (accessor o) in
          let payload_fields =
            match Js.Json.decodeObject case_value.Case.value_json with
            | Some dict -> Array.to_list (Js.Dict.entries dict)
            | None -> []
          in
          m.encs o
          @ ((name, tag_t case_value.Case.value_tag) :: payload_fields));
    }
end
