Parse the full exported resnet18 model (model.json) and print summary stats.

  $ cat > parse_model.ml << 'EOF'
  > #use "topfind";;
  > #require "jsont";;
  > #require "jsont.bytesrw";;
  > #use "schema_pytorch.ml";;
  > #use "model_test_utils.ml";;
  > let () =
  >   let json = In_channel.with_open_bin "model.json" In_channel.input_all in
  >   Format.printf "%a@."
  >     (Format.pp_print_result ~ok:pp_model ~error:Format.pp_print_string)
  >     (Jsont_bytesrw.decode_string ExportedProgram.jsont json)
  > EOF
  $ ocaml schema_runtime.cma parse_model.ml 2>/dev/null
  schema=8.14 nodes=69
    torch.ops.aten.conv2d.default: 20
    torch.ops.aten.batch_norm.default: 20
    torch.ops.aten.relu_.default: 17
    torch.ops.aten.add_.Tensor: 8
    torch.ops.aten.adaptive_avg_pool2d.default: 1
    torch.ops.aten.max_pool2d.default: 1
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
