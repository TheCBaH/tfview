module Buf = Buffer
open Tflite_schema.Tflite
module Rt = Tflite_schema.Rt

let string_of_int_array b v =
  let arr = Rt.Int.Vector.to_array b v in
  "["
  ^ (Array.to_list arr |> List.map Int32.to_string |> String.concat ", ")
  ^ "]"

let string_of_float_array b v =
  let arr = Rt.Float.Vector.to_array b v in
  "["
  ^ (Array.to_list arr |> List.map (Printf.sprintf "%g") |> String.concat ", ")
  ^ "]"

let string_of_long_array b v =
  let arr = Rt.Long.Vector.to_array b v in
  "["
  ^ (Array.to_list arr |> List.map Int64.to_string |> String.concat ", ")
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

let string_of_activation a =
  if a = ActivationFunctionType.none then ""
  else Printf.sprintf " activation=%s" (ActivationFunctionType.to_string a)

let bprint_builtin_options buf b op =
  Operator.builtin_options
    ~conv2_doptions:(fun o ->
      Printf.bprintf buf
        "      padding=%s stride=[%ld,%ld] dilation=[%ld,%ld]%s\n"
        (Padding.to_string (Conv2Doptions.padding b o))
        (Conv2Doptions.stride_w b o)
        (Conv2Doptions.stride_h b o)
        (Conv2Doptions.dilation_w_factor b o)
        (Conv2Doptions.dilation_h_factor b o)
        (string_of_activation (Conv2Doptions.fused_activation_function b o)))
    ~depthwise_conv2_doptions:(fun o ->
      Printf.bprintf buf
        "      padding=%s stride=[%ld,%ld] depth_multiplier=%ld \
         dilation=[%ld,%ld]%s\n"
        (Padding.to_string (DepthwiseConv2Doptions.padding b o))
        (DepthwiseConv2Doptions.stride_w b o)
        (DepthwiseConv2Doptions.stride_h b o)
        (DepthwiseConv2Doptions.depth_multiplier b o)
        (DepthwiseConv2Doptions.dilation_w_factor b o)
        (DepthwiseConv2Doptions.dilation_h_factor b o)
        (string_of_activation
           (DepthwiseConv2Doptions.fused_activation_function b o)))
    ~pool2_doptions:(fun o ->
      Printf.bprintf buf
        "      padding=%s stride=[%ld,%ld] filter=[%ld,%ld]%s\n"
        (Padding.to_string (Pool2Doptions.padding b o))
        (Pool2Doptions.stride_w b o)
        (Pool2Doptions.stride_h b o)
        (Pool2Doptions.filter_width b o)
        (Pool2Doptions.filter_height b o)
        (string_of_activation (Pool2Doptions.fused_activation_function b o)))
    ~softmax_options:(fun o ->
      Printf.bprintf buf "      beta=%g\n" (SoftmaxOptions.beta b o))
    ~reshape_options:(fun o ->
      Rt.Option.iter
        (fun v ->
          Printf.bprintf buf "      new_shape=%s\n" (string_of_int_array b v))
        (ReshapeOptions.new_shape b o))
    ~fully_connected_options:(fun o ->
      Printf.bprintf buf "      weights_format=%s%s\n"
        (FullyConnectedOptionsWeightsFormat.to_string
           (FullyConnectedOptions.weights_format b o))
        (string_of_activation
           (FullyConnectedOptions.fused_activation_function b o)))
    ~concatenation_options:(fun o ->
      Printf.bprintf buf "      axis=%ld%s\n"
        (ConcatenationOptions.axis b o)
        (string_of_activation
           (ConcatenationOptions.fused_activation_function b o)))
    ~add_options:(fun o ->
      Printf.bprintf buf "      %s\n"
        (string_of_activation (AddOptions.fused_activation_function b o)))
    ~mul_options:(fun o ->
      Printf.bprintf buf "      %s\n"
        (string_of_activation (MulOptions.fused_activation_function b o)))
    ~sub_options:(fun o ->
      Printf.bprintf buf "      pot_scale_int16=%b%s\n"
        (SubOptions.pot_scale_int16 b o)
        (string_of_activation (SubOptions.fused_activation_function b o)))
    ~gather_options:(fun o ->
      Printf.bprintf buf "      axis=%ld batch_dims=%ld\n"
        (GatherOptions.axis b o)
        (GatherOptions.batch_dims b o))
    ~pack_options:(fun o ->
      Printf.bprintf buf "      values_count=%ld axis=%ld\n"
        (PackOptions.values_count b o)
        (PackOptions.axis b o))
    ~unpack_options:(fun o ->
      Printf.bprintf buf "      num=%ld axis=%ld\n" (UnpackOptions.num b o)
        (UnpackOptions.axis b o))
    ~cast_options:(fun o ->
      Printf.bprintf buf "      in_data_type=%s out_data_type=%s\n"
        (TensorType.to_string (CastOptions.in_data_type b o))
        (TensorType.to_string (CastOptions.out_data_type b o)))
    ~resize_bilinear_options:(fun o ->
      Printf.bprintf buf "      align_corners=%b half_pixel_centers=%b\n"
        (ResizeBilinearOptions.align_corners b o)
        (ResizeBilinearOptions.half_pixel_centers b o))
    ~strided_slice_options:(fun o ->
      Printf.bprintf buf
        "      begin_mask=%ld end_mask=%ld ellipsis_mask=%ld new_axis_mask=%ld \
         shrink_axis_mask=%ld\n"
        (StridedSliceOptions.begin_mask b o)
        (StridedSliceOptions.end_mask b o)
        (StridedSliceOptions.ellipsis_mask b o)
        (StridedSliceOptions.new_axis_mask b o)
        (StridedSliceOptions.shrink_axis_mask b o))
    ~reducer_options:(fun o ->
      Printf.bprintf buf "      keep_dims=%b\n" (ReducerOptions.keep_dims b o))
    ~skip_gram_options:(fun o ->
      Printf.bprintf buf
        "      ngram_size=%ld max_skip_size=%ld include_all_ngrams=%b\n"
        (SkipGramOptions.ngram_size b o)
        (SkipGramOptions.max_skip_size b o)
        (SkipGramOptions.include_all_ngrams b o))
    ~lshprojection_options:(fun o ->
      Printf.bprintf buf "      type=%s\n"
        (LshprojectionType.to_string (LshprojectionOptions.type_ b o)))
    ~lstmoptions:(fun o ->
      Printf.bprintf buf "      kernel_type=%s cell_clip=%g proj_clip=%g%s\n"
        (LstmkernelType.to_string (Lstmoptions.kernel_type b o))
        (Lstmoptions.cell_clip b o)
        (Lstmoptions.proj_clip b o)
        (string_of_activation (Lstmoptions.fused_activation_function b o)))
    ~rnnoptions:(fun o ->
      Printf.bprintf buf "      %s\n"
        (string_of_activation (Rnnoptions.fused_activation_function b o)))
    ~transpose_options:(fun _o -> Printf.bprintf buf "")
    ~pad_options:(fun _o -> Printf.bprintf buf "")
    ~log_softmax_options:(fun _o -> Printf.bprintf buf "")
    ~hard_swish_options:(fun _o -> Printf.bprintf buf "")
    ~default:(fun tag ->
      let name = BuiltinOptions.to_string tag in
      if name <> "none" then Printf.bprintf buf "      <%s>\n" name)
    b op

