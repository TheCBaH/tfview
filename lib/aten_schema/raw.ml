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

(* dispatch / ufunc_inner_loop: arbitrary-key objects folded into lists *)

let dispatch_jsont : dispatch_entry list Jsont.t =
  Jsont.map ~dec:List.rev
    (Jsont.fold_object Jsont.string
       (fun _meta keys kernel acc -> { keys; kernel } :: acc)
       [])

let ufunc_inner_loop_jsont : (string * string) list Jsont.t =
  Jsont.map ~dec:List.rev
    (Jsont.fold_object Jsont.string (fun _meta k v acc -> (k, v) :: acc) [])

(* tags: scalar string → singleton list;  YAML sequence → list *)
let tags_jsont : string list Jsont.t =
  Jsont.any ()
    ~dec_string:(Jsont.map ~dec:(fun s -> [ String.trim s ]) Jsont.string)
    ~dec_array:(Jsont.list Jsont.string)

let entry_jsont : t Jsont.t =
  Jsont.Object.(
    finish
      (map
         (fun
           func
           variants
           dispatch
           structured
           structured_delegate
           structured_inherits
           tags
           device_guard
           device_check
           python_module
           manual_cpp_binding
           use_const_ref_for_mutable_tensors
           category_override
           cpp_no_default_args
           autogen
           precomputed
           ufunc_inner_loop
         ->
           {
             func;
             variants;
             dispatch;
             structured;
             structured_delegate;
             structured_inherits;
             tags;
             device_guard;
             device_check;
             python_module;
             manual_cpp_binding;
             use_const_ref_for_mutable_tensors;
             category_override;
             cpp_no_default_args;
             autogen;
             precomputed;
             ufunc_inner_loop;
           })
      |> mem "func" Jsont.string
      |> opt_mem "variants" Jsont.string
      |> mem "dispatch" dispatch_jsont ~dec_absent:[]
      |> mem "structured" Jsont.bool ~dec_absent:false
      |> opt_mem "structured_delegate" Jsont.string
      |> opt_mem "structured_inherits" Jsont.string
      |> mem "tags" tags_jsont ~dec_absent:[]
      |> mem "device_guard" Jsont.bool ~dec_absent:true
      |> opt_mem "device_check" Jsont.string
      |> opt_mem "python_module" Jsont.string
      |> mem "manual_cpp_binding" Jsont.bool ~dec_absent:false
      |> mem "use_const_ref_for_mutable_tensors" Jsont.bool ~dec_absent:false
      |> opt_mem "category_override" Jsont.string
      |> mem "cpp_no_default_args" (Jsont.list Jsont.string) ~dec_absent:[]
      |> opt_mem "autogen" Jsont.string
      |> mem "precomputed" (Jsont.list Jsont.string) ~dec_absent:[]
      |> mem "ufunc_inner_loop" ufunc_inner_loop_jsont ~dec_absent:[]))

let jsont : t list Jsont.t = Jsont.list entry_jsont
let of_yaml_string s = Yamlt.of_string jsont s
