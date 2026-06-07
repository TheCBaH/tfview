let of_string s =
  let lexbuf = Lexing.from_string s in
  try Type_expr_parser.type_expr Type_expr_lexer.token lexbuf
  with exn ->
    failwith
      (Printf.sprintf "Type_expr.of_string %S: %s" s (Printexc.to_string exn))
