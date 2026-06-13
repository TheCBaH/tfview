(* Generator output snapshots. Parse a schema string and emit the extern "C"
   shim + ctypes binding (or the skip reason). *)

let gen s =
  match Func_schema.parse s with
  | Error e -> Printf.printf "PARSE ERROR: %s\n" e
  | Ok op -> (
      match Aten_gen.Gen.generate op with
      | Skipped r -> Printf.printf "SKIPPED: %s\n" r
      | Generated g ->
          Printf.printf "%s\n---\n%s\n" g.Aten_gen.Gen.c_source
            g.Aten_gen.Gen.ctypes_line)

let%expect_test "add.Tensor" =
  gen "add.Tensor(Tensor self, Tensor other, *, Scalar alpha=1) -> Tensor";
  [%expect
    {|
    void* atg_add_Tensor(void* self, void* other, double alpha) {
      return new at::Tensor(at::add(*static_cast<at::Tensor*>(self), *static_cast<at::Tensor*>(other), c10::Scalar(alpha)));
    }
    ---
    let add_Tensor = foreign "atg_add_Tensor" (ptr void @-> ptr void @-> double @-> returning (ptr void)) |}]

let%expect_test "mul.Tensor" =
  gen "mul.Tensor(Tensor self, Tensor other) -> Tensor";
  [%expect
    {|
    void* atg_mul_Tensor(void* self, void* other) {
      return new at::Tensor(at::mul(*static_cast<at::Tensor*>(self), *static_cast<at::Tensor*>(other)));
    }
    ---
    let mul_Tensor = foreign "atg_mul_Tensor" (ptr void @-> ptr void @-> returning (ptr void)) |}]

let%expect_test "reshape (IntList)" =
  gen "reshape(Tensor(a) self, SymInt[] shape) -> Tensor(a)";
  [%expect {| SKIPPED: unsupported arg type: SymInt[] |}]

let%expect_test "softmax (int + ScalarType?)" =
  gen "softmax.int(Tensor self, int dim, ScalarType? dtype=None) -> Tensor";
  [%expect {| SKIPPED: unsupported arg type: ScalarType? |}]

let%expect_test "skipped: out= variant" =
  gen
    "add.out(Tensor self, Tensor other, *, Scalar alpha=1, Tensor(a!) out) -> \
     Tensor(a!)";
  [%expect {| SKIPPED: out= variant |}]

let%expect_test "skipped: unsupported arg (Dimname)" =
  gen "squeeze.dimname(Tensor(a) self, Dimname dim) -> Tensor(a)";
  [%expect {| SKIPPED: unsupported arg type: Dimname |}]
