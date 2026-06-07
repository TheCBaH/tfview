Parse model_weights_config.json for all 17 models and print weight count and
the lexicographically first weight's key, path_name, and is_param flag.

  $ for name in \
  >   efficientnet_b0 efficientnet_b1 efficientnet_b2 efficientnet_b3 \
  >   efficientnet_b4 efficientnet_b5 efficientnet_b6 efficientnet_b7 \
  >   efficientnet_v2_l efficientnet_v2_m efficientnet_v2_s \
  >   mobilenet_v2 \
  >   resnet18 resnet34 resnet50 resnet101 resnet152; do
  >   ./parse_weights_config.exe "$name" "${name}_weights_config.json"
  > done
  efficientnet_b0: weights=360 first=classifier.1.bias path_name=weight_212 is_param=true
  efficientnet_b1: weights=508 first=classifier.1.bias path_name=weight_300 is_param=true
  efficientnet_b2: weights=508 first=classifier.1.bias path_name=weight_300 is_param=true
  efficientnet_b3: weights=574 first=classifier.1.bias path_name=weight_339 is_param=true
  efficientnet_b4: weights=706 first=classifier.1.bias path_name=weight_417 is_param=true
  efficientnet_b5: weights=854 first=classifier.1.bias path_name=weight_505 is_param=true
  efficientnet_b6: weights=986 first=classifier.1.bias path_name=weight_583 is_param=true
  efficientnet_b7: weights=1200 first=classifier.1.bias path_name=weight_710 is_param=true
  efficientnet_v2_l: weights=1548 first=classifier.1.bias path_name=weight_896 is_param=true
  efficientnet_v2_m: weights=1120 first=classifier.1.bias path_name=weight_648 is_param=true
  efficientnet_v2_s: weights=782 first=classifier.1.bias path_name=weight_451 is_param=true
  mobilenet_v2: weights=314 first=classifier.1.bias path_name=weight_157 is_param=true
  resnet18: weights=122 first=bn1.bias path_name=weight_2 is_param=true
  resnet34: weights=218 first=bn1.bias path_name=weight_2 is_param=true
  resnet50: weights=320 first=bn1.bias path_name=weight_2 is_param=true
  resnet101: weights=626 first=bn1.bias path_name=weight_2 is_param=true
  resnet152: weights=932 first=bn1.bias path_name=weight_2 is_param=true
