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

#ifdef __cplusplus
extern "C" {
#endif

/* Step 0 (plumbing): trivial calls into c10 to prove OCaml -> C++ linkage. */

/* The process-wide default dtype, as a c10::ScalarType enum value. */
int8_t atc_default_dtype(void);

/* Size in bytes of one element of the given c10::ScalarType. */
size_t atc_dtype_elem_size(int8_t scalar_type);

/* Step 2: minimal CPU float32 tensor runtime built directly on c10
   (StorageImpl/TensorImpl, no dispatcher / native kernels). atc_tensor is an
   opaque owning handle (a heap at::Tensor*); the caller must atc_free it.
   Tensors are contiguous; data is a plain float buffer. */
struct atc_tensor_opaque;
typedef struct atc_tensor_opaque* atc_tensor;

/* New uninitialized CPU float tensor of the given contiguous shape. */
atc_tensor atc_new_float(const int64_t* sizes, size_t ndim);

/* Release a handle returned by atc_new_float / atc_add_float. */
void atc_free(atc_tensor t);

/* Number of elements. */
int64_t atc_numel(atc_tensor t);

/* Pointer to the contiguous element buffer (read/write from the caller). */
float* atc_data_float(atc_tensor t);

/* Scalar op: set every element to v. */
void atc_fill_float(atc_tensor t, float v);

/* Tensor op: elementwise a + b into a fresh tensor (shapes must match). */
atc_tensor atc_add_float(atc_tensor a, atc_tensor b);

#ifdef __cplusplus
}
#endif

#endif /* ATEN_CORE_SHIM_H_ */
