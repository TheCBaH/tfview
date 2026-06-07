let () =
  if Array.length Sys.argv < 2 then (
    Printf.eprintf "Usage: schema_gen <schema.yaml>\n";
    exit 1);
  let path = Sys.argv.(1) in
  let yaml = In_channel.with_open_bin path In_channel.input_all in
  match Pytorch_schema.Schema.of_yaml_string yaml with
  | Error (`Msg e) ->
      Printf.eprintf "Schema parse error: %s\n" e;
      exit 1
  | Ok schema ->
      let types = Pytorch_schema.Schema.types schema in
      print_string (Schema_codegen.generate types)
