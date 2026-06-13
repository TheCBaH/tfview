open Ctypes

(* atc_tensor is `struct atc_tensor_opaque*` on the C side (shim.h).
   All pointer types share the same ABI, so we bind it as a named alias. *)
let atc_tensor = ptr void

module Functions (F : Ctypes.FOREIGN) = struct
  open F

  let default_dtype = foreign "atc_default_dtype" (void @-> returning int8_t)

  let dtype_elem_size =
    foreign "atc_dtype_elem_size" (int8_t @-> returning size_t)

  let new_ =
    foreign "atc_new"
      (ptr int64_t @-> size_t @-> int8_t @-> returning atc_tensor)

  let free = foreign "atc_free" (atc_tensor @-> returning void)
  let numel = foreign "atc_numel" (atc_tensor @-> returning int64_t)

  let data_float =
    foreign "atc_data_float" (atc_tensor @-> returning (ptr float))

  let fill_float =
    foreign "atc_fill_float" (atc_tensor @-> float @-> returning void)

  let add_float =
    foreign "atc_add_float" (atc_tensor @-> atc_tensor @-> returning atc_tensor)

  let mul =
    foreign "atc_mul" (atc_tensor @-> atc_tensor @-> returning atc_tensor)
end
