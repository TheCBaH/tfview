(* Per-op binding generator. Given a parsed schema op, emit an extern "C" C++
   wrapper (calls [at::<op>], returns an owning tensor handle) and the matching
   ctypes [foreign] line -- or skip the op with a reason if it uses anything
   outside the gated supported set. Mirrors janestreet/torch's atg_ wrappers. *)

type generated = {
  c_name : string; (* the extern "C" symbol, e.g. atg_add_Tensor *)
  ocaml_name : string; (* the ctypes binding name, e.g. add_Tensor *)
  c_source : string; (* the extern "C" wrapper definition *)
  ctypes_line : string; (* the ctypes Functions-functor binding line *)
}

type result = Generated of generated | Skipped of string

let names (op : Func_ast.t) =
  match op.name.overload with
  | None | Some "" -> ("atg_" ^ op.name.base, op.name.base)
  | Some ov ->
      ( Printf.sprintf "atg_%s_%s" op.name.base ov,
        Printf.sprintf "%s_%s" op.name.base ov )

(* positional + kwarg-only args (out= handled separately) *)
let in_args (args : Func_ast.Arguments.t) = args.positional @ args.kwarg_only

let generate (op : Func_ast.t) : result =
  if op.arguments.out <> [] then Skipped "out= variant"
  else
    match C_type.map_returns op.returns with
    | None -> Skipped "unsupported return shape"
    | Some C_type.Tensor_ret -> (
        let mapped =
          List.map
            (fun (a : Func_ast.Argument.t) ->
              (a, C_type.map_type ~name:a.name a.ty))
            (in_args op.arguments)
        in
        match List.find_opt (fun (_, m) -> Option.is_none m) mapped with
        | Some (a, _) ->
            Skipped
              (Format.asprintf "unsupported arg type: %a" Func_ast.Type.pp a.ty)
        | None ->
            let margs = List.map (fun (a, m) -> (a, Option.get m)) mapped in
            let c_params =
              List.concat_map (fun (_, (m : C_type.arg)) -> m.c_params) margs
            in
            let call_args =
              List.map (fun (_, (m : C_type.arg)) -> m.call_expr) margs
            in
            let ctypes_in =
              List.concat_map (fun (_, (m : C_type.arg)) -> m.ctypes) margs
            in
            let c_name, ocaml_name = names op in
            let c_source =
              Printf.sprintf
                "atc_tensor %s(%s) {\n  return atc_wrap(at::%s(%s));\n}" c_name
                (String.concat ", " c_params)
                op.name.base
                (String.concat ", " call_args)
            in
            let ctypes_in = match ctypes_in with [] -> [ "void" ] | l -> l in
            let ctypes_line =
              Printf.sprintf
                "let %s = foreign \"%s\" (%s @-> returning atc_tensor)"
                ocaml_name c_name
                (String.concat " @-> " ctypes_in)
            in
            Generated { c_name; ocaml_name; c_source; ctypes_line })
