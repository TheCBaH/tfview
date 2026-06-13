open Ctypes
module F = Aten.C.Functions
module O = Aten.C.Operations
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
  let c = O.add_Tensor a b 1.0 in
  let d = O.mul_Tensor a b in
  let bc = T.as_float32 c |> Option.get in
  let bd = T.as_float32 d |> Option.get in
  let pp_shape fmt s =
    Format.fprintf fmt "[%a]"
      (Format.pp_print_list
         ~pp_sep:(fun fmt () -> Format.pp_print_string fmt "x")
         Format.pp_print_int)
      (Array.to_list s)
  in
  let show name t ba =
    Format.printf "%s %a = %a\n" name pp_shape (T.shape t) T.pp_float32 ba
  in
  show "a" a ba;
  show "b" b bb;
  show "a+b" c bc;
  show "a*b" d bd;
  (* in-place add_: e (10..15) += b (3) -> 13..18; returns a handle to e. *)
  let e = make [| 2; 3 |] in
  let be = T.as_float32 e |> Option.get in
  for i = 0 to Bigarray.Array1.dim be - 1 do
    be.{i} <- float_of_int (10 + i)
  done;
  let e' = O.add__Tensor e b 1.0 in
  show "e+=b" e' (T.as_float32 e' |> Option.get);
  (* SymInt[]: reshape the 2x3 tensor 'a' to 3x2 (a view; shares storage). *)
  let i64 xs = CArray.of_list int64_t (List.map Int64.of_int xs) in
  let reshape_to t xs =
    let shape = i64 xs in
    O.reshape t (CArray.start shape) (List.length xs)
  in
  let r = reshape_to a [ 3; 2 ] in
  Format.printf "reshape a %a -> %a = %a\n" pp_shape (T.shape a) pp_shape
    (T.shape r) T.pp_float32
    (T.as_float32 r |> Option.get);
  (* flatten using_ints: 2x3 -> 1D [6] (start_dim=0, end_dim=-1). *)
  let fl = O.flatten_using_ints a 0L (-1L) in
  Format.printf "flatten a %a -> %a = %a\n" pp_shape (T.shape a) pp_shape
    (T.shape fl) T.pp_float32
    (T.as_float32 fl |> Option.get);
  (* avg_pool2d: 1x1x4x4 input of 1..16, 2x2 kernel -> 1x1x2x2 block means. *)
  let img = make [| 1; 1; 4; 4 |] in
  let bimg = T.as_float32 img |> Option.get in
  for i = 0 to Bigarray.Array1.dim bimg - 1 do
    bimg.{i} <- float_of_int (i + 1)
  done;
  let kernel = i64 [ 2; 2 ] in
  let pooled = O.avg_pool2d img (CArray.start kernel) 2 in
  Format.printf "avg_pool2d %a kernel [2x2] -> %a = %a\n" pp_shape (T.shape img)
    pp_shape (T.shape pooled) T.pp_float32
    (T.as_float32 pooled |> Option.get);
  F.free a;
  F.free b;
  F.free c;
  F.free d;
  F.free e;
  F.free e';
  F.free r;
  F.free fl;
  F.free img;
  F.free pooled