let model_to_string_with prim data =
  let (Rt.Root (b, model)) = Model.root prim data in
  let buf = Buf.create 4096 in

  (* Version and description *)
  Printf.bprintf buf "Model version: %ld\n" (Model.version b model);
  Rt.Option.iter
    (fun s -> Printf.bprintf buf "Description: %s\n" (Rt.String.to_string b s))
    (Model.description b model);

  (* Operator codes *)
  let op_codes = Model.operator_codes b model in
  Rt.Option.iter
    (fun ops ->
      let n = OperatorCode.Vector.length b ops in
      Printf.bprintf buf "\nOperator codes: %d\n" n;
      for i = 0 to n - 1 do
        let op = OperatorCode.Vector.get b ops i in
        Printf.bprintf buf "  [%d] %s" i
          (BuiltinOperator.to_string (effective_opcode b op));
        Rt.Option.iter
          (fun s ->
            Printf.bprintf buf " (custom: %s)" (Rt.String.to_string b s))
          (OperatorCode.custom_code b op);
        Buf.add_char buf '\n'
      done)
    op_codes;

  (* Subgraphs *)
  Rt.Option.iter
    (fun subgraphs ->
      let n_sg = SubGraph.Vector.length b subgraphs in
      Printf.bprintf buf "\nSubgraphs: %d\n" n_sg;
      for sg_i = 0 to n_sg - 1 do
        let sg = SubGraph.Vector.get b subgraphs sg_i in
        Printf.bprintf buf "\n--- Subgraph %d" sg_i;
        Rt.Option.iter
          (fun s -> Printf.bprintf buf " (%s)" (Rt.String.to_string b s))
          (SubGraph.name b sg);
        Buf.add_string buf " ---\n";

        (* Inputs/outputs *)
        Rt.Option.iter
          (fun v ->
            Printf.bprintf buf "  Inputs: %s\n" (string_of_int_array b v))
          (SubGraph.inputs b sg);
        Rt.Option.iter
          (fun v ->
            Printf.bprintf buf "  Outputs: %s\n" (string_of_int_array b v))
          (SubGraph.outputs b sg);

        (* Operators *)
        Rt.Option.iter
          (fun ops ->
            let n_ops = Operator.Vector.length b ops in
            Printf.bprintf buf "  Operators: %d\n" n_ops;
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
              Printf.bprintf buf "    [%d] %-30s inputs=%-20s outputs=%s\n" op_i
                op_name inputs outputs;
              bprint_builtin_options buf b op
            done)
          (SubGraph.operators b sg);

        (* Tensors *)
        Rt.Option.iter
          (fun tensors ->
            let n_t = Tensor.Vector.length b tensors in
            Printf.bprintf buf "  Tensors: %d\n" n_t;
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
              Printf.bprintf buf "    [%d] %-40s %-12s %s\n" t_i name ty shape;
              Rt.Option.iter
                (fun qp ->
                  let has_scale =
                    Rt.Option.fold ~none:false
                      ~some:(fun v -> Rt.Float.Vector.length b v > 0)
                      (QuantizationParameters.scale b qp)
                  in
                  if has_scale then (
                    Rt.Option.iter
                      (fun v ->
                        Printf.bprintf buf "      scale=%s"
                          (string_of_float_array b v))
                      (QuantizationParameters.scale b qp);
                    Rt.Option.iter
                      (fun v ->
                        Printf.bprintf buf " zero_point=%s"
                          (string_of_long_array b v))
                      (QuantizationParameters.zero_point b qp);
                    let qd = QuantizationParameters.quantized_dimension b qp in
                    if qd <> 0l then
                      Printf.bprintf buf " quantized_dimension=%ld" qd;
                    Buf.add_char buf '\n'))
                (Tensor.quantization b tensor)
            done)
          (SubGraph.tensors b sg)
      done)
    (Model.subgraphs b model);

  Buf.contents buf

let model_to_string data =
  model_to_string_with Flatbuffers.Primitives.Bytes data
