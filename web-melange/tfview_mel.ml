external read_file_sync : string -> Node.Buffer.t = "readFileSync"
[@@mel.module "fs"]

let () =
  let args = Node.Process.argv in
  if Array.length args < 3 then (
    Printf.eprintf "Usage: node tfview_mel.js <model.tflite>\n";
    Node.Process.exit 1);
  let path = args.(2) in
  let buf = read_file_sync path in
  let data =
    Bytes.unsafe_of_string (Node.Buffer.toString ~encoding:`binary buf)
  in
  print_string (Print.model_to_string data)
