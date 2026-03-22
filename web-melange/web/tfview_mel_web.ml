let parse (data : string) : string =
  Print.model_to_string (Bytes.unsafe_of_string data)

let graph (data : string) : Js.Json.t =
  Model_explorer.GraphCollection.jsont
    (Graph.model_to_graph (Bytes.unsafe_of_string data))
