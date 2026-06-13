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

#ifdef __cplusplus
}
#endif

#endif /* ATEN_CORE_SHIM_H_ */
