#!/usr/bin/env bash
# Compile the ATen "core" subset PLUS the real CPU add/mul kernels (static
# dispatch) into a static archive libaten_core.a.
#
# Layers:
#   1. c10 core+util+mobile (recursive) + ATen/core    — metadata/type system
#   2. generated static-dispatch glue: Operators_* (::call -> at::cpu::X),
#      RegisterCPU_* / RegisterComposite* (at::cpu:: wrappers + structured
#      kernels), UfuncCPU_add / UfuncCPUKernel_add (the add ufunc + its stub)
#   3. native runtime the kernels need: TensorIterator, Parallel*, factories
#      (empty*/empty_like), shape (as_strided/select), conversions, BinaryOps
#      (+ BinaryOpsKernel/FillKernel = mul_stub/fill_stub) — the bounded closure
#   4. stubs.cpp — throwing leaves for the cold-path ops TensorIterator/structured
#      kernels reference straight-line but never run for dense float (Option A)
#   5. cpuinfo (built here via cmake) — ParallelNative needs it; bundled in
#
# Everything is compiled with -ffunction-sections -fdata-sections so the FINAL
# link (OCaml exe / dll) can --gc-sections away the unreached wrappers; the
# archive itself stays the bounded ~190-object set we actually compile.
# CPU kernels (cpu/*Kernel + UfuncCPUKernel + the native/ files that pull vec.h)
# are built scalar via -DCPU_CAPABILITY=DEFAULT -DCPU_CAPABILITY_DEFAULT.
#
#   $1 = path to the pytorch source root (the git submodule)
# Prereqs in cwd (produced by sibling rules): ./gen, ./inc
# Third-party submodules (must be checked out):
#   git submodule update --init third_party/fmt third_party/cpuinfo
# Output: ./libaten_core.a + ./dllaten_core.so
set -euo pipefail
PT=$(cd "$1" && pwd)

for need in "$PT/third_party/fmt/include/fmt/core.h" \
            "$PT/third_party/cpuinfo/include/cpuinfo.h" \
            "$PT/third_party/cpuinfo/CMakeLists.txt"; do
  if [ ! -f "$need" ]; then
    echo "ERROR: missing $need" >&2
    echo "Run: git submodule update --init third_party/fmt third_party/cpuinfo" >&2
    exit 1
  fi
done

INC=(-I"$PT" -I"$PT/aten/src" -Igen -Iinc
     -I"$PT/third_party/fmt/include" -I"$PT/third_party/cpuinfo/include")
FLAGS=(-std=c++17 -Os -fPIC -DFMT_HEADER_ONLY=1)
# Per-function/data sections so the FINAL link can --gc-sections away the unused
# op wrappers. Applied ONLY to the generated glue + native closure: the c10 /
# ATen-core objects are monolithic and always fully reached, so splitting them
# gains nothing and makes section-GC over the whole archive pathologically slow.
SECT=(-ffunction-sections -fdata-sections)
# Extra flags for the SIMD-capable kernels: scalar (DEFAULT) capability only.
CAP=(-DCPU_CAPABILITY=DEFAULT -DCPU_CAPABILITY_DEFAULT)

# --- source lists -----------------------------------------------------------

# layer 1: full c10 (core incl. core/impl, util, mobile) + ATen/core + the
# generated op-name list. Monolithic, always needed -> NO section splitting.
mapfile -t SRCS_CORE < <(
  find "$PT/c10/core" "$PT/c10/util" "$PT/c10/mobile" -name '*.cpp' ! -name '*test*'
  find "$PT/aten/src/ATen/core" -name '*.cpp' ! -name '*test*'
  echo gen/ATen/core/ATenOpList.cpp
)

