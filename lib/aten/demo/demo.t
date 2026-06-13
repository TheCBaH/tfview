Build CPU tensors and run add + mul ops from OCaml via the minimal c10-based
tensor runtime. Default dtype is Float (6, 4 bytes); a is 1..6, b is filled
with the scalar 3, a+b is the elementwise sum and a*b is the elementwise product.

e+=b exercises in-place add_ (e is 10..15, += b of 3 -> 13..18). relu/relu_
clamp negatives to 0. reshape exercises the SymInt[] path (2x3 -> 3x2, a
storage-sharing view); flatten collapses 2x3 -> 1D [6]; avg_pool2d is a real
compute kernel (1x1x4x4 of 1..16, 2x2 kernel -> the four block means
3.5/5.5/11.5/13.5).

  $ ./main.exe
  default dtype = 6, elem size = 4 bytes
  a [2x3] = [1; 2; 3; 4; 5; 6]
  b [2x3] = [3; 3; 3; 3; 3; 3]
  a+b [2x3] = [4; 5; 6; 7; 8; 9]
  a*b [2x3] = [3; 6; 9; 12; 15; 18]
  e+=b [2x3] = [13; 14; 15; 16; 17; 18]
  relu g [2x3] = [0; 0; 0; 1; 2; 3]
  relu_ h [2x3] = [0; 0; 0; 0; 1; 2]
  reshape a [2x3] -> [3x2] = [1; 2; 3; 4; 5; 6]
  flatten a [2x3] -> [6] = [1; 2; 3; 4; 5; 6]
  avg_pool2d [1x1x4x4] kernel [2x2] -> [1x1x2x2] = [3.5; 5.5; 11.5; 13.5]
