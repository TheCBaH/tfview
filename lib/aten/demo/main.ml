(* Step 0 smoke test: call into ATen core (c10) from OCaml through the ctypes
   static bindings. No Tensor yet -- this only proves the linkage works. *)

let () =
  let dt = Aten.C.Functions.default_dtype () in
  let sz = Unsigned.Size_t.to_int (Aten.C.Functions.dtype_elem_size dt) in
  (* c10::ScalarType::Float = 6, element size 4 bytes *)
  Printf.printf "default dtype = %d, elem size = %d bytes\n" dt sz
