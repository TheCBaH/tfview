Explore the correct Jsont pattern for Optional fields that accept both an
absent key and an explicit JSON null.

opt_mem "field" T_jsont          -- fails on explicit null
opt_mem "field" (Jsont.option T)  -- absent->None, null->None
Use Option.join in the constructor to flatten 'a option option -> 'a option.

  $ cat > explore.ml << 'EOF'
  > #use "topfind";;
  > #require "jsont";;
  > #require "jsont.bytesrw";;
  > type range = { min_val : int option; max_val : int option }
  > let range_jsont =
  >   Jsont.Object.map ~kind:"Range" (fun min_val max_val ->
  >     { min_val = Option.join min_val; max_val = Option.join max_val })
  >   |> Jsont.Object.opt_mem "min_val" (Jsont.option Jsont.int)
  >   |> Jsont.Object.opt_mem "max_val" (Jsont.option Jsont.int)
  >   |> Jsont.Object.finish
  > let pp_opt ppf = function
  >   | None   -> Format.fprintf ppf "none"
  >   | Some n -> Format.fprintf ppf "%d" n
  > let pp ppf v =
  >   Format.fprintf ppf "min=%a max=%a" pp_opt v.min_val pp_opt v.max_val
  > let check label json =
  >   Format.printf "%s: %a@." label
  >     (Format.pp_print_result ~ok:pp
  >        ~error:(fun ppf e -> Format.fprintf ppf "Error: %s" e))
  >     (Jsont_bytesrw.decode_string range_jsont json)
  > let () =
  >   check "absent key"    {|{}|};
  >   check "key present"   {|{"min_val":0}|};
  >   check "explicit null" {|{"min_val":null}|};
  >   check "both present"  {|{"min_val":1,"max_val":2}|}
  > EOF
  $ ocaml explore.ml 2>/dev/null
  absent key: min=none max=none
  key present: min=0 max=none
  explicit null: min=none max=none
  both present: min=1 max=2
