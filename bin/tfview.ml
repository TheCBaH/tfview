open Schema
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
  "[" ^ (Array.to_list arr |> List.map Int32.to_string |> String.concat ", ") ^ "]"

let print_model path =
  let buf = read_file path in
  let (Rt.Root (b, model)) = Model.root Flatbuffers.Primitives.String buf in

  (* Version and description *)
  Printf.printf "Model version: %ld\n" (Model.version b model);
  Rt.Option.iter
    (fun s -> Printf.printf "Description: %s\n" (Rt.String.to_string b s))
    (Model.description b model);

  (* Operator codes *)
  Rt.Option.iter (fun ops ->
    let n = OperatorCode.Vector.length b ops in
    Printf.printf "\nOperator codes: %d\n" n;
    for i = 0 to n - 1 do
      let op = OperatorCode.Vector.get b ops i in
      (* Use builtin_code if set, fall back to deprecated_builtin_code *)
      let builtin = OperatorCode.builtin_code b op in
      let effective : BuiltinOperator.t =
        if builtin = BuiltinOperator.add then
          let dep = OperatorCode.deprecated_builtin_code b op in
          if dep = 0 then builtin
          else Obj.magic (Int32.of_int dep)
        else builtin
      in
      Printf.printf "  [%d] %s" i (BuiltinOperator.to_string effective);
      Rt.Option.iter
        (fun s -> Printf.printf " (custom: %s)" (Rt.String.to_string b s))
        (OperatorCode.custom_code b op);
      Printf.printf "\n"
    done
  ) (Model.operator_codes b model);

  (* Subgraphs *)
  Rt.Option.iter (fun subgraphs ->
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

      (* Operator count *)
      Rt.Option.iter
        (fun ops -> Printf.printf "  Operators: %d\n" (Operator.Vector.length b ops))
        (SubGraph.operators b sg);

      (* Tensors *)
      Rt.Option.iter (fun tensors ->
        let n_t = Tensor.Vector.length b tensors in
        Printf.printf "  Tensors: %d\n" n_t;
        for t_i = 0 to n_t - 1 do
          let tensor = Tensor.Vector.get b tensors t_i in
          let name = Rt.Option.fold
            ~none:"<unnamed>"
            ~some:(fun s -> Rt.String.to_string b s)
            (Tensor.name b tensor)
          in
          let ty = TensorType.to_string (Tensor.type_ b tensor) in
          let shape = Rt.Option.fold
            ~none:"[]"
            ~some:(fun v -> string_of_int_array b v)
            (Tensor.shape b tensor)
          in
          Printf.printf "    [%d] %-40s %-12s %s\n" t_i name ty shape
        done
      ) (SubGraph.tensors b sg)
    done
  ) (Model.subgraphs b model)

let () =
  if Array.length Sys.argv < 2 then (
    Printf.eprintf "Usage: tfview <model.tflite>\n";
    exit 1
  );
  print_model Sys.argv.(1)
