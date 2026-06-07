module Scc = Scc.Make (struct
  type t = string

  let compare = String.compare
end)

let run nodes edges =
  let succ v = Option.value ~default:[] (List.assoc_opt v edges) in
  Scc.run ~succ nodes

let pp_sccs sccs =
  List.iter
    (fun scc ->
      print_string "[";
      print_string (String.concat "," scc);
      print_endline "]")
    sccs

let%expect_test "empty graph" =
  pp_sccs (run [] []);
  [%expect {| |}]

let%expect_test "singleton, no self-loop" =
  pp_sccs (run [ "a" ] []);
  [%expect {| [a] |}]

let%expect_test "singleton self-loop" =
  pp_sccs (run [ "a" ] [ ("a", [ "a" ]) ]);
  [%expect {| [a] |}]

let%expect_test "linear chain — leaves first" =
  (* a -> b -> c, topological: c, b, a *)
  pp_sccs (run [ "a"; "b"; "c" ] [ ("a", [ "b" ]); ("b", [ "c" ]) ]);
  [%expect {|
    [c]
    [b]
    [a] |}]

let%expect_test "two-node cycle" =
  pp_sccs (run [ "a"; "b" ] [ ("a", [ "b" ]); ("b", [ "a" ]) ]);
  [%expect {| [a,b] |}]

let%expect_test "three-node cycle" =
  pp_sccs
    (run [ "a"; "b"; "c" ] [ ("a", [ "b" ]); ("b", [ "c" ]); ("c", [ "a" ]) ]);
  [%expect {| [a,b,c] |}]

let%expect_test "diamond — two independent paths" =
  (* a -> b, a -> c, b -> d, c -> d  =>  d, then b and c (in visit order), then a *)
  pp_sccs
    (run [ "a"; "b"; "c"; "d" ]
       [ ("a", [ "b"; "c" ]); ("b", [ "d" ]); ("c", [ "d" ]) ]);
  [%expect {|
    [d]
    [b]
    [c]
    [a] |}]

let%expect_test "two disconnected components" =
  pp_sccs (run [ "a"; "b"; "c"; "d" ] [ ("a", [ "b" ]); ("c", [ "d" ]) ]);
  [%expect {|
    [b]
    [a]
    [d]
    [c] |}]
