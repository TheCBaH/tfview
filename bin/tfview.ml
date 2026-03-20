open Tflite_schema
open Tflite

let read_file path =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let buf = Bytes.create n in
  really_input ic buf 0 n;
  close_in ic;
  Bytes.to_string buf

let string_of_int_array b v =
  let arr = Rt.Int.Vector.to_array b v in
  "["
  ^ (Array.to_list arr |> List.map Int32.to_string |> String.concat ", ")
  ^ "]"

let effective_opcode b op =
  let builtin = OperatorCode.builtin_code b op in
  if builtin = BuiltinOperator.add then
    let dep = OperatorCode.deprecated_builtin_code b op in
    if dep = 0 then builtin
    else
      BuiltinOperator.of_underlying
        (Flatbuffers.Runtime.Int.of_default (Int64.of_int dep))
  else builtin

let string_of_padding p = Padding.to_string p

let string_of_activation a =
  if a = ActivationFunctionType.none then ""
  else Printf.sprintf " activation=%s" (ActivationFunctionType.to_string a)

let print_builtin_options b op =
  Operator.builtin_options
    ~conv2_doptions:(fun o ->
      Printf.printf "      padding=%s stride=[%ld,%ld] dilation=[%ld,%ld]%s\n"
        (string_of_padding (Conv2Doptions.padding b o))
        (Conv2Doptions.stride_w b o)
        (Conv2Doptions.stride_h b o)
        (Conv2Doptions.dilation_w_factor b o)
        (Conv2Doptions.dilation_h_factor b o)
        (string_of_activation (Conv2Doptions.fused_activation_function b o)))
    ~depthwise_conv2_doptions:(fun o ->
      Printf.printf
        "      padding=%s stride=[%ld,%ld] depth_multiplier=%ld \
         dilation=[%ld,%ld]%s\n"
        (string_of_padding (DepthwiseConv2Doptions.padding b o))
        (DepthwiseConv2Doptions.stride_w b o)
        (DepthwiseConv2Doptions.stride_h b o)
        (DepthwiseConv2Doptions.depth_multiplier b o)
        (DepthwiseConv2Doptions.dilation_w_factor b o)
        (DepthwiseConv2Doptions.dilation_h_factor b o)
        (string_of_activation
           (DepthwiseConv2Doptions.fused_activation_function b o)))
    ~pool2_doptions:(fun o ->
      Printf.printf "      padding=%s stride=[%ld,%ld] filter=[%ld,%ld]%s\n"
        (string_of_padding (Pool2Doptions.padding b o))
        (Pool2Doptions.stride_w b o)
        (Pool2Doptions.stride_h b o)
        (Pool2Doptions.filter_width b o)
        (Pool2Doptions.filter_height b o)
        (string_of_activation (Pool2Doptions.fused_activation_function b o)))
    ~softmax_options:(fun o ->
      Printf.printf "      beta=%g\n" (SoftmaxOptions.beta b o))
    ~reshape_options:(fun o ->
      Rt.Option.iter
        (fun v ->
          Printf.printf "      new_shape=%s\n" (string_of_int_array b v))
        (ReshapeOptions.new_shape b o))
    ~fully_connected_options:(fun o ->
      Printf.printf "      weights_format=%s%s\n"
        (FullyConnectedOptionsWeightsFormat.to_string
           (FullyConnectedOptions.weights_format b o))
        (string_of_activation
           (FullyConnectedOptions.fused_activation_function b o)))
    ~concatenation_options:(fun o ->
      Printf.printf "      axis=%ld%s\n"
        (ConcatenationOptions.axis b o)
        (string_of_activation
           (ConcatenationOptions.fused_activation_function b o)))
    ~add_options:(fun o ->
      Printf.printf "      %s\n"
        (string_of_activation (AddOptions.fused_activation_function b o)))
    ~default:(fun tag ->
      let name = BuiltinOptions.to_string tag in
      if name <> "none" then Printf.printf "      <%s>\n" name)
    b op

