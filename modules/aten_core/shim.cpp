#include "shim.h"

#include <c10/core/DefaultDtype.h>
#include <c10/core/ScalarType.h>

extern "C" {

int8_t atc_default_dtype(void) {
  return static_cast<int8_t>(c10::get_default_dtype_as_scalartype());
}

size_t atc_dtype_elem_size(int8_t scalar_type) {
  return c10::elementSize(static_cast<c10::ScalarType>(scalar_type));
}

}  // extern "C"
