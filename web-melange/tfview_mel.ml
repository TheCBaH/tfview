external read_file_sync : string -> Js.Typed_array.Uint8Array.t = "readFileSync"
[@@mel.module "fs"]

let dataview_of_uint8array : Js.Typed_array.Uint8Array.t -> Js_dataview.t =
  [%mel.raw
    {|function(u8) { return new DataView(u8.buffer, u8.byteOffset, u8.byteLength) }|}]

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
  let dv = dataview_of_uint8array buf in
  if !graph_mode then
    let gc = Graph.model_to_graph_with Flatbuffers.Primitives.JsDataView dv in
    print_string (Js.Json.stringify (Model_explorer.GraphCollection.jsont gc))
  else
    print_string
      (Print.model_to_string_with Flatbuffers.Primitives.JsDataView dv)
