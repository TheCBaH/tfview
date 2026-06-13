open Ctypes

(* Function bindings for the ctypes stub generator. Each [foreign] names an
   extern "C" symbol from shim.cpp (see shim.h) with its C signature. *)
module Functions (F : Ctypes.FOREIGN) = struct
  open F

  (* Step 0 (plumbing): trivial c10 calls, no Tensor yet. *)
  let default_dtype = foreign "atc_default_dtype" (void @-> returning int8_t)

  let dtype_elem_size =
    foreign "atc_dtype_elem_size" (int8_t @-> returning size_t)
end
