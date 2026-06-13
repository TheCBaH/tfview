// Throwing stubs for ATen cold-path ops that TensorIterator / structured
// kernels reference UNCONDITIONALLY (straight-line, in error / type-check /
// quantized / sparse branches) but never execute for dense CPU float add/mul.
// Stubbing the leaf entry points lets --gc-sections drop the sparse /
// quantized / reduction / indexing machinery (and their SIMD DispatchStubs)
// behind them, keeping the static-dispatch archive bounded (Option A).
#include <ATen/core/Tensor.h>
#include <ATen/NativeFunctions.h>
#include <ATen/NativeMetaFunctions.h>
#include <ATen/core/operator_name.h>
#include <ATen/quantized/QTensorImpl.h>
#include <ATen/quantized/Quantizer.h>
#include <c10/util/Exception.h>

#define MINSTUB(name) \
  TORCH_CHECK(false, "ATen op '" name "' is not built in the minimal static-dispatch subset")

namespace at {
namespace native {

// --- layer 1: TensorIterator type-check / error-helper leaves ---
// (item / to_dense / coalesce / values_default / indices_default are provided
// by the real Scalar.cpp / TensorConversions.cpp / SparseTensor.cpp.)
bool is_nonzero(const at::Tensor&) { MINSTUB("is_nonzero"); }
at::Tensor dequantize_cpu_or_cuda(const at::Tensor&) { MINSTUB("dequantize"); }
at::Tensor& copy_(at::Tensor& self, const at::Tensor&, bool) { MINSTUB("copy_"); return self; }
at::Tensor sum(const at::Tensor&, std::optional<c10::ScalarType>) { MINSTUB("sum"); }
at::Tensor col_indices_default(const at::Tensor&) { MINSTUB("col_indices"); }
at::Tensor crow_indices_default(const at::Tensor&) { MINSTUB("crow_indices"); }
at::Tensor ccol_indices_default(const at::Tensor&) { MINSTUB("ccol_indices"); }
at::Tensor row_indices_default(const at::Tensor&) { MINSTUB("row_indices"); }

// --- layer 2: leaves pulled in by TensorFactories / TensorShape /
//     TensorConversions (output allocation + as_strided / select / to paths) ---
at::Tensor nonzero_cpu(const at::Tensor&) { MINSTUB("nonzero_cpu"); }
at::Tensor index_select_cpu_(const at::Tensor&, int64_t, const at::Tensor&) { MINSTUB("index_select_cpu_"); }
at::Tensor& arange_out(const at::Scalar&, const at::Scalar&, const at::Scalar&, at::Tensor& out) { MINSTUB("arange_out"); return out; }
at::Tensor sparse_compressed_tensor_with_dims(int64_t, int64_t, at::IntArrayRef, at::IntArrayRef, at::ScalarType, std::optional<at::ScalarType>, std::optional<at::Layout>, std::optional<at::Device>, std::optional<bool>) { MINSTUB("sparse_compressed_tensor_with_dims"); }
at::Tensor _sparse_compressed_tensor_unsafe_symint(const at::Tensor&, const at::Tensor&, const at::Tensor&, c10::SymIntArrayRef, std::optional<at::ScalarType>, std::optional<at::Layout>, std::optional<at::Device>, std::optional<bool>) { MINSTUB("_sparse_compressed_tensor_unsafe_symint"); }

// sum.IntList structured op (referenced by RegisterCPU's wrapper_CPU_sum)
void structured_sum_out::impl(const at::Tensor&, at::OptionalIntArrayRef, bool, std::optional<at::ScalarType>, const at::Tensor&) { MINSTUB("sum.impl"); }

}  // namespace native

namespace meta {
void structured_sum_dim_IntList::meta(const at::Tensor&, at::OptionalIntArrayRef, bool, std::optional<at::ScalarType>) { MINSTUB("sum.meta"); }
}  // namespace meta

// --- quantizer leaves (TensorShape's is_quantized() branch in as_strided) ---
// The QTensorImpl ctor + vtable come from the real (tiny) QTensorImpl.cpp; only
// the affine-quantizer factory leaves are stubbed (they never cascade).
QTensorImpl* get_qtensorimpl(const TensorBase&) { MINSTUB("get_qtensorimpl"); }
QuantizerPtr make_per_tensor_affine_quantizer(double, int64_t, ScalarType) { MINSTUB("make_per_tensor_affine_quantizer"); }
QuantizerPtr make_per_channel_affine_quantizer(const Tensor&, const Tensor&, int64_t, ScalarType) { MINSTUB("make_per_channel_affine_quantizer"); }
void set_quantizer_(const Tensor&, ConstQuantizerPtr) { MINSTUB("set_quantizer_"); }
QuantizerPtr TensorBase::quantizer() const { MINSTUB("quantizer"); }

}  // namespace at

// --- TORCH_LIBRARY schema parser (cold path in ATen/core/library.cpp; unused
//     under --skip-dispatcher-op-registration). core is not section-split, so
//     this straight-line ref must resolve. ---
namespace torch {
namespace jit {
c10::OperatorName parseName(const std::string&) { MINSTUB("parseName"); }
}  // namespace jit
}  // namespace torch
