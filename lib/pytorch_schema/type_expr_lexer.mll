{
  open Type_expr_parser
}

let alpha = ['a'-'z' 'A'-'Z' '_']
let alnum = ['a'-'z' 'A'-'Z' '0'-'9' '_']

rule token = parse
  | [' ' '\t']           { token lexbuf }
  | "str"                { STR }
  | "int"                { INT }
  | "float"              { FLOAT }
  | "bool"               { BOOL }
  | "List"               { LIST }
  | "Optional"           { OPTIONAL }
  | "Dict"               { DICT }
  | '['                  { LBRACKET }
  | ']'                  { RBRACKET }
  | ','                  { COMMA }
  | alpha alnum* as s    { IDENT s }
  | eof                  { EOF }
  | _ as c               { failwith (Printf.sprintf "Type_expr_lexer: unexpected char %C" c) }
