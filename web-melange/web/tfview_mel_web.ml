let parse (data : string) : string =
  Print.model_to_string (Bytes.unsafe_of_string data)
