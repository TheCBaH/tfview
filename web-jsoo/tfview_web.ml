open Js_of_ocaml

let dataview_of_uint8array (u8 : Typed_array.uint8Array Js.t) : Js_dataview.t =
  let ab = u8##.buffer in
  let off = u8##.byteOffset in
  let len = u8##.byteLength in
  let constr = Js.Unsafe.global##._DataView in
  Js.Unsafe.new_obj constr
    [| Js.Unsafe.inject ab; Js.Unsafe.inject off; Js.Unsafe.inject len |]

let parse bytes =
  let dv = dataview_of_uint8array bytes in
  Js.string (Print.model_to_string_with Flatbuffers.Primitives.JsDataView dv)

let graph bytes =
  let dv = dataview_of_uint8array bytes in
  let gc = Graph.model_to_graph_with Flatbuffers.Primitives.JsDataView dv in
  match Jsont_brr.encode_jv Model_explorer.GraphCollection.jsont gc with
  | Ok jv -> jv
  | Error e -> Jv.throw (Jv.Error.message e)

let () =
  Js.export "tfview"
    object%js
      method parse bytes = parse bytes
      method graph bytes = graph bytes
    end
