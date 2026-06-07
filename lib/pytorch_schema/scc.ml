(** Tarjan's strongly connected components algorithm (generic functor).
    [run ~succ nodes] returns SCCs in topological order (leaves first: no
    outgoing edges to later SCCs). [succ v] must return only nodes present in
    [nodes]. *)
module Make (Ord : Map.OrderedType) = struct
  module Map = Map.Make (Ord)
  module Set = Set.Make (Ord)

  type state = {
    index : int Map.t;
    lowlink : int Map.t;
    on_stack : Set.t;
    stack : Ord.t list;
    counter : int;
    sccs : Ord.t list list;
  }

  let run ~(succ : Ord.t -> Ord.t list) (nodes : Ord.t list) : Ord.t list list =
    let init =
      {
        index = Map.empty;
        lowlink = Map.empty;
        on_stack = Set.empty;
        stack = [];
        counter = 0;
        sccs = [];
      }
    in
    let rec visit s v =
      let idx = s.counter in
      let s =
        {
          s with
          index = Map.add v idx s.index;
          lowlink = Map.add v idx s.lowlink;
          counter = idx + 1;
          stack = v :: s.stack;
          on_stack = Set.add v s.on_stack;
        }
      in
      let s =
        List.fold_left
          (fun s w ->
            if not (Map.mem w s.index) then
              let s = visit s w in
              let lv = Map.find v s.lowlink in
              let lw = Map.find w s.lowlink in
              { s with lowlink = Map.add v (min lv lw) s.lowlink }
            else if Set.mem w s.on_stack then
              let lv = Map.find v s.lowlink in
              let iw = Map.find w s.index in
              { s with lowlink = Map.add v (min lv iw) s.lowlink }
            else s)
          s (succ v)
      in
      if Map.find v s.lowlink = Map.find v s.index then
        let rec pop s acc =
          match s.stack with
          | [] -> (s, acc)
          | w :: rest ->
              let s =
                { s with stack = rest; on_stack = Set.remove w s.on_stack }
              in
              let acc = w :: acc in
              if Ord.compare w v = 0 then (s, acc) else pop s acc
        in
        let s, scc = pop s [] in
        { s with sccs = scc :: s.sccs }
      else s
    in
    let s =
      List.fold_left
        (fun s v -> if not (Map.mem v s.index) then visit s v else s)
        init nodes
    in
    List.rev s.sccs
end
