#include "shim.h"

#include <ATen/core/Tensor.h>
#include <c10/core/CPUAllocator.h>
#include <c10/core/DefaultDtype.h>
#include <c10/core/ScalarType.h>
#include <c10/core/StorageImpl.h>
#include <c10/core/TensorImpl.h>

namespace {

// Construct a contiguous CPU float tensor directly from c10 primitives -- the
// minimal path that avoids at::empty / the dispatcher / cpuinfo.
at::Tensor make_cpu_float(const int64_t* sizes, size_t ndim) {
  c10::IntArrayRef shape(sizes, ndim);
  int64_t numel = 1;
  for (size_t i = 0; i < ndim; ++i) numel *= sizes[i];
  auto storage = c10::make_intrusive<c10::StorageImpl>(
      c10::StorageImpl::use_byte_size_t(),
      static_cast<size_t>(numel) * sizeof(float), c10::GetCPUAllocator(),
      /*resizable=*/true);
  auto t = at::detail::make_tensor<c10::TensorImpl>(
      std::move(storage), c10::DispatchKeySet(c10::DispatchKey::CPU),
      c10::scalarTypeToTypeMeta(c10::ScalarType::Float));
  t.unsafeGetTensorImpl()->set_sizes_contiguous(shape);
  return t;
}

inline at::Tensor* handle(atc_tensor t) { return static_cast<at::Tensor*>(t); }

// Raw buffer via storage (not data_ptr<T>, which would pull TensorMethods/item).
inline float* buf(at::Tensor* t) {
  return static_cast<float*>(t->unsafeGetTensorImpl()->storage().mutable_data());
}

}  // namespace

extern "C" {

int8_t atc_default_dtype(void) {
  return static_cast<int8_t>(c10::get_default_dtype_as_scalartype());
}

size_t atc_dtype_elem_size(int8_t scalar_type) {
  return c10::elementSize(static_cast<c10::ScalarType>(scalar_type));
}

atc_tensor atc_new_float(const int64_t* sizes, size_t ndim) {
  return new at::Tensor(make_cpu_float(sizes, ndim));
}

void atc_free(atc_tensor t) { delete handle(t); }

int64_t atc_numel(atc_tensor t) { return handle(t)->numel(); }

float* atc_data_float(atc_tensor t) { return buf(handle(t)); }

void atc_fill_float(atc_tensor t, float v) {
  at::Tensor* a = handle(t);
  float* p = buf(a);
  int64_t n = a->numel();
  for (int64_t i = 0; i < n; ++i) p[i] = v;
}

atc_tensor atc_add_float(atc_tensor a, atc_tensor b) {
  at::Tensor* ta = handle(a);
  at::Tensor* tb = handle(b);
  auto* out = new at::Tensor(
      make_cpu_float(ta->sizes().data(), ta->sizes().size()));
  float* pa = buf(ta);
  float* pb = buf(tb);
  float* po = buf(out);
  int64_t n = ta->numel();
  for (int64_t i = 0; i < n; ++i) po[i] = pa[i] + pb[i];
  return out;
}

}  // extern "C"
