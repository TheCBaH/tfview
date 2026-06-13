Binding-generator coverage over the full native_functions.yaml. The generator
is gated to a controlled type set; this records how many ops it can currently
emit and why the rest are skipped (the skip buckets are the roadmap for which
types/return-shapes to support next).

  $ ./aten_gen_coverage.exe native_functions.yaml
  total: 2650
  generated: 971
  skipped: 1679
  top skip reasons:
     656  out= variant
     477  unsupported return shape
      88  unsupported arg type: ScalarType?
      80  unsupported arg type: SymInt[]
      38  unsupported arg type: SymInt
      34  unsupported arg type: int?
      33  unsupported arg type: Dimname
      30  unsupported arg type: SymInt[2]
      25  unsupported arg type: Tensor[]
      24  unsupported arg type: Generator?
      24  unsupported arg type: str
      18  unsupported arg type: SymInt[3]
