#include <nanobind/nanobind.h>

namespace nb = nanobind;

extern "C" void launch_hello();

NB_MODULE(_ctgrad_ext, m) {
    m.def("hello", &launch_hello, "Launches a hello-world CUDA kernel");
}
