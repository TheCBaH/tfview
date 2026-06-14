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
  (* relu: max(0,x). g = [-2..3] -> [0;0;0;1;2;3]. *)
  let g = make [| 2; 3 |] in
  let bg = T.as_float32 g |> Option.get in
  for i = 0 to Bigarray.Array1.dim bg - 1 do
    bg.{i} <- float_of_int (i - 2)
  done;
  let rg = O.relu g in
  show "relu g" rg (T.as_float32 rg |> Option.get);
  (* relu_: in-place. h = [-3..2] -> [0;0;0;0;1;2]. *)
  let h = make [| 2; 3 |] in
  let bh = T.as_float32 h |> Option.get in
  for i = 0 to Bigarray.Array1.dim bh - 1 do
    bh.{i} <- float_of_int (i - 3)
  done;
  let rh = O.relu_ h in
  show "relu_ h" rh (T.as_float32 rh |> Option.get);
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
  (* max_pool2d: same 1x1x4x4, 2x2 kernel/stride, pad 0, dil 1 -> block maxima
     6/8/14/16. *)
  let mp_k = i64 [ 2; 2 ] and mp_s = i64 [ 2; 2 ] in
  let mp_p = i64 [ 0; 0 ] and mp_d = i64 [ 1; 1 ] in
  let maxed =
    O.max_pool2d img (CArray.start mp_k) 2 (CArray.start mp_s) 2
      (CArray.start mp_p) 2 (CArray.start mp_d) 2 false
  in
  Format.printf "max_pool2d %a kernel [2x2] -> %a = %a\n" pp_shape (T.shape img)
    pp_shape (T.shape maxed) T.pp_float32
    (T.as_float32 maxed |> Option.get);
  (* adaptive_avg_pool2d to (1,1): global mean of 1..16 = 8.5 (the resnet18
     global-average-pool path). *)
  let ada_os = i64 [ 1; 1 ] in
  let adapted = O.adaptive_avg_pool2d img (CArray.start ada_os) 2 in
  Format.printf "adaptive_avg_pool2d %a -> %a = %a\n" pp_shape (T.shape img)
    pp_shape (T.shape adapted) T.pp_float32
    (T.as_float32 adapted |> Option.get);
  (* linear: y = x @ W^T + b. x=[1,2,3] (1x3), W=[[1,0,0],[0,1,1]] (2x3),
     b=[10,20] -> [11,25]. Exercises the addmm/gemm path. *)
  let set t vs =
    List.iteri (fun i v -> (T.as_float32 t |> Option.get).{i} <- v) vs
  in
  let lin_x = make [| 1; 3 |] in
  set lin_x [ 1.; 2.; 3. ];
  let lin_w = make [| 2; 3 |] in
  set lin_w [ 1.; 0.; 0.; 0.; 1.; 1. ];
  let lin_b = make [| 2 |] in
  set lin_b [ 10.; 20. ];
  let lin_y = O.linear lin_x lin_w lin_b in
  Format.printf "linear x[1x3] W[2x3] b[2] -> %a = %a\n" pp_shape
    (T.shape lin_y) T.pp_float32
    (T.as_float32 lin_y |> Option.get);
  (* batch_norm (inference): y = (x-mean)/sqrt(var+eps)*w + b, per channel.
     x[1x2x1x2] ch0=[1,2] ch1=[3,4], mean=0 var=1 eps=0 w=2 b=1 -> 2x+1
     = [3;5;7;9]. *)
  let bn_x = make [| 1; 2; 1; 2 |] in
  set bn_x [ 1.; 2.; 3.; 4. ];
  let bn_w = make [| 2 |] and bn_b = make [| 2 |] in
  set bn_w [ 2.; 2. ];
  set bn_b [ 1.; 1. ];
  let bn_m = make [| 2 |] and bn_v = make [| 2 |] in
  set bn_m [ 0.; 0. ];
  set bn_v [ 1.; 1. ];
  let bn_y = O.batch_norm bn_x bn_w bn_b bn_m bn_v false 0.1 0.0 false in
  Format.printf "batch_norm %a -> %a = %a\n" pp_shape (T.shape bn_x) pp_shape
    (T.shape bn_y) T.pp_float32
    (T.as_float32 bn_y |> Option.get);
  F.free a;
  F.free b;
  F.free c;
  F.free d;
  F.free e;
  F.free e';
  F.free g;
  F.free rg;
  F.free h;
  F.free rh;
  F.free r;
  F.free fl;
  F.free img;
  F.free pooled;
  F.free maxed;
  F.free adapted;
  F.free lin_x;
  F.free lin_w;
  F.free lin_b;
  F.free lin_y;
  F.free bn_x;
  F.free bn_w;
  F.free bn_b;
  F.free bn_m;
  F.free bn_v;
  F.free bn_y
