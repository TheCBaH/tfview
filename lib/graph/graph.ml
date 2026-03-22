open Tflite_schema.Tflite
module Rt = Tflite_schema.Rt
module ME = Model_explorer

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

let tensor_shape_string b tensor =
  let ty = TensorType.to_string (Tensor.type_ b tensor) in
  let shape =
    Rt.Option.fold ~none:"[]"
      ~some:(fun v -> string_of_int_array b v)
      (Tensor.shape b tensor)
  in
  Printf.sprintf "%s%s" ty shape

let tensor_name b tensor =
  Rt.Option.fold ~none:"<unnamed>"
    ~some:(fun s -> Rt.String.to_string b s)
    (Tensor.name b tensor)

let tensor_metadata b tensors tensor_idx =
  let idx = Int32.to_int tensor_idx in
  if idx < 0 then ME.MetadataItem.create ~id:(string_of_int idx) ~attrs:[]
  else
    let tensor = Tensor.Vector.get b tensors idx in
    let name = tensor_name b tensor in
    let shape = tensor_shape_string b tensor in
    let attrs =
      [
        ME.KeyValue.create ~key:"__tensor_index" ~value:(string_of_int idx);
        ME.KeyValue.create ~key:"__tensor_name" ~value:name;
        ME.KeyValue.create ~key:"__tensor_shape" ~value:shape;
      ]
    in
    let attrs =
      Rt.Option.fold ~none:attrs
        ~some:(fun qp ->
          let has_scale =
            Rt.Option.fold ~none:false
              ~some:(fun v -> Rt.Float.Vector.length b v > 0)
              (QuantizationParameters.scale b qp)
          in
          if has_scale then
            let scale =
              Rt.Option.fold ~none:""
                ~some:(fun v ->
                  let arr = Rt.Float.Vector.to_array b v in
                  "["
                  ^ (Array.to_list arr
                    |> List.map (Printf.sprintf "%g")
                    |> String.concat ", ")
                  ^ "]")
                (QuantizationParameters.scale b qp)
            in
            let zp =
              Rt.Option.fold ~none:""
                ~some:(fun v ->
                  let arr = Rt.Long.Vector.to_array b v in
                  "["
                  ^ (Array.to_list arr |> List.map Int64.to_string
                   |> String.concat ", ")
                  ^ "]")
                (QuantizationParameters.zero_point b qp)
            in
            attrs
            @ [
                ME.KeyValue.create ~key:"quantization"
                  ~value:(Printf.sprintf "scale=%s zero_point=%s" scale zp);
              ]
          else attrs)
        (Tensor.quantization b tensor)
    in
    ME.MetadataItem.create ~id:(string_of_int idx) ~attrs