let print_model path =
  let buf = read_file path in
  let (Rt.Root (b, model)) = Model.root Flatbuffers.Primitives.String buf in

  (* Version and description *)
  Printf.printf "Model version: %ld\n" (Model.version b model);
  Rt.Option.iter
    (fun s -> Printf.printf "Description: %s\n" (Rt.String.to_string b s))
    (Model.description b model);

  (* Operator codes *)
  let op_codes = Model.operator_codes b model in
  Rt.Option.iter
    (fun ops ->
      let n = OperatorCode.Vector.length b ops in
      Printf.printf "\nOperator codes: %d\n" n;
      for i = 0 to n - 1 do
        let op = OperatorCode.Vector.get b ops i in
        Printf.printf "  [%d] %s" i
          (BuiltinOperator.to_string (effective_opcode b op));
        Rt.Option.iter
          (fun s -> Printf.printf " (custom: %s)" (Rt.String.to_string b s))
          (OperatorCode.custom_code b op);
        Printf.printf "\n"
      done)
    op_codes;

  (* Subgraphs *)
  Rt.Option.iter
    (fun subgraphs ->
      let n_sg = SubGraph.Vector.length b subgraphs in
      Printf.printf "\nSubgraphs: %d\n" n_sg;
      for sg_i = 0 to n_sg - 1 do
        let sg = SubGraph.Vector.get b subgraphs sg_i in
        Printf.printf "\n--- Subgraph %d" sg_i;
        Rt.Option.iter
          (fun s -> Printf.printf " (%s)" (Rt.String.to_string b s))
          (SubGraph.name b sg);
        Printf.printf " ---\n";

        (* Inputs/outputs *)
        Rt.Option.iter
          (fun v -> Printf.printf "  Inputs: %s\n" (string_of_int_array b v))
          (SubGraph.inputs b sg);
        Rt.Option.iter
          (fun v -> Printf.printf "  Outputs: %s\n" (string_of_int_array b v))
          (SubGraph.outputs b sg);

        (* Operators *)
        Rt.Option.iter
          (fun ops ->
            let n_ops = Operator.Vector.length b ops in
            Printf.printf "  Operators: %d\n" n_ops;
            for op_i = 0 to n_ops - 1 do
              let op = Operator.Vector.get b ops op_i in
              let opcode_idx = Int32.to_int (Operator.opcode_index b op) in
              let op_name =
                Rt.Option.fold ~none:"<unknown>"
                  ~some:(fun codes ->
                    let code = OperatorCode.Vector.get b codes opcode_idx in
                    BuiltinOperator.to_string (effective_opcode b code))
                  op_codes
              in
              let inputs =
                Rt.Option.fold ~none:"[]"
                  ~some:(fun v -> string_of_int_array b v)
                  (Operator.inputs b op)
              in
              let outputs =
                Rt.Option.fold ~none:"[]"
                  ~some:(fun v -> string_of_int_array b v)
                  (Operator.outputs b op)
              in
              Printf.printf "    [%d] %-30s inputs=%-20s outputs=%s\n" op_i
                op_name inputs outputs;
              print_builtin_options b op
            done)
          (SubGraph.operators b sg);

        (* Tensors *)
        Rt.Option.iter
          (fun tensors ->
            let n_t = Tensor.Vector.length b tensors in
            Printf.printf "  Tensors: %d\n" n_t;
            for t_i = 0 to n_t - 1 do
              let tensor = Tensor.Vector.get b tensors t_i in
              let name =
                Rt.Option.fold ~none:"<unnamed>"
                  ~some:(fun s -> Rt.String.to_string b s)
                  (Tensor.name b tensor)
              in
              let ty = TensorType.to_string (Tensor.type_ b tensor) in
              let shape =
                Rt.Option.fold ~none:"[]"
                  ~some:(fun v -> string_of_int_array b v)
                  (Tensor.shape b tensor)
              in
              Printf.printf "    [%d] %-40s %-12s %s\n" t_i name ty shape
            done)
          (SubGraph.tensors b sg)
      done)
    (Model.subgraphs b model)

let () =
  if Array.length Sys.argv < 2 then (
    Printf.eprintf "Usage: tfview <model.tflite>\n";
    exit 1);
  print_model Sys.argv.(1)
