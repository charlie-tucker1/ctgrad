#include <cstdio>

__global__ void hello_kernel() {
    printf("Hello from thread %d, block %d on the RTX 5070!\n",
           threadIdx.x, blockIdx.x);
}

extern "C" void launch_hello() {
    hello_kernel<<<2, 4>>>();
    cudaDeviceSynchronize();
}