let builtin_options_attrs b op =
  let attrs = ref [] in
  let add k v = attrs := ME.KeyValue.create ~key:k ~value:v :: !attrs in
  let add_activation a =
    if a <> ActivationFunctionType.none then
      add "activation" (ActivationFunctionType.to_string a)
  in
  Operator.builtin_options
    ~conv2_doptions:(fun o ->
      add "padding" (Padding.to_string (Conv2Doptions.padding b o));
      add "stride"
        (Printf.sprintf "[%ld,%ld]"
           (Conv2Doptions.stride_w b o)
           (Conv2Doptions.stride_h b o));
      add "dilation"
        (Printf.sprintf "[%ld,%ld]"
           (Conv2Doptions.dilation_w_factor b o)
           (Conv2Doptions.dilation_h_factor b o));
      add_activation (Conv2Doptions.fused_activation_function b o))
    ~depthwise_conv2_doptions:(fun o ->
      add "padding" (Padding.to_string (DepthwiseConv2Doptions.padding b o));
      add "stride"
        (Printf.sprintf "[%ld,%ld]"
           (DepthwiseConv2Doptions.stride_w b o)
           (DepthwiseConv2Doptions.stride_h b o));
      add "depth_multiplier"
        (Int32.to_string (DepthwiseConv2Doptions.depth_multiplier b o));
      add "dilation"
        (Printf.sprintf "[%ld,%ld]"
           (DepthwiseConv2Doptions.dilation_w_factor b o)
           (DepthwiseConv2Doptions.dilation_h_factor b o));
      add_activation (DepthwiseConv2Doptions.fused_activation_function b o))
    ~pool2_doptions:(fun o ->
      add "padding" (Padding.to_string (Pool2Doptions.padding b o));
      add "stride"
        (Printf.sprintf "[%ld,%ld]"
           (Pool2Doptions.stride_w b o)
           (Pool2Doptions.stride_h b o));
      add "filter"
        (Printf.sprintf "[%ld,%ld]"
           (Pool2Doptions.filter_width b o)
           (Pool2Doptions.filter_height b o));
      add_activation (Pool2Doptions.fused_activation_function b o))
    ~softmax_options:(fun o ->
      add "beta" (Printf.sprintf "%g" (SoftmaxOptions.beta b o)))
    ~reshape_options:(fun o ->
      Rt.Option.iter
        (fun v -> add "new_shape" (string_of_int_array b v))
        (ReshapeOptions.new_shape b o))
    ~fully_connected_options:(fun o ->
      add "weights_format"
        (FullyConnectedOptionsWeightsFormat.to_string
           (FullyConnectedOptions.weights_format b o));
      add_activation (FullyConnectedOptions.fused_activation_function b o))
    ~concatenation_options:(fun o ->
      add "axis" (Int32.to_string (ConcatenationOptions.axis b o));
      add_activation (ConcatenationOptions.fused_activation_function b o))
    ~add_options:(fun o ->
      add_activation (AddOptions.fused_activation_function b o))
    ~mul_options:(fun o ->
      add_activation (MulOptions.fused_activation_function b o))
    ~sub_options:(fun o ->
      add "pot_scale_int16" (string_of_bool (SubOptions.pot_scale_int16 b o));
      add_activation (SubOptions.fused_activation_function b o))
    ~gather_options:(fun o ->
      add "axis" (Int32.to_string (GatherOptions.axis b o));
      add "batch_dims" (Int32.to_string (GatherOptions.batch_dims b o)))
    ~pack_options:(fun o ->
      add "values_count" (Int32.to_string (PackOptions.values_count b o));
      add "axis" (Int32.to_string (PackOptions.axis b o)))
    ~unpack_options:(fun o ->
      add "num" (Int32.to_string (UnpackOptions.num b o));
      add "axis" (Int32.to_string (UnpackOptions.axis b o)))
    ~cast_options:(fun o ->
      add "in_data_type" (TensorType.to_string (CastOptions.in_data_type b o));
      add "out_data_type" (TensorType.to_string (CastOptions.out_data_type b o)))
    ~resize_bilinear_options:(fun o ->
      add "align_corners"
        (string_of_bool (ResizeBilinearOptions.align_corners b o));
      add "half_pixel_centers"
        (string_of_bool (ResizeBilinearOptions.half_pixel_centers b o)))
    ~strided_slice_options:(fun o ->
      add "begin_mask" (Int32.to_string (StridedSliceOptions.begin_mask b o));
      add "end_mask" (Int32.to_string (StridedSliceOptions.end_mask b o));
      add "ellipsis_mask"
        (Int32.to_string (StridedSliceOptions.ellipsis_mask b o));
      add "new_axis_mask"
        (Int32.to_string (StridedSliceOptions.new_axis_mask b o));
      add "shrink_axis_mask"
        (Int32.to_string (StridedSliceOptions.shrink_axis_mask b o)))
    ~reducer_options:(fun o ->
      add "keep_dims" (string_of_bool (ReducerOptions.keep_dims b o)))
    ~lstmoptions:(fun o ->
      add "kernel_type" (LstmkernelType.to_string (Lstmoptions.kernel_type b o));
      add "cell_clip" (Printf.sprintf "%g" (Lstmoptions.cell_clip b o));
      add "proj_clip" (Printf.sprintf "%g" (Lstmoptions.proj_clip b o));
      add_activation (Lstmoptions.fused_activation_function b o))
    ~rnnoptions:(fun o ->
      add_activation (Rnnoptions.fused_activation_function b o))
    ~skip_gram_options:(fun o ->
      add "ngram_size" (Int32.to_string (SkipGramOptions.ngram_size b o));
      add "max_skip_size" (Int32.to_string (SkipGramOptions.max_skip_size b o));
      add "include_all_ngrams"
        (string_of_bool (SkipGramOptions.include_all_ngrams b o)))
    ~lshprojection_options:(fun o ->
      add "type" (LshprojectionType.to_string (LshprojectionOptions.type_ b o)))
    ~transpose_options:(fun _o -> ())
    ~pad_options:(fun _o -> ())
    ~log_softmax_options:(fun _o -> ())
    ~hard_swish_options:(fun _o -> ())
    ~default:(fun tag ->
      let name = BuiltinOptions.to_string tag in
      if name <> "none" then add "builtin_options" name)
    b op;
  List.rev !attrs

