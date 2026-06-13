(* Step 2 smoke test: build CPU tensors and run ops from OCaml, through
   the minimal c10-based tensor runtime in the shim. *)

open Ctypes
module F = Aten.C.Functions
module Stype = Aten.Scalar_type

let make ?(dtype = Stype.Float) shape =
  let n = Array.length shape in
  let sizes =
    CArray.of_list int64_t (List.map Int64.of_int (Array.to_list shape))
  in
  F.new_ (CArray.start sizes) (Unsigned.Size_t.of_int n) (Stype.to_int dtype)

let numel t = Int64.to_int (F.numel t)

let init t f =
  let p = F.data_float t in
  for i = 0 to numel t - 1 do
    p +@ i <-@ f i
  done

let to_list t =
  let p = F.data_float t in
  List.init (numel t) (fun i -> !@(p +@ i))

let show name t =
  Printf.printf "%s = [%s]\n" name
    (String.concat "; " (List.map (Printf.sprintf "%.0f") (to_list t)))

let () =
  let dt = F.default_dtype () in
  Printf.printf "default dtype = %d, elem size = %d bytes\n" dt
    (Unsigned.Size_t.to_int (F.dtype_elem_size dt));
  let a = make [| 2; 3 |] and b = make [| 2; 3 |] in
  init a (fun i -> float_of_int (i + 1));
  F.fill_float b 3.0;
  let c = F.add_float a b in
  let d = F.mul a b in
  show "a" a;
  show "b" b;
  show "a+b" c;
  show "a*b" d;
  F.free a;
  F.free b;
  F.free c;
  F.free d
