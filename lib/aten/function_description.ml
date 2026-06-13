open Ctypes

(* atc_tensor is `struct atc_tensor_opaque*` on the C side (shim.h).
   ctypes has no way to bind an incomplete struct by pointer without defining the
   struct body; the ABI for any pointer is identical to void*, so we bind it as
   a named alias. The shim header no longer exposes bare void*. *)
let atc_tensor = ptr void

(* Function bindings for the ctypes stub generator. Each [foreign] names an
   extern "C" symbol from shim.cpp (see shim.h) with its C signature. *)
module Functions (F : Ctypes.FOREIGN) = struct
  open F

  (* Step 0 (plumbing): trivial c10 calls, no Tensor yet. *)
  let default_dtype = foreign "atc_default_dtype" (void @-> returning int8_t)

  let dtype_elem_size =
    foreign "atc_dtype_elem_size" (int8_t @-> returning size_t)

  (* Step 2: minimal CPU float32 tensor runtime. *)
  let new_float =
    foreign "atc_new_float" (ptr int64_t @-> size_t @-> returning atc_tensor)

  let free = foreign "atc_free" (atc_tensor @-> returning void)
  let numel = foreign "atc_numel" (atc_tensor @-> returning int64_t)

  let data_float =
    foreign "atc_data_float" (atc_tensor @-> returning (ptr float))

  let fill_float =
    foreign "atc_fill_float" (atc_tensor @-> float @-> returning void)

  let add_float =
    foreign "atc_add_float" (atc_tensor @-> atc_tensor @-> returning atc_tensor)
end
