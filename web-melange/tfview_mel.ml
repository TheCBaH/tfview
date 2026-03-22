external read_file_sync : string -> Node.Buffer.t = "readFileSync"
[@@mel.module "fs"]

let () =
  let args = Node.Process.argv in
  let graph_mode = ref false in
  let file_idx = ref 3 in
  if Array.length args >= 3 && args.(2) = "--graph" then (
    graph_mode := true;
    file_idx := 3)
  else file_idx := 2;
  if Array.length args <= !file_idx then (
    Printf.eprintf "Usage: node tfview_mel.js [--graph] <model.tflite>\n";
    Node.Process.exit 1);
  let path = args.(!file_idx) in
  let buf = read_file_sync path in
  let data =
    Bytes.unsafe_of_string (Node.Buffer.toString ~encoding:`binary buf)
  in
  if !graph_mode then
    let gc = Graph.model_to_graph data in
    print_string (Js.Json.stringify (Model_explorer.GraphCollection.jsont gc))
  else print_string (Print.model_to_string data)
