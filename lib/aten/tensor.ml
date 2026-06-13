open Ctypes
open Bigarray
module F = C.Functions

type float32_array = (float, float32_elt, c_layout) Array1.t

let numel t = Int64.to_int (F.numel t)

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
    Gc.finalise
      (fun _ ->
        let _ = t in
        ())
      ba;
    Some ba

let pp_float32 fmt (ba : float32_array) =
  let n = Array1.dim ba in
  Format.pp_print_char fmt '[';
  for i = 0 to n - 1 do
    if i > 0 then Format.pp_print_string fmt "; ";
    Format.fprintf fmt "%.0f" ba.{i}
  done;
  Format.pp_print_char fmt ']'