# layer 2+3: static-dispatch glue + native runtime that does NOT pull vec.h.
# Section-split (SECT) so --gc-sections trims the unused wrappers. TensorMethods
# is here, not in core: under static dispatch every Tensor::method() routes
# directly to at::native::X, so its ~2600 methods must be GC-trimmable.
mapfile -t SRCS_GLUE < <(
  echo gen/ATen/core/TensorMethods.cpp
  for f in Operators_0 Operators_1 Operators_2 Operators_3 Operators_4 \
           RegisterCPU_0 RegisterCPU_1 RegisterCPU_2 RegisterCPU_3 \
           RegisterCompositeExplicitAutograd_0 \
           RegisterCompositeExplicitAutogradNonFunctional_0 \
           RegisterCompositeImplicitAutograd_0 \
           UfuncCPU_add; do
    echo "gen/ATen/$f.cpp"
  done
  for f in Context EmptyTensor ExpandUtils MemoryOverlap NamedTensorUtils \
           ParallelCommon ParallelNative ParallelThreadPoolNative \
           SequenceNumber record_function ScalarOps TensorUtils \
           TensorIterator DeviceAccelerator; do
    echo "$PT/aten/src/ATen/$f.cpp"
  done
  # avg_pool2d structured meta+impl (TORCH_META_FUNC/TORCH_IMPL_FUNC) and the
  # avg_pool2d_kernel DispatchStub declaration; no vec.h -> compiled here.
  echo "$PT/aten/src/ATen/native/AveragePool2d.cpp"
  echo "$PT/aten/src/ATen/cpu/FlushDenormal.cpp"
  echo "$PT/aten/src/ATen/quantized/QTensorImpl.cpp"
  echo "$PT/aten/src/ATen/native/sparse/SparseTensor.cpp"
  find "$PT/aten/src/ATen/detail" -name '*HooksInterface.cpp'
  echo stubs.cpp
  echo shim.cpp
  echo ops.cpp
)

# layer 2+3 WITH CPU_CAPABILITY (the add/mul ufunc + DispatchStub kernels, and
# the native/ files that include vec.h transitively). Also section-split.
mapfile -t SRCS_CAP < <(
  echo gen/ATen/UfuncCPUKernel_add.cpp
  for f in Fill Resize TypeProperties DispatchStub Scalar TensorCompare \
           TensorConversions TensorFactories TensorProperties TensorShape \
           BinaryOps; do
    echo "$PT/aten/src/ATen/native/$f.cpp"
  done
  echo "$PT/aten/src/ATen/native/cpu/BinaryOpsKernel.cpp"
  echo "$PT/aten/src/ATen/native/cpu/FillKernel.cpp"
  # REGISTER_DISPATCH(avg_pool2d_kernel, ...) — the vectorized pooling kernel.
  echo "$PT/aten/src/ATen/native/cpu/AvgPoolKernel.cpp"
)

# --- compile ----------------------------------------------------------------
rm -rf obj && mkdir -p obj
compile_list() {  # extra flags as args; source paths via stdin
  xargs -P"$(nproc)" -I{} \
    bash -c 'o="obj/$(echo "$1" | tr "/" _).o"; clang++ "${@:2}" -c "$1" -o "$o"' \
         _ {} "$@"
}
printf '%s\n' "${SRCS_CORE[@]}" | compile_list "${FLAGS[@]}" "${INC[@]}"
printf '%s\n' "${SRCS_GLUE[@]}" | compile_list "${FLAGS[@]}" "${SECT[@]}" "${INC[@]}"
printf '%s\n' "${SRCS_CAP[@]}"  | compile_list "${FLAGS[@]}" "${SECT[@]}" "${CAP[@]}" "${INC[@]}"

# --- cpuinfo (static, PIC) --------------------------------------------------
cmake -S "$PT/third_party/cpuinfo" -B cpuinfo-build \
  -DCPUINFO_LIBRARY_TYPE=static -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCPUINFO_BUILD_UNIT_TESTS=OFF -DCPUINFO_BUILD_MOCK_TESTS=OFF \
  -DCPUINFO_BUILD_BENCHMARKS=OFF -DCPUINFO_BUILD_TOOLS=OFF \
  -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build cpuinfo-build -j"$(nproc)" --target cpuinfo >/dev/null

# --- archive + shared lib ---------------------------------------------------
rm -f libaten_core.a dllaten_core.so
ar rcs libaten_core.a obj/*.o
# Fold cpuinfo in via an MRI script: ADDLIB copies ALL members, preserving the
# duplicate object names cpuinfo ships (src/cache.c and src/arm/cache.c both
# compile to cache.c.o) that a filesystem `ar x` would clobber.
ar -M <<EOF
OPEN libaten_core.a
ADDLIB cpuinfo-build/libcpuinfo.a
SAVE
END
EOF
# Shared variant for ctypes' bytecode/toplevel path (foreign_archives needs a
# dll<name>.so alongside lib<name>.a). --whole-archive so every symbol is
# present; --gc-sections (via the fast lld linker) trims the unreached op
# wrappers — GNU ld is pathologically slow at this over the generated objects.
clang++ -shared -o dllaten_core.so -fuse-ld=lld \
  -Wl,--whole-archive libaten_core.a -Wl,--no-whole-archive \
  -Wl,--gc-sections -lpthread
echo "built libaten_core.a + dllaten_core.so with $(ls obj/*.o | wc -l) objects (+ cpuinfo)"
