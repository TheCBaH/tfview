open Js_of_ocaml

let parse bytes =
  let data = Bytes.unsafe_of_string (Js.to_bytestring bytes) in
  Js.string (Print.model_to_string data)

let graph bytes =
  let data = Bytes.unsafe_of_string (Js.to_bytestring bytes) in
  let gc = Graph.model_to_graph data in
  match Jsont_brr.encode_jv Model_explorer.GraphCollection.jsont gc with
  | Ok jv -> jv
  | Error e -> Jv.throw (Jv.Error.message e)

let () =
  Js.export "tfview"
    object%js
      method parse bytes = parse bytes
      method graph bytes = graph bytes
    end
