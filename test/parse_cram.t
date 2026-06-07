Incremental JSON parsing tests for relevant portions of the generated schema.
Each test defines a pp function and uses Format.pp_print_result to print the
decode outcome.

-- SchemaVersion: plain struct with two int fields --

  $ cat > parse1.ml << 'EOF'
  > #use "topfind";;
  > #require "jsont";;
  > #require "jsont.bytesrw";;
  > #use "schema_pytorch.ml";;
  > let pp ppf v =
  >   Format.fprintf ppf "%d.%d" v.SchemaVersion.major v.SchemaVersion.minor
  > let () =
  >   Format.printf "%a@."
  >     (Format.pp_print_result ~ok:pp ~error:Format.pp_print_string)
  >     (Jsont_bytesrw.decode_string SchemaVersion.jsont {|{"major":8,"minor":14}|})
  > EOF
  $ ocaml schema_runtime.cma parse1.ml 2>/dev/null
  8.14

-- TensorArgument: struct with a single string field --

  $ cat > parse2.ml << 'EOF'
  > #use "topfind";;
  > #require "jsont";;
  > #require "jsont.bytesrw";;
  > #use "schema_pytorch.ml";;
  > let pp ppf v =
  >   Format.fprintf ppf "name=%s" v.TensorArgument.name
  > let () =
  >   Format.printf "%a@."
  >     (Format.pp_print_result ~ok:pp ~error:Format.pp_print_string)
  >     (Jsont_bytesrw.decode_string TensorArgument.jsont {|{"name":"x"}|})
  > EOF
  $ ocaml schema_runtime.cma parse2.ml 2>/dev/null
  name=x

-- ArgumentKind: enum decoded from an integer --

  $ cat > parse3.ml << 'EOF'
  > #use "topfind";;
  > #require "jsont";;
  > #require "jsont.bytesrw";;
  > #use "schema_pytorch.ml";;
  > let pp ppf = function
  >   | ArgumentKind.UNKNOWN    -> Format.fprintf ppf "UNKNOWN"
  >   | ArgumentKind.POSITIONAL -> Format.fprintf ppf "POSITIONAL"
  >   | ArgumentKind.KEYWORD    -> Format.fprintf ppf "KEYWORD"
  > let () =
  >   Format.printf "%a@."
  >     (Format.pp_print_result ~ok:pp ~error:Format.pp_print_string)
  >     (Jsont_bytesrw.decode_string ArgumentKind.jsont {|1|})
  > EOF
  $ ocaml schema_runtime.cma parse3.ml 2>/dev/null
  POSITIONAL

-- SymIntArgument: union decoded from a single-key object --

  $ cat > parse4.ml << 'EOF'
  > #use "topfind";;
  > #require "jsont";;
  > #require "jsont.bytesrw";;
  > #use "schema_pytorch.ml";;
  > let pp ppf = function
  >   | SymIntArgument.Name s -> Format.fprintf ppf "Name %s" s
  >   | SymIntArgument.Int  i -> Format.fprintf ppf "Int %d" i
  > let () =
  >   Format.printf "%a@."
  >     (Format.pp_print_result ~ok:pp ~error:Format.pp_print_string)
  >     (Jsont_bytesrw.decode_string SymIntArgument.jsont {|{"as_name":"sym0"}|})
  > EOF
  $ ocaml schema_runtime.cma parse4.ml 2>/dev/null
  Name sym0

-- RangeConstraint: struct with optional int fields; absent key -> None --

  $ cat > parse5.ml << 'EOF'
  > #use "topfind";;
  > #require "jsont";;
  > #require "jsont.bytesrw";;
  > #use "schema_pytorch.ml";;
  > let pp_opt ppf = function
  >   | None   -> Format.fprintf ppf "none"
  >   | Some n -> Format.fprintf ppf "%d" n
  > let pp ppf v =
  >   Format.fprintf ppf "min=%a max=%a"
  >     pp_opt v.RangeConstraint.min_val
  >     pp_opt v.RangeConstraint.max_val
  > let () =
  >   Format.printf "%a@."
  >     (Format.pp_print_result ~ok:pp ~error:Format.pp_print_string)
  >     (Jsont_bytesrw.decode_string RangeConstraint.jsont {|{"min_val":0}|})
  > EOF
  $ ocaml schema_runtime.cma parse5.ml 2>/dev/null
  min=0 max=none

-- Node: explicit null on an Optional field is decoded as None --

  $ cat > parse6.ml << 'EOF'
  > #use "topfind";;
  > #require "jsont";;
  > #require "jsont.bytesrw";;
  > #use "schema_pytorch.ml";;
  > let pp_opt_bool ppf = function
  >   | None   -> Format.fprintf ppf "none"
  >   | Some b -> Format.fprintf ppf "%b" b
  > let pp ppf v =
  >   Format.fprintf ppf "target=%s is_hop=%a"
  >     v.Node.target
  >     pp_opt_bool v.Node.is_hop_single_tensor_return
  > let () =
  >   let json = {|{"target":"t","inputs":[],"outputs":[],"metadata":{},"is_hop_single_tensor_return":null}|} in
  >   Format.printf "%a@."
  >     (Format.pp_print_result ~ok:pp ~error:Format.pp_print_string)
  >     (Jsont_bytesrw.decode_string Node.jsont json)
  > EOF
  $ ocaml schema_runtime.cma parse6.ml 2>/dev/null
  target=t is_hop=none
