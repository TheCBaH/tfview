let dataview_of_uint8array : Js.Typed_array.Uint8Array.t -> Js_dataview.t =
  [%mel.raw
    {|function(u8) { return new DataView(u8.buffer, u8.byteOffset, u8.byteLength) }|}]

let parse (u8 : Js.Typed_array.Uint8Array.t) : string =
  let dv = dataview_of_uint8array u8 in
  Print.model_to_string_with Flatbuffers.Primitives.JsDataView dv

let graph (u8 : Js.Typed_array.Uint8Array.t) : Js.Json.t =
  let dv = dataview_of_uint8array u8 in
  Model_explorer.GraphCollection.jsont
    (Graph.model_to_graph_with Flatbuffers.Primitives.JsDataView dv)
