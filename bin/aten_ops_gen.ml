(* Driver for the ATen operation-binding generator. Emits ONE of the three
   build artifacts (ops.h, ops.cpp, operation_description.ml) to stdout from a
   curated selection of ops, so lib/aten/dune can produce each with a
   [with-stdout-to] rule.

   Usage: aten_ops_gen <native_functions.yaml> <ops.h|ops.cpp|operation_description.ml>

   The op set is curated on purpose: the static-dispatch + --gc-sections build
   trims unreached at:: kernels, so binding every supported op would force-link
   ~1000 kernels and defeat that trimming. Two sources feed the selection:

     - [Allow]: ops pulled verbatim from native_functions.yaml by name. The
       generator (Aten_gen.Gen) must be able to emit them as-is.
     - [Override]: a hand-written schema signature used INSTEAD of the yaml
       entry, for ops the generator cannot yet emit unmodified. e.g. avg_pool2d
       carries an [int? divisor_override] (unsupported) plus several defaulted
       args; the override drops them to the (self, kernel_size) frontend
       overload that at::avg_pool2d still accepts via C++ defaults. *)

type selection =
  | Allow of { base : string; overload : string option }
  | Override of string

let selection =
  [
    Allow { base = "add"; overload = Some "Tensor" };
    Allow { base = "add_"; overload = Some "Tensor" };
    Allow { base = "mul"; overload = Some "Tensor" };
    Allow { base = "relu"; overload = None };
    Allow { base = "relu_"; overload = None };
    Allow { base = "reshape"; overload = None };
    Allow { base = "flatten"; overload = Some "using_ints" };
    Allow { base = "max_pool2d"; overload = None };
    Allow { base = "adaptive_avg_pool2d"; overload = None };
    Allow { base = "linear"; overload = None };
    Allow { base = "batch_norm"; overload = None };
    Allow { base = "conv2d"; overload = None };
    Override "avg_pool2d(Tensor self, int[2] kernel_size) -> Tensor";
  ]

let die fmt =
  Printf.ksprintf
    (fun s ->
      prerr_endline s;
      exit 1)
    fmt

(* Parse a schema signature and run it through the generator, failing loudly if
   it cannot be parsed or the generator skips it (the selection is curated, so a
   skip is a configuration error, not an expected outcome). *)
let generate_sig ~origin ~style (sg : string) : Aten_gen.Gen.generated =
  match Func_schema.parse sg with
  | Error e -> die "%s: parse error: %s" origin e
  | Ok op -> (
      match Aten_gen.Gen.generate ~style op with
      | Skipped r -> die "%s: generator skipped (%s): %s" origin r sg
      | Generated g -> g)

(* Find the native_functions.yaml entry matching [base]/[overload]. The call
   style follows the schema's [variants]: ops marked method-only have no at::
   free function, so they must be emitted as a Tensor method call. *)
let find_entry (entries : Raw.t list) ~base ~overload : Raw.t =
  let matches (e : Raw.t) =
    match Func_schema.parse e.func with
    | Error _ -> false
    | Ok op -> op.name.base = base && op.name.overload = overload
  in
  match List.find_opt matches entries with
  | Some e -> e
  | None ->
      let ov = match overload with None -> "" | Some s -> "." ^ s in
      die "no native_functions.yaml entry for op %s%s" base ov

(* torchgen defaults an absent [variants] to "function", so emit a free-function
   call unless the op is explicitly method-only (a non-empty list without
   Function, e.g. in-place add_). *)
let style_of (e : Raw.t) =
  match e.variants with
  | [] -> `Function
  | vs -> if List.mem Raw.Variant.Function vs then `Function else `Method

let resolve (entries : Raw.t list) : Aten_gen.Gen.generated list =
  List.map
    (fun sel ->
      match sel with
      | Allow { base; overload } ->
          let e = find_entry entries ~base ~overload in
          generate_sig ~origin:"schema" ~style:(style_of e) e.func
      | Override sg -> generate_sig ~origin:"override" ~style:`Function sg)
    selection

let () =
  if Array.length Sys.argv <> 3 then
    die
      "Usage: aten_ops_gen <native_functions.yaml> \
       <ops.h|ops.cpp|operation_description.ml>";
  let yaml = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  let entries =
    match Raw.of_yaml_string yaml with
    | Error (`Msg e) -> die "YAML parse error: %s" e
    | Ok entries -> entries
  in
  let ops = resolve entries in
  let out =
    match Sys.argv.(2) with
    | "ops.h" -> Aten_gen.Emit.header ops
    | "ops.cpp" -> Aten_gen.Emit.source ops
    | "operation_description.ml" -> Aten_gen.Emit.ocaml ops
    | other -> die "unknown output target: %s" other
  in
  print_string out
