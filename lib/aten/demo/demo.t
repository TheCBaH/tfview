Build CPU tensors and run add + mul ops from OCaml via the minimal c10-based
tensor runtime. Default dtype is Float (6, 4 bytes); a is 1..6, b is filled
with the scalar 3, a+b is the elementwise sum and a*b is the elementwise product.

  $ ./main.exe
  default dtype = 6, elem size = 4 bytes
  a = [1; 2; 3; 4; 5; 6]
  b = [3; 3; 3; 3; 3; 3]
  a+b = [4; 5; 6; 7; 8; 9]
  a*b = [3; 6; 9; 12; 15; 18]
