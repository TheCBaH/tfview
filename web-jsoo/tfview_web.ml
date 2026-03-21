open Js_of_ocaml

let parse bytes =
  let data = Bytes.unsafe_of_string (Js.to_bytestring bytes) in
  Js.string (Print.model_to_string data)

let () =
  Js.export "tfview"
    object%js
      method parse bytes = parse bytes
    end
