let read_file path =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let buf = Bytes.create n in
  really_input ic buf 0 n;
  close_in ic;
  buf

let () =
  let graph_mode = ref false in
  let files = ref [] in
  Arg.parse
    [ ("--graph", Arg.Set graph_mode, "Output model-explorer graph JSON") ]
    (fun f -> files := f :: !files)
    "Usage: tfview [--graph] <model.tflite>";
  match !files with
  | [] ->
      Printf.eprintf "Usage: tfview [--graph] <model.tflite>\n";
      exit 1
  | _ ->
      List.iter
        (fun path ->
          let data = read_file path in
          if !graph_mode then print_string (Graph.model_to_graph_json data)
          else print_string (Print.model_to_string data))
        (List.rev !files)
