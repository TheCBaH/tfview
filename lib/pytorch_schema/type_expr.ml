type t =
  | Str
  | Int
  | Float
  | Bool
  | List of t
  | Optional of t
  | Dict of t (* Dict[str, T] — key is always str *)
  | Ref of string

let rec to_string = function
  | Str -> "str"
  | Int -> "int"
  | Float -> "float"
  | Bool -> "bool"
  | List t -> "List[" ^ to_string t ^ "]"
  | Optional t -> "Optional[" ^ to_string t ^ "]"
  | Dict t -> "Dict[str, " ^ to_string t ^ "]"
  | Ref s -> s
