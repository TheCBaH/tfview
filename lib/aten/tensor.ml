open Ctypes
open Bigarray
module F = C.Functions

type float32_array = (float, float32_elt, c_layout) Array1.t

(* RAII: attach a finaliser so the C++ at::Tensor behind [t] is atc_free'd when
   the OCaml handle becomes unreachable. Returns [t] for chaining. Every handle
   that crosses into OCaml (atc_new and op results) should be passed through
   this exactly once; double-managing would double-free. *)
let manage t =
  Gc.finalise F.free t;
  t

(* Number of live (atc_wrap'd, not yet freed) C++ tensors. *)
let live_count () = Int64.to_int (F.live_count ())

(* Raised when a shim call fails (ATen threw a c10::Error at the boundary). *)
exception Error of string

(* Raise [Error] if [t] is the failure sentinel (a null handle); otherwise
   return it. The message comes from the thread-local atc_last_error. *)
let check t =
  if is_null t then
    raise (Error (Option.value (F.last_error ()) ~default:"aten error"))
  else t

(* A new uninitialised contiguous CPU tensor, owned (freed by the GC via
   [manage]). Raises [Error] on a bad shape/dtype. *)
let create ?(dtype = Scalar_type.Float) shape =
  let sizes = CArray.of_list int64_t (List.map Int64.of_int shape) in
  F.new_ (CArray.start sizes)
    (Unsigned.Size_t.of_int (List.length shape))
    (Scalar_type.to_int dtype)
  |> check |> manage

let numel t = Int64.to_int (F.numel t)
let dim t = Unsigned.Size_t.to_int (F.dim t)
let element_size t = Int64.to_int (F.element_size t)
let is_contiguous t = F.is_contiguous t <> 0
let defined t = F.defined t <> 0
let is_cpu t = F.is_cpu t <> 0

(* The tensor's dtype. Total over the supported (CPU) dtype set. *)
let scalar_type t =
  let code = F.scalar_type t in
  match Scalar_type.of_int code with
  | Some s -> s
  | None ->
      raise (Error (Printf.sprintf "unsupported scalar type code %d" code))

(* Read the [atc_dim] int64 entries written by [fill] (sizes or strides). *)
let read_dims fill t =
  let n = Unsigned.Size_t.to_int (F.dim t) in
  let out = CArray.make int64_t n in
  fill t (CArray.start out);
  Array.init n (fun i -> Int64.to_int (CArray.get out i))

(* The tensor's shape / strides as int arrays (length = rank). *)
let shape t = read_dims F.sizes t
let strides t = read_dims F.strides t

(* Return a Bigarray view over the tensor's contiguous buffer if its dtype
   matches [dtype], or None on mismatch.  The view shares memory with the
   tensor — the caller must not free the tensor while the view is live.
   A Gc finaliser on the returned array keeps the OCaml handle reachable,
   guarding against the GC collecting the handle box while the array exists;
   explicit [F.free t] while a view is live remains the caller's responsibility. *)
let as_float32 t : float32_array option =
  let n = numel t in
  let vp = F.data_ptr t (Scalar_type.to_int Scalar_type.Float) in
  if is_null vp then None
  else
    let fp = from_voidp float vp in
    let ba = bigarray_of_ptr array1 n float32 fp in
    Gc.finalise (fun _ -> ignore t) ba;
    Some ba

let pp_float32 fmt (ba : float32_array) =
  let seq = Seq.init (Array1.dim ba) (fun i -> ba.{i}) in
  Format.fprintf fmt "[%a]"
    (Format.pp_print_seq
       ~pp_sep:(fun fmt () -> Format.pp_print_string fmt "; ")
       (fun fmt v -> Format.fprintf fmt "%g" v))
    seq
