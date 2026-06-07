%token STR INT FLOAT BOOL
%token LIST OPTIONAL DICT
%token LBRACKET RBRACKET COMMA
%token <string> IDENT
%token EOF

%start <Type_expr.t> type_expr
%%

type_expr:
  | e = expr EOF { e }

expr:
  | STR                                           { Type_expr.Str }
  | INT                                           { Type_expr.Int }
  | FLOAT                                         { Type_expr.Float }
  | BOOL                                          { Type_expr.Bool }
  | i = IDENT                                     { Type_expr.Ref i }
  | LIST     LBRACKET e = expr RBRACKET           { Type_expr.List e }
  | OPTIONAL LBRACKET e = expr RBRACKET           { Type_expr.Optional e }
  | DICT LBRACKET STR COMMA e = expr RBRACKET     { Type_expr.Dict e }
