(* Step 2 smoke test: build CPU tensors and run a real op from OCaml, through
   the minimal c10-based tensor runtime in the shim. *)

open Ctypes
module F = Aten.C.Functions

(* Allocate a CPU float tensor of the given int shape. *)
let make shape =
  let n = Array.length shape in
  let sizes =
    CArray.of_list int64_t (List.map Int64.of_int (Array.to_list shape))
  in
  F.new_float (CArray.start sizes) (Unsigned.Size_t.of_int n)

let numel t = Int64.to_int (F.numel t)

(* Set element i to f i. *)
let init t f =
  let p = F.data_float t in
  for i = 0 to numel t - 1 do
    p +@ i <-@ f i
  done

let to_list t =
  let p = F.data_float t in
  List.init (numel t) (fun i -> !@(p +@ i))

let () =
  (* Step 0 plumbing check. *)
  let dt = F.default_dtype () in
  Printf.printf "default dtype = %d, elem size = %d bytes\n" dt
    (Unsigned.Size_t.to_int (F.dtype_elem_size dt));
  (* Step 2: tensors + a real op. *)
  let a = make [| 2; 3 |] and b = make [| 2; 3 |] in
  init a (fun i -> float_of_int i);
  F.fill_float b 10.0 (* scalar op *);
  let c =
    F.add_float a b
    (* tensor op *)
  in
  let show name t =
    Printf.printf "%s = [%s]\n" name
      (String.concat "; " (List.map (Printf.sprintf "%.0f") (to_list t)))
  in
  show "a" a;
  show "b" b;
  show "a+b" c;
  F.free a;
  F.free b;
  F.free c
