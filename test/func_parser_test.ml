open Func_ast

let parse s = match Func_schema.parse s with Ok v -> v | Error e -> failwith e

let show_ty t =
  let rec go = function
    | Base Generator -> "Generator"
    | Base ScalarType -> "ScalarType"
    | Base Tensor -> "Tensor"
    | Base Int -> "int"
    | Base Dimname -> "Dimname"
    | Base DimVector -> "DimVector"
    | Base Float -> "float"
    | Base Str -> "str"
    | Base Bool -> "bool"
    | Base Layout -> "Layout"
    | Base Device -> "Device"
    | Base DeviceIndex -> "DeviceIndex"
    | Base Scalar -> "Scalar"
    | Base MemoryFormat -> "MemoryFormat"
    | Base QScheme -> "QScheme"
    | Base Storage -> "Storage"
    | Base Stream -> "Stream"
    | Base SymInt -> "SymInt"
    | Base SymBool -> "SymBool"
    | Base GraphModule -> "GraphModule"
    | Optional t -> go t ^ "?"
    | List (t, None) -> go t ^ "[]"
    | List (t, Some n) -> go t ^ "[" ^ string_of_int n ^ "]"
  in
  go t

let show_ann ann =
  let aliases = String.concat "|" ann.alias_set in
  let wr = if ann.is_write then "!" else "" in
  let after =
    if ann.alias_set_after = [] then ""
    else " -> " ^ String.concat "|" ann.alias_set_after
  in
  Printf.sprintf "(%s%s%s)" aliases wr after

let show_default = function
  | DefaultNone -> "None"
  | DefaultBool true -> "True"
  | DefaultBool false -> "False"
  | DefaultInt n -> string_of_int n
  | DefaultFloat s -> s
  | DefaultStr s -> Printf.sprintf "%S" s
  | DefaultIntList ns ->
      "[" ^ String.concat "," (List.map string_of_int ns) ^ "]"
  | DefaultIdent s -> s

let show_arg (a : argument) =
  let ann = match a.annotation with None -> "" | Some ann -> show_ann ann in
  let dflt =
    match a.default with None -> "" | Some d -> "=" ^ show_default d
  in
  Printf.sprintf "%s%s %s%s" (show_ty a.ty) ann a.name dflt

let show_ret r =
  let ann = match r.annotation with None -> "" | Some ann -> show_ann ann in
  let nm = match r.name with None -> "" | Some s -> " " ^ s in
  Printf.sprintf "%s%s%s" (show_ty r.ty) ann nm

let show_args args =
  let ps = List.map show_arg args.positional in
  let ks = List.map show_arg args.kwarg_only in
  let os = List.map show_arg args.out in
  let parts = ps @ if ks = [] && os = [] then [] else [ "*" ] @ ks @ os in
  String.concat ", " parts

let show fs =
  let name =
    match fs.name.overload with
    | None -> fs.name.base
    | Some ov -> fs.name.base ^ "." ^ ov
  in
  let rets =
    match fs.returns with
    | [ r ] -> show_ret r
    | rs -> "(" ^ String.concat ", " (List.map show_ret rs) ^ ")"
  in
  Printf.sprintf "%s(%s) -> %s" name (show_args fs.arguments) rets

(* ---- tests ---- *)

let%expect_test "simple positional args" =
  print_string (show (parse "relu(Tensor self) -> Tensor"));
  [%expect {| relu(Tensor self) -> Tensor |}]

let%expect_test "optional and list types" =
  print_string
    (show
       (parse
          "add.Tensor(Tensor self, Tensor other, Scalar? alpha=None) -> Tensor"));
  [%expect
    {| add.Tensor(Tensor self, Tensor other, Scalar? alpha=None) -> Tensor |}]

let%expect_test "annotated tensor arg and out" =
  print_string
    (show (parse "abs.out(Tensor self, *, Tensor(a!) out) -> Tensor(a!)"));
  [%expect {| abs.out(Tensor self, *, Tensor(a!) out) -> Tensor(a!) |}]

let%expect_test "multiple returns" =
  print_string
    (show (parse "chunk(Tensor self, int chunks, int dim=0) -> Tensor[]"));
  [%expect {| chunk(Tensor self, int chunks, int dim=0) -> Tensor[] |}]

let%expect_test "defaults: float, bool, list" =
  print_string
    (show
       (parse
          "batch_norm(Tensor input, Tensor? weight, Tensor? bias, Tensor? \
           running_mean, Tensor? running_var, bool training, float momentum, \
           float eps=1e-05, bool cudnn_enabled=True) -> Tensor"));
  [%expect
    {| batch_norm(Tensor input, Tensor? weight, Tensor? bias, Tensor? running_mean, Tensor? running_var, bool training, float momentum, float eps=1e-05, bool cudnn_enabled=True) -> Tensor |}]
