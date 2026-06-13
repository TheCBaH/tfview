/* Hand-written C ABI shim over the ATen "core" C++ subset.
 *
 * ctypes binds C, but ATen/c10 are C++ (mangled symbols, non-POD by-value
 * types). Every function here is `extern "C"` and trades only in C scalars /
 * opaque pointers so it is callable from OCaml ctypes. Kept deliberately small
 * and grown one operation at a time. */
#ifndef ATEN_CORE_SHIM_H_
#define ATEN_CORE_SHIM_H_

#include <stddef.h>
#include <stdint.h>

/* Opaque owning handle to a heap-allocated at::Tensor.  Caller must atc_free
   it.  The underlying type is never exposed to C callers. */
struct atc_tensor_opaque;
typedef struct atc_tensor_opaque* atc_tensor;

/* Data type: integer codes matching c10::ScalarType. */
typedef int8_t atc_scalar_type;
#define ATC_DTYPE_BYTE   ((atc_scalar_type)0)
#define ATC_DTYPE_CHAR   ((atc_scalar_type)1)
#define ATC_DTYPE_SHORT  ((atc_scalar_type)2)
#define ATC_DTYPE_INT    ((atc_scalar_type)3)
#define ATC_DTYPE_LONG   ((atc_scalar_type)4)
#define ATC_DTYPE_HALF   ((atc_scalar_type)5)
#define ATC_DTYPE_FLOAT  ((atc_scalar_type)6)
#define ATC_DTYPE_DOUBLE ((atc_scalar_type)7)
#define ATC_DTYPE_BOOL   ((atc_scalar_type)11)

#ifdef __cplusplus
extern "C" {
#endif

/* The process-wide default dtype, as a c10::ScalarType enum value. */
int8_t atc_default_dtype(void);

/* Size in bytes of one element of the given c10::ScalarType. */
size_t atc_dtype_elem_size(int8_t scalar_type);

/* New uninitialized contiguous CPU tensor of the given shape and dtype. */
atc_tensor atc_new(const int64_t* sizes, size_t ndim, atc_scalar_type dtype);

/* Release a handle returned by atc_new / atc_add_float / atc_mul. */
void atc_free(atc_tensor t);

/* Number of elements. */
int64_t atc_numel(atc_tensor t);

/* Pointer to the contiguous float32 element buffer (read/write). */
float* atc_data_float(atc_tensor t);

/* Scalar op: set every element to v. */
void atc_fill_float(atc_tensor t, float v);

/* Elementwise a + b into a fresh tensor (shapes must match). */
atc_tensor atc_add_float(atc_tensor a, atc_tensor b);

/* Elementwise a * b into a fresh tensor (shapes must match). */
atc_tensor atc_mul(atc_tensor a, atc_tensor b);

#ifdef __cplusplus
}

/* C++ conversion helpers for use inside shim.cpp and generated wrappers. */
#include <ATen/core/Tensor.h>

inline at::Tensor* atc_to_ptr(atc_tensor t) {
  return reinterpret_cast<at::Tensor*>(t);
}
inline atc_tensor atc_from_ptr(at::Tensor* t) {
  return reinterpret_cast<atc_tensor>(t);
}
inline atc_tensor atc_wrap(at::Tensor t) {
  return atc_from_ptr(new at::Tensor(std::move(t)));
}
#endif

#endif /* ATEN_CORE_SHIM_H_ */
