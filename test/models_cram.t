Parse every exported model and print schema version, node count, and
op-type histogram sorted by frequency (high to low).

  $ cat > parse_models.ml << 'EOF'
  > #use "topfind";;
  > #require "jsont";;
  > #require "jsont.bytesrw";;
  > #use "schema_pytorch.ml";;
  > #use "model_test_utils.ml";;
  > let models = [
  >   "efficientnet_b0",  "efficientnet_b0_model.json";
  >   "efficientnet_b1",  "efficientnet_b1_model.json";
  >   "efficientnet_b2",  "efficientnet_b2_model.json";
  >   "efficientnet_b3",  "efficientnet_b3_model.json";
  >   "efficientnet_b4",  "efficientnet_b4_model.json";
  >   "efficientnet_b5",  "efficientnet_b5_model.json";
  >   "efficientnet_b6",  "efficientnet_b6_model.json";
  >   "efficientnet_b7",  "efficientnet_b7_model.json";
  >   "efficientnet_v2_l","efficientnet_v2_l_model.json";
  >   "efficientnet_v2_m","efficientnet_v2_m_model.json";
  >   "efficientnet_v2_s","efficientnet_v2_s_model.json";
  >   "mobilenet_v2",     "mobilenet_v2_model.json";
  >   "resnet18",         "resnet18_model.json";
  >   "resnet34",         "resnet34_model.json";
  >   "resnet50",         "resnet50_model.json";
  >   "resnet101",        "resnet101_model.json";
  >   "resnet152",        "resnet152_model.json";
  > ]
  > let () =
  >   List.iter (fun (name, file) ->
  >     let json = In_channel.with_open_bin file In_channel.input_all in
  >     Format.printf "%s: %a@." name
  >       (Format.pp_print_result ~ok:pp_model ~error:Format.pp_print_string)
  >       (Jsont_bytesrw.decode_string ExportedProgram.jsont json)
  >   ) models
  > EOF
  $ ocaml schema_runtime.cma parse_models.ml 2>/dev/null
  efficientnet_b0: schema=8.14 nodes=240
    torch.ops.aten.conv2d.default: 81
    torch.ops.aten.silu_.default: 49
    torch.ops.aten.batch_norm.default: 49
    torch.ops.aten.adaptive_avg_pool2d.default: 17
    torch.ops.aten.sigmoid.default: 16
    torch.ops.aten.mul.Tensor: 16
    torch.ops.aten.add_.Tensor: 9
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_b1: schema=8.14 nodes=342
    torch.ops.aten.conv2d.default: 115
    torch.ops.aten.silu_.default: 69
    torch.ops.aten.batch_norm.default: 69
    torch.ops.aten.adaptive_avg_pool2d.default: 24
    torch.ops.aten.sigmoid.default: 23
    torch.ops.aten.mul.Tensor: 23
    torch.ops.aten.add_.Tensor: 16
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_b2: schema=8.14 nodes=342
    torch.ops.aten.conv2d.default: 115
    torch.ops.aten.silu_.default: 69
    torch.ops.aten.batch_norm.default: 69
    torch.ops.aten.adaptive_avg_pool2d.default: 24
    torch.ops.aten.sigmoid.default: 23
    torch.ops.aten.mul.Tensor: 23
    torch.ops.aten.add_.Tensor: 16
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_b3: schema=8.14 nodes=387
    torch.ops.aten.conv2d.default: 130
    torch.ops.aten.silu_.default: 78
    torch.ops.aten.batch_norm.default: 78
    torch.ops.aten.adaptive_avg_pool2d.default: 27
    torch.ops.aten.sigmoid.default: 26
    torch.ops.aten.mul.Tensor: 26
    torch.ops.aten.add_.Tensor: 19
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_b4: schema=8.14 nodes=477
    torch.ops.aten.conv2d.default: 160
    torch.ops.aten.silu_.default: 96
    torch.ops.aten.batch_norm.default: 96
    torch.ops.aten.adaptive_avg_pool2d.default: 33
    torch.ops.aten.sigmoid.default: 32
    torch.ops.aten.mul.Tensor: 32
    torch.ops.aten.add_.Tensor: 25
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_b5: schema=8.14 nodes=579
    torch.ops.aten.conv2d.default: 194
    torch.ops.aten.silu_.default: 116
    torch.ops.aten.batch_norm.default: 116
    torch.ops.aten.adaptive_avg_pool2d.default: 40
    torch.ops.aten.sigmoid.default: 39
    torch.ops.aten.mul.Tensor: 39
    torch.ops.aten.add_.Tensor: 32
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_b6: schema=8.14 nodes=669
    torch.ops.aten.conv2d.default: 224
    torch.ops.aten.silu_.default: 134
    torch.ops.aten.batch_norm.default: 134
    torch.ops.aten.adaptive_avg_pool2d.default: 46
    torch.ops.aten.sigmoid.default: 45
    torch.ops.aten.mul.Tensor: 45
    torch.ops.aten.add_.Tensor: 38
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_b7: schema=8.14 nodes=816
    torch.ops.aten.conv2d.default: 273
    torch.ops.aten.silu_.default: 163
    torch.ops.aten.batch_norm.default: 163
    torch.ops.aten.adaptive_avg_pool2d.default: 56
    torch.ops.aten.sigmoid.default: 55
    torch.ops.aten.mul.Tensor: 55
    torch.ops.aten.add_.Tensor: 48
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_v2_l: schema=8.14 nodes=1019
    torch.ops.aten.conv2d.default: 339
    torch.ops.aten.batch_norm.default: 217
    torch.ops.aten.silu_.default: 203
    torch.ops.aten.add_.Tensor: 73
    torch.ops.aten.adaptive_avg_pool2d.default: 62
    torch.ops.aten.sigmoid.default: 61
    torch.ops.aten.mul.Tensor: 61
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_v2_m: schema=8.14 nodes=736
    torch.ops.aten.conv2d.default: 245
    torch.ops.aten.batch_norm.default: 157
    torch.ops.aten.silu_.default: 147
    torch.ops.aten.add_.Tensor: 51
    torch.ops.aten.adaptive_avg_pool2d.default: 45
    torch.ops.aten.sigmoid.default: 44
    torch.ops.aten.mul.Tensor: 44
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  efficientnet_v2_s: schema=8.14 nodes=511
    torch.ops.aten.conv2d.default: 170
    torch.ops.aten.batch_norm.default: 110
    torch.ops.aten.silu_.default: 102
    torch.ops.aten.add_.Tensor: 35
    torch.ops.aten.adaptive_avg_pool2d.default: 31
    torch.ops.aten.sigmoid.default: 30
    torch.ops.aten.mul.Tensor: 30
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout_.default: 1
  mobilenet_v2: schema=8.14 nodes=153
    torch.ops.aten.conv2d.default: 52
    torch.ops.aten.batch_norm.default: 52
    torch.ops.aten.hardtanh_.default: 35
    torch.ops.aten.add.Tensor: 10
    torch.ops.aten.adaptive_avg_pool2d.default: 1
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
    torch.ops.aten.dropout.default: 1
  resnet18: schema=8.14 nodes=69
    torch.ops.aten.conv2d.default: 20
    torch.ops.aten.batch_norm.default: 20
    torch.ops.aten.relu_.default: 17
    torch.ops.aten.add_.Tensor: 8
    torch.ops.aten.adaptive_avg_pool2d.default: 1
    torch.ops.aten.max_pool2d.default: 1
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
  resnet34: schema=8.14 nodes=125
    torch.ops.aten.conv2d.default: 36
    torch.ops.aten.batch_norm.default: 36
    torch.ops.aten.relu_.default: 33
    torch.ops.aten.add_.Tensor: 16
    torch.ops.aten.adaptive_avg_pool2d.default: 1
    torch.ops.aten.max_pool2d.default: 1
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
  resnet50: schema=8.14 nodes=175
    torch.ops.aten.conv2d.default: 53
    torch.ops.aten.batch_norm.default: 53
    torch.ops.aten.relu_.default: 49
    torch.ops.aten.add_.Tensor: 16
    torch.ops.aten.adaptive_avg_pool2d.default: 1
    torch.ops.aten.max_pool2d.default: 1
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
  resnet101: schema=8.14 nodes=345
    torch.ops.aten.conv2d.default: 104
    torch.ops.aten.batch_norm.default: 104
    torch.ops.aten.relu_.default: 100
    torch.ops.aten.add_.Tensor: 33
    torch.ops.aten.adaptive_avg_pool2d.default: 1
    torch.ops.aten.max_pool2d.default: 1
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
  resnet152: schema=8.14 nodes=515
    torch.ops.aten.conv2d.default: 155
    torch.ops.aten.batch_norm.default: 155
    torch.ops.aten.relu_.default: 151
    torch.ops.aten.add_.Tensor: 50
    torch.ops.aten.adaptive_avg_pool2d.default: 1
    torch.ops.aten.max_pool2d.default: 1
    torch.ops.aten.linear.default: 1
    torch.ops.aten.flatten.using_ints: 1
