(* Raw (un-interpreted) representation of a native_functions.yaml entry.
   All field values are kept as close to the YAML structure as possible;
   the func signature string is NOT parsed further. *)

type dispatch_entry = {
  keys : string; (* may be comma-separated, e.g. "CPU, CUDA" *)
  kernel : string;
}

type t = {
  func : string;
  variants : string option;
  dispatch : dispatch_entry list;
  structured : bool;
  structured_delegate : string option;
  structured_inherits : string option;
  tags : string list;
  device_guard : bool;
  device_check : string option;
  python_module : string option;
  manual_cpp_binding : bool;
  use_const_ref_for_mutable_tensors : bool;
  category_override : string option;
  cpp_no_default_args : string list;
  autogen : string option; (* comma-separated op names, kept raw *)
  precomputed : string list;
  ufunc_inner_loop : (string * string) list;
}

(* ---- low-level Jsont helpers ---- *)

let find_member key members =
  List.find_map (fun ((k, _), v) -> if k = key then Some v else None) members

let json_string = function Jsont.String (s, _) -> Some s | _ -> None
let json_bool = function Jsont.Bool (b, _) -> Some b | _ -> None

(* ---- field decoders ---- *)

let decode_dispatch = function
  | Jsont.Object (members, _) ->
      List.filter_map
        (fun ((k, _), v) ->
          Option.map (fun kernel -> { keys = k; kernel }) (json_string v))
        members
  | _ -> []

(* YAML scalar string or sequence of strings -> string list *)
let decode_string_list = function
  | Jsont.String (s, _) ->
      List.filter_map
        (fun t ->
          let t = String.trim t in
          if t = "" then None else Some t)
        (String.split_on_char ',' s)
  | Jsont.Array (items, _) -> List.filter_map json_string items
  | _ -> []

(* tags may be a scalar string or a YAML sequence *)
let decode_tags j =
  match j with
  | Jsont.String (s, _) -> [ String.trim s ]
  | Jsont.Array _ -> decode_string_list j
  | _ -> []

(* cpp_no_default_args is always a YAML sequence of strings *)
let decode_str_seq = function
  | Jsont.Array (items, _) -> List.filter_map json_string items
  | _ -> []

(* precomputed is a sequence of strings *)
let decode_precomputed = decode_str_seq

(* ufunc_inner_loop is a mapping of key -> value strings *)
let decode_ufunc_inner_loop = function
  | Jsont.Object (members, _) ->
      List.filter_map
        (fun ((k, _), v) -> Option.map (fun s -> (k, s)) (json_string v))
        members
  | _ -> []

(* ---- entry decoder ---- *)

let decode_entry_exn json =
  match json with
  | Jsont.Object (members, _) ->
      let get k = find_member k members in
      let str k = Option.bind (get k) json_string in
      let bool k default =
        Option.value ~default (Option.bind (get k) json_bool)
      in
      let func =
        match str "func" with
        | Some s -> s
        | None ->
            Jsont.Error.msgf Jsont.Meta.none "missing required field 'func'"
      in
      {
        func;
        variants = str "variants";
        dispatch =
          (match get "dispatch" with None -> [] | Some j -> decode_dispatch j);
        structured = bool "structured" false;
        structured_delegate = str "structured_delegate";
        structured_inherits = str "structured_inherits";
        tags = (match get "tags" with None -> [] | Some j -> decode_tags j);
        device_guard = bool "device_guard" true;
        device_check = str "device_check";
        python_module = str "python_module";
        manual_cpp_binding = bool "manual_cpp_binding" false;
        use_const_ref_for_mutable_tensors =
          bool "use_const_ref_for_mutable_tensors" false;
        category_override = str "category_override";
        cpp_no_default_args =
          (match get "cpp_no_default_args" with
          | None -> []
          | Some j -> decode_str_seq j);
        autogen = str "autogen";
        precomputed =
          (match get "precomputed" with
          | None -> []
          | Some j -> decode_precomputed j);
        ufunc_inner_loop =
          (match get "ufunc_inner_loop" with
          | None -> []
          | Some j -> decode_ufunc_inner_loop j);
      }
  | _ ->
      Jsont.Error.msgf Jsont.Meta.none
        "expected a YAML mapping for a native function entry"

let jsont : t list Jsont.t =
  Jsont.map ~kind:"NativeFuncList"
    ~dec:(fun json ->
      match json with
      | Jsont.Array (items, _) -> List.map decode_entry_exn items
      | _ ->
          Jsont.Error.msgf Jsont.Meta.none
            "expected a YAML sequence at top level")
    Jsont.json

let of_yaml_string s = Yamlt.of_string jsont s
