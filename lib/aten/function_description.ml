open Ctypes

(* Function bindings for the ctypes stub generator. Each [foreign] names an
   extern "C" symbol from shim.cpp (see shim.h) with its C signature. *)
module Functions (F : Ctypes.FOREIGN) = struct
  open F

  (* Step 0 (plumbing): trivial c10 calls, no Tensor yet. *)
  let default_dtype = foreign "atc_default_dtype" (void @-> returning int8_t)

  let dtype_elem_size =
    foreign "atc_dtype_elem_size" (int8_t @-> returning size_t)

  (* Step 2: minimal CPU float32 tensor runtime. atc_tensor is an opaque owning
     handle, bound as a void pointer. *)
  let new_float =
    foreign "atc_new_float" (ptr int64_t @-> size_t @-> returning (ptr void))

  let free = foreign "atc_free" (ptr void @-> returning void)
  let numel = foreign "atc_numel" (ptr void @-> returning int64_t)
  let data_float = foreign "atc_data_float" (ptr void @-> returning (ptr float))

  let fill_float =
    foreign "atc_fill_float" (ptr void @-> float @-> returning void)

  let add_float =
    foreign "atc_add_float" (ptr void @-> ptr void @-> returning (ptr void))
end
