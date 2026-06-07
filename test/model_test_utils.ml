(* Shared utilities for model-parsing cram tests.
   #use this file after schema_pytorch.ml has been loaded. *)

let node_type_counts g =
  let tbl = Hashtbl.create 64 in
  List.iter
    (fun (node : Node_Type.t) ->
      let t = node.target in
      Hashtbl.replace tbl t (1 + try Hashtbl.find tbl t with Not_found -> 0))
    g.Graph_Type.nodes;
  Hashtbl.fold (fun k v acc -> (k, v) :: acc) tbl []
  |> List.sort (fun (_, a) (_, b) -> Int.compare b a)

let pp_model ppf prog =
  let g = prog.ExportedProgram.graph_module.GraphModule.graph in
  let sv = prog.ExportedProgram.schema_version in
  Format.fprintf ppf "schema=%d.%d nodes=%d" sv.SchemaVersion.major
    sv.SchemaVersion.minor
    (List.length g.Graph_Type.nodes);
  List.iter
    (fun (op, n) -> Format.fprintf ppf "@\n  %s: %d" op n)
    (node_type_counts g)
