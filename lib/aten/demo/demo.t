Step 2: build CPU tensors and run a real op from OCaml via the minimal
c10-based tensor runtime. Default dtype is Float (6, 4 bytes); a is 0..5,
b is filled with the scalar 10, and a+b is the elementwise sum.

  $ ./main.exe
  default dtype = 6, elem size = 4 bytes
  a = [0; 1; 2; 3; 4; 5]
  b = [10; 10; 10; 10; 10; 10]
  a+b = [10; 11; 12; 13; 14; 15]