(** Build a mapping from tensor index to the operator node that produces it. *)
let build_tensor_producer_map b sg_idx ops tensors =
  let n_t = Tensor.Vector.length b tensors in
  (* Initialize: all tensors have no producer *)
  let producers = Hashtbl.create n_t in
  let n_ops = Operator.Vector.length b ops in
  for op_i = 0 to n_ops - 1 do
    let op = Operator.Vector.get b ops op_i in
    Rt.Option.iter
      (fun outputs ->
        let arr = Rt.Int.Vector.to_array b outputs in
        Array.iteri
          (fun out_slot tensor_idx ->
            let idx = Int32.to_int tensor_idx in
            if idx >= 0 then
              Hashtbl.replace producers idx
                (Printf.sprintf "op_%d_%d" sg_idx op_i, string_of_int out_slot))
          arr)
      (Operator.outputs b op)
  done;
  producers

let model_to_graph data =
  let (Rt.Root (b, model)) = Model.root Flatbuffers.Primitives.Bytes data in
  let description =
    Rt.Option.fold ~none:"TFLite Model"
      ~some:(fun s ->
        let d = Rt.String.to_string b s in
        if d = "" then "TFLite Model" else d)
      (Model.description b model)
  in
  let op_codes = Model.operator_codes b model in
  let graphs =
    Rt.Option.fold ~none:[]
      ~some:(fun subgraphs ->
        let n_sg = SubGraph.Vector.length b subgraphs in
        let graphs = ref [] in
        for sg_i = 0 to n_sg - 1 do
          let sg = SubGraph.Vector.get b subgraphs sg_i in
          let sg_name =
            Rt.Option.fold
              ~none:(Printf.sprintf "subgraph_%d" sg_i)
              ~some:(fun s ->
                let n = Rt.String.to_string b s in
                if n = "" then Printf.sprintf "subgraph_%d" sg_i else n)
              (SubGraph.name b sg)
          in
          let nodes = ref [] in

          (* Get tensors for metadata *)
          let tensors_opt = SubGraph.tensors b sg in

          (* Build tensor→producer map *)
          let producers =
            Rt.Option.fold ~none:(Hashtbl.create 0)
              ~some:(fun ops ->
                Rt.Option.fold ~none:(Hashtbl.create 0)
                  ~some:(fun tensors ->
                    build_tensor_producer_map b sg_i ops tensors)
                  tensors_opt)
              (SubGraph.operators b sg)
          in

          (* GraphInputs node *)
          let input_node =
            let output_metadata =
              Rt.Option.fold ~none:[]
                ~some:(fun inputs ->
                  let arr = Rt.Int.Vector.to_array b inputs in
                  Array.to_list
                    (Array.mapi
                       (fun slot tensor_idx ->
                         (* Register input tensors as produced by the input node *)
                         let idx = Int32.to_int tensor_idx in
                         if idx >= 0 then
                           Hashtbl.replace producers idx
                             (Printf.sprintf "input_%d" sg_i, string_of_int slot);
                         Rt.Option.fold
                           ~none:
                             (ME.MetadataItem.create ~id:(string_of_int slot)
                                ~attrs:[])
                           ~some:(fun tensors ->
                             tensor_metadata b tensors tensor_idx)
                           tensors_opt)
                       arr))
                (SubGraph.inputs b sg)
            in
            ME.GraphNode.create
              ~id:(Printf.sprintf "input_%d" sg_i)
              ~label:"GraphInputs" ~namespace:""
              ~outputsMetadata:output_metadata
              ~config:(ME.GraphNodeConfig.create ~pinToGroupTop:true ())
              ()
          in
          nodes := input_node :: !nodes;

          (* Operator nodes *)
          Rt.Option.iter
            (fun ops ->
              let n_ops = Operator.Vector.length b ops in
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
                let node_id = Printf.sprintf "op_%d_%d" sg_i op_i in

                (* Incoming edges from input tensors *)
                let incoming_edges =
                  Rt.Option.fold ~none:[]
                    ~some:(fun inputs ->
                      let arr = Rt.Int.Vector.to_array b inputs in
                      let edges = ref [] in
                      Array.iteri
                        (fun in_slot tensor_idx ->
                          let idx = Int32.to_int tensor_idx in
                          if idx >= 0 then
                            match Hashtbl.find_opt producers idx with
                            | Some (src_id, src_out) ->
                                edges :=
                                  ME.IncomingEdge.create ~sourceNodeId:src_id
                                    ~sourceNodeOutputId:src_out
                                    ~targetNodeInputId:(string_of_int in_slot)
                                    ()
                                  :: !edges
                            | None -> ())
                        arr;
                      List.rev !edges)
                    (Operator.inputs b op)
                in

                (* Input metadata *)
                let inputs_metadata =
                  Rt.Option.fold ~none:None
                    ~some:(fun inputs ->
                      Rt.Option.fold ~none:None
                        ~some:(fun tensors ->
                          let arr = Rt.Int.Vector.to_array b inputs in
                          Some
                            (Array.to_list
                               (Array.map
                                  (fun tensor_idx ->
                                    tensor_metadata b tensors tensor_idx)
                                  arr)))
                        tensors_opt)
                    (Operator.inputs b op)
                in

                (* Output metadata *)
                let outputs_metadata =
                  Rt.Option.fold ~none:None
                    ~some:(fun outputs ->
                      Rt.Option.fold ~none:None
                        ~some:(fun tensors ->
                          let arr = Rt.Int.Vector.to_array b outputs in
                          Some
                            (Array.to_list
                               (Array.map
                                  (fun tensor_idx ->
                                    tensor_metadata b tensors tensor_idx)
                                  arr)))
                        tensors_opt)
                    (Operator.outputs b op)
                in

                (* Operator attributes *)
                let attrs = builtin_options_attrs b op in

                let node =
                  ME.GraphNode.create ~id:node_id ~label:op_name ~namespace:""
                    ~incomingEdges:incoming_edges
                    ?inputsMetadata:inputs_metadata
                    ?outputsMetadata:outputs_metadata ~attrs ()
                in
                nodes := node :: !nodes
              done)
            (SubGraph.operators b sg);

          (* GraphOutputs node *)
          let output_node =
            let incoming_edges =
              Rt.Option.fold ~none:[]
                ~some:(fun outputs ->
                  let arr = Rt.Int.Vector.to_array b outputs in
                  let edges = ref [] in
                  Array.iteri
                    (fun in_slot tensor_idx ->
                      let idx = Int32.to_int tensor_idx in
                      if idx >= 0 then
                        match Hashtbl.find_opt producers idx with
                        | Some (src_id, src_out) ->
                            edges :=
                              ME.IncomingEdge.create ~sourceNodeId:src_id
                                ~sourceNodeOutputId:src_out
                                ~targetNodeInputId:(string_of_int in_slot) ()
                              :: !edges
                        | None -> ())
                    arr;
                  List.rev !edges)
                (SubGraph.outputs b sg)
            in
            let input_metadata =
              Rt.Option.fold ~none:[]
                ~some:(fun outputs ->
                  let arr = Rt.Int.Vector.to_array b outputs in
                  Array.to_list
                    (Array.mapi
                       (fun slot tensor_idx ->
                         Rt.Option.fold
                           ~none:
                             (ME.MetadataItem.create ~id:(string_of_int slot)
                                ~attrs:[])
                           ~some:(fun tensors ->
                             tensor_metadata b tensors tensor_idx)
                           tensors_opt)
                       arr))
                (SubGraph.outputs b sg)
            in
            ME.GraphNode.create
              ~id:(Printf.sprintf "output_%d" sg_i)
              ~label:"GraphOutputs" ~namespace:"" ~incomingEdges:incoming_edges
              ~inputsMetadata:input_metadata ()
          in
          nodes := output_node :: !nodes;

          let graph =
            ME.Graph.create
              ~id:(Printf.sprintf "subgraph_%d" sg_i)
              ~collectionLabel:sg_name ~nodes:(List.rev !nodes) ()
          in
          graphs := graph :: !graphs
        done;
        List.rev !graphs)
      (Model.subgraphs b model)
  in
  ME.GraphCollection.create ~label:description ~graphs

let graph_collection_to_json gc =
  Format.asprintf "%a" (Jsont.pp_value ME.GraphCollection.jsont ()) gc

let model_to_graph_json data = graph_collection_to_json (model_to_graph data)
