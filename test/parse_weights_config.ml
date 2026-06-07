let () =
  let name = Sys.argv.(1) in
  let file = Sys.argv.(2) in
  let json = In_channel.with_open_bin file In_channel.input_all in
  match
    Jsont_bytesrw.decode_string Pytorch_weights_config.ModelWeightsConfig.jsont
      json
  with
  | Error e ->
      Printf.eprintf "%s: Error: %s\n" name e;
      exit 1
  | Ok wc ->
      let open Pytorch_weights_config in
      let cfg = wc.ModelWeightsConfig.config in
      let n = Schema_runtime.String_map.cardinal cfg in
      let first_key, first_entry = Schema_runtime.String_map.min_binding cfg in
      Printf.printf "%s: weights=%d first=%s path_name=%s is_param=%b\n" name n
        first_key first_entry.WeightEntry.path_name
        first_entry.WeightEntry.is_param
