let parse s = Type_expr.to_string (Type_expr_parse.of_string s)

let%expect_test "primitives" =
  List.iter (fun s -> print_endline (parse s)) [ "str"; "int"; "float"; "bool" ];
  [%expect {|
    str
    int
    float
    bool |}]

let%expect_test "List and Optional" =
  List.iter
    (fun s -> print_endline (parse s))
    [ "List[str]"; "List[int]"; "Optional[str]"; "Optional[List[int]]" ];
  [%expect
    {|
    List[str]
    List[int]
    Optional[str]
    Optional[List[int]] |}]

let%expect_test "Dict" =
  List.iter
    (fun s -> print_endline (parse s))
    [
      "Dict[str, int]";
      "Dict[str, RangeConstraint]";
      "Dict[str, List[OutputSpec]]";
    ];
  [%expect
    {|
    Dict[str, int]
    Dict[str, RangeConstraint]
    Dict[str, List[OutputSpec]] |}]

let%expect_test "user-defined type references" =
  List.iter
    (fun s -> print_endline (parse s))
    [
      "GraphModule";
      "SchemaVersion";
      "List[GraphArgument]";
      "Optional[TensorArgument]";
    ];
  [%expect
    {|
    GraphModule
    SchemaVersion
    List[GraphArgument]
    Optional[TensorArgument] |}]
