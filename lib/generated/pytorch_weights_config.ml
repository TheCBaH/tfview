open Schema_runtime
open Pytorch_types

module WeightEntry = struct
  type t = {
    path_name : string;
    is_param : bool;
    use_pickle : bool;
    tensor_meta : TensorMeta.t;
  }

  let make path_name is_param use_pickle tensor_meta =
    { path_name; is_param; use_pickle; tensor_meta }

  let jsont =
    Jsont.Object.map ~kind:"WeightEntry" make
    |> Jsont.Object.mem "path_name" Jsont.string
    |> Jsont.Object.mem "is_param" Jsont.bool
    |> Jsont.Object.mem "use_pickle" Jsont.bool
    |> Jsont.Object.mem "tensor_meta" TensorMeta.jsont
    |> Jsont.Object.finish
end

module ModelWeightsConfig = struct
  type t = { config : WeightEntry.t String_map.t }

  let make config = { config }

  let jsont =
    Jsont.Object.map ~kind:"ModelWeightsConfig" make
    |> Jsont.Object.mem "config" (Jsont.Object.as_string_map WeightEntry.jsont)
    |> Jsont.Object.finish
end
