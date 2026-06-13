#include "ops.h"

#include <ATen/Functions.h>

extern "C" {

atc_tensor atc_add(atc_tensor a, atc_tensor b) {
  return atc_wrap(at::add(*atc_to_ptr(a), *atc_to_ptr(b)));
}

atc_tensor atc_mul(atc_tensor a, atc_tensor b) {
  return atc_wrap(at::mul(*atc_to_ptr(a), *atc_to_ptr(b)));
}

atc_tensor atc_reshape(atc_tensor t, const int64_t* shape, size_t ndim) {
  return atc_wrap(at::reshape(*atc_to_ptr(t), at::IntArrayRef(shape, ndim)));
}

atc_tensor atc_avg_pool2d(atc_tensor t, const int64_t* kernel, size_t klen) {
  return atc_wrap(at::avg_pool2d(*atc_to_ptr(t), at::IntArrayRef(kernel, klen)));
}

}  // extern "C"
