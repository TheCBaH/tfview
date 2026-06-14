(* Tensor object-API tests: RAII / live count, metadata accessors, and the
   error boundary.

   RAII: every handle that crosses into OCaml is passed through [Tensor.manage]
   (done by [Tensor.create]), which attaches a Gc finaliser that atc_free's the
   C++ at::Tensor when the OCaml handle is collected. The shim keeps an exact
   live count (atc_wrap allocations not yet freed), so we can assert the
   round-trip: live rises with allocation and returns to baseline once handles
   are unreachable and the GC has run their finalisers. *)

open Ctypes
module F = Aten.C.Functions
module O = Aten.C.Operations
module Stype = Aten.Scalar_type
module T = Aten.Tensor

(* A managed, uninitialised tensor of [shape]. No data view is taken, so the
   only finaliser is the free — no anchoring view to keep the handle alive
   across a GC. Values are irrelevant here; we only count handles. *)
let alloc shape = T.create shape

let ints a =
  "[" ^ String.concat ";" (Array.to_list (Array.map string_of_int a)) ^ "]"

(* Two full majors: the first collects the now-unreachable handles, and running
   finalisers can unreference further handles (e.g. op results aliasing inputs),
   so a second pass drains those too. *)
let collect () =
  Gc.full_major ();
  Gc.full_major ()

let%expect_test "live count rises on alloc, returns to baseline after GC" =
  collect ();
  let base = T.live_count () in
  (* Allocate in an inner scope so the handles are unreachable once it returns;
     measure the live delta while they are still referenced. *)
  let while_referenced =
    let ts = List.init 10 (fun _ -> alloc [ 3 ]) in
    let delta = T.live_count () - base in
    ignore (Sys.opaque_identity ts);
    delta
  in
  Printf.printf "while referenced: +%d\n" while_referenced;
  collect ();
  Printf.printf "after gc: +%d\n" (T.live_count () - base);
  [%expect {|
    while referenced: +10
    after gc: +0 |}]

let%expect_test "long op sequence leaves no live tensors" =
  collect ();
  let base = T.live_count () in
  (* A sequence in the spirit of aten_ops_test: inputs + several op results per
     iteration, all dropped each turn. Values are uninitialised — we only care
     that every atc_wrap'd handle (inputs and results) is freed. *)
  for _ = 1 to 100 do
    let a = alloc [ 2; 3 ] and b = alloc [ 2; 3 ] in
    let c = T.manage (O.add_Tensor a b 1.0) in
    let d = T.manage (O.mul_Tensor a b) in
    let _ = T.manage (O.relu c) in
    let _ = T.manage (O.relu_ d) in
    ()
  done;
  collect ();
  Printf.printf "live delta after 100 iterations: %d\n" (T.live_count () - base);
  [%expect {| live delta after 100 iterations: 0 |}]

let%expect_test "metadata accessors" =
  let t = T.create [ 2; 3 ] in
  Printf.printf
    "dim=%d numel=%d esize=%d dtype=%d contig=%b cpu=%b defined=%b\n" (T.dim t)
    (T.numel t) (T.element_size t)
    (Stype.to_int (T.scalar_type t))
    (T.is_contiguous t) (T.is_cpu t) (T.defined t);
  Printf.printf "shape=%s strides=%s\n" (ints (T.shape t)) (ints (T.strides t));
  [%expect
    {|
    dim=2 numel=6 esize=4 dtype=6 contig=true cpu=true defined=true
    shape=[2;3] strides=[3;1] |}]

let%expect_test "error boundary: bad dtype raises Tensor.Error" =
  (* atc_new with an unknown dtype code throws a c10::Error in C++; the boundary
     catches it, returns the null sentinel, and Tensor.check raises. *)
  let bad =
    let sizes = CArray.of_list int64_t [ 2L; 3L ] in
    F.new_ (CArray.start sizes) (Unsigned.Size_t.of_int 2) 99
  in
  (match T.check bad with
  | exception T.Error _ -> print_string "raised Tensor.Error"
  | _ -> print_string "no error");
  [%expect "raised Tensor.Error"]
