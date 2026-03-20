let read_file path =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let buf = Bytes.create n in
  really_input ic buf 0 n;
  close_in ic;
  Bytes.to_string buf

let () =
  if Array.length Sys.argv < 2 then (
    Printf.eprintf "Usage: tfview <model.tflite>\n";
    exit 1);
  print_string (Print.model_to_string (read_file Sys.argv.(1)))
