open Ctypes
module F = Aten.C.Functions
module Stype = Aten.Scalar_type
module T = Aten.Tensor

let make ?(dtype = Stype.Float) shape =
  let n = Array.length shape in
  let sizes =
    CArray.of_list int64_t (List.map Int64.of_int (Array.to_list shape))
  in
  F.new_ (CArray.start sizes) (Unsigned.Size_t.of_int n) (Stype.to_int dtype)

let () =
  let dt = F.default_dtype () in
  Format.printf "default dtype = %d, elem size = %d bytes\n" dt
    (Unsigned.Size_t.to_int (F.dtype_elem_size dt));
  let a = make [| 2; 3 |] and b = make [| 2; 3 |] in
  let ba = T.as_float32 a |> Option.get in
  let bb = T.as_float32 b |> Option.get in
  for i = 0 to Bigarray.Array1.dim ba - 1 do
    ba.{i} <- float_of_int (i + 1)
  done;
  Bigarray.Array1.fill bb 3.0;
  let c = F.add a b in
  let d = F.mul a b in
  let bc = T.as_float32 c |> Option.get in
  let bd = T.as_float32 d |> Option.get in
  Format.printf "a = %a\n" T.pp_float32 ba;
  Format.printf "b = %a\n" T.pp_float32 bb;
  Format.printf "a+b = %a\n" T.pp_float32 bc;
  Format.printf "a*b = %a\n" T.pp_float32 bd;
  F.free a;
  F.free b;
  F.free c;
  F.free d
