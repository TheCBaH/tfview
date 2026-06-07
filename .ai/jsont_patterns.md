# Jsont Patterns and Pitfalls

## Library overview

`jsont` is an OCaml library for zero-copy JSON encode/decode. Key entry points used
in this project:

```ocaml
(* Primitives *)
Jsont.string : string Jsont.t
Jsont.int    : int    Jsont.t
Jsont.bool   : bool   Jsont.t
Jsont.number : float  Jsont.t
Jsont.json   : Jsont.json Jsont.t     (* raw JSON value; used for union dispatch *)

(* Combinators *)
Jsont.list   : 'a Jsont.t -> 'a list Jsont.t
Jsont.option : 'a Jsont.t -> 'a option Jsont.t  (* absent=None, null=None *)
Jsont.map ~kind ~dec ~enc : 'b Jsont.t -> 'a Jsont.t  (* general transformation *)
Jsont.rec'   : 'a Jsont.t Lazy.t -> 'a Jsont.t  (* force lazy for recursive types *)

(* Object combinators *)
Jsont.Object.map    ~kind ctor  (* start an object decoder *)
Jsont.Object.mem    "key" t     (* required field *)
Jsont.Object.opt_mem "key" t    (* optional field; absent → passes None *)
Jsont.Object.finish             (* finalize object decoder *)
Jsont.Object.as_string_map : 'a Jsont.t -> 'a String_map.t Jsont.t

(* Error *)
Jsont.Error.msg  meta s         (* raise a decode error with message s *)
Jsont.Error.msgf meta fmt ...   (* like Fmt.failwithf *)

(* Decoding *)
Jsont_bytesrw.decode_string : 'a Jsont.t -> string -> ('a, string) result
Jsont.Json.decode : 'a Jsont.t -> Jsont.json -> ('a, string) result
```

## Pattern: struct with a required field

```ocaml
let jsont =
  Jsont.Object.map ~kind:"Point" (fun x y -> { x; y })
  |> Jsont.Object.mem "x" Jsont.int
  |> Jsont.Object.mem "y" Jsont.int
  |> Jsont.Object.finish
```

## Pattern: struct with an Optional field (absent OR explicit null → None)

`Jsont.Object.opt_mem "f" T_jsont` passes `None` to the constructor when the key
is absent, but **errors on explicit JSON null**.

The correct pattern for PyTorch's `Optional[T]` fields (which serialize explicit null)
is to wrap with `Jsont.option` and `Option.join` in the constructor:

```ocaml
Jsont.Object.map ~kind:"Range" (fun min_val max_val ->
  { min_val = Option.join min_val; max_val = Option.join max_val })
|> Jsont.Object.opt_mem "min_val" (Jsont.option Jsont.int)
|> Jsont.Object.opt_mem "max_val" (Jsont.option Jsont.int)
|> Jsont.Object.finish
```

What the constructor receives for each case:
| JSON | `opt_mem (Jsont.option T)` delivers | After `Option.join` |
|---|---|---|
| key absent | `None` | `None` |
| `"key": null` | `Some None` | `None` |
| `"key": 42` | `Some (Some 42)` | `Some 42` |

## Pattern: struct with a non-Optional default

For fields like `is_single_tensor_return: bool` (default `False`) — the key may be
absent from JSON but `false` should be used, not `None`. Use `opt_mem` without the
`Jsont.option` wrapper, and a `match` in the constructor:

```ocaml
Jsont.Object.map ~kind:"Graph" (fun is_single_tensor_return ... ->
  { is_single_tensor_return =
      (match is_single_tensor_return with None -> false | Some v -> v)
  ; ... })
|> Jsont.Object.opt_mem "is_single_tensor_return" Jsont.bool
...
```

**Do not use** `Option.value ~default:false` here: `Option.value ~default:expr`
evaluates `expr` unconditionally even when the option is `Some v`. If `expr` is
`failwith "..."` this crashes. The `match` is the correct lazy form.

## Pattern: union (single-key dispatch)

PyTorch unions serialize as `{"case_name": payload}`. Decode via `Jsont.json`,
then pattern-match on the raw `Jsont.json` value:

```ocaml
Jsont.map ~kind:"SymIntArgument"
  ~dec:(fun json -> match json with
    | Jsont.Object ([ ((key, _), value) ], _) ->
        (match key with
         | "as_int"  -> (match Jsont.Json.decode Jsont.int value with
                         | Ok v -> Int v | Error s -> Jsont.Error.msg Jsont.Meta.none s)
         | "as_name" -> (match Jsont.Json.decode Jsont.string value with
                         | Ok v -> Name v | Error s -> Jsont.Error.msg Jsont.Meta.none s)
         | k -> Jsont.Error.msgf Jsont.Meta.none "Unknown SymIntArgument case: %s" k)
    | Jsont.Object _ ->
        Jsont.Error.msgf Jsont.Meta.none "SymIntArgument must have exactly one member"
    | _ ->
        Jsont.Error.msgf Jsont.Meta.none "SymIntArgument must be a JSON object")
  ~enc:(fun _ -> assert false)
  Jsont.json
```

The `~enc` stub is `assert false` because encoding is not yet needed.

## Pattern: enum (integer-keyed variant)

```ocaml
Jsont.map ~kind:"ArgumentKind"
  ~dec:(fun n -> match n with
    | 0 -> UNKNOWN | 1 -> POSITIONAL | 2 -> KEYWORD
    | n -> Jsont.Error.msgf Jsont.Meta.none "Unknown ArgumentKind value: %d" n)
  ~enc:(fun v -> match v with UNKNOWN -> 0 | POSITIONAL -> 1 | KEYWORD -> 2)
  Jsont.int
```

## Pattern: Dict[str, T]

```ocaml
Jsont.Object.as_string_map T_jsont : T String_map.t Jsont.t
```

This decodes any JSON object as a `Map.Make(String)` keyed map.

## Pattern: recursive types via Lazy

When type A references type B and B references type A, `Jsont.t` values cannot be
constructed as plain `let rec` bindings (the RHS is not a syntactic value). Solution:

```ocaml
let rec a_jsont : A_Type.t Jsont.t Lazy.t = lazy (
  Jsont.Object.map ~kind:"A" ...
  |> Jsont.Object.mem "b" (Lazy.force b_jsont)
  |> Jsont.Object.finish)

and b_jsont : B_Type.t Jsont.t Lazy.t = lazy (
  Jsont.Object.map ~kind:"B" ...
  |> Jsont.Object.mem "a" (Lazy.force a_jsont)
  |> Jsont.Object.finish)

module A = struct
  include A_Type
  let jsont = Jsont.rec' a_jsont   (* Jsont.rec' forces the Lazy.t once *)
end
```

## Decoding in cram tests (via OCaml toplevel)

```ocaml
(* After #use "schema_pytorch.ml" *)
let result = Jsont_bytesrw.decode_string ExportedProgram.jsont json_string in
Format.printf "%a@."
  (Format.pp_print_result ~ok:pp_model ~error:Format.pp_print_string)
  result
```

`pp_print_result ~ok:pp ~error:Format.pp_print_string` is the idiomatic way to print
a `('a, string) result`; the `~error` printer does not need a custom lambda.
