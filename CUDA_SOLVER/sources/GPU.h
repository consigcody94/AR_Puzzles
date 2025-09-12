#ifndef GPU_H
#define GPU_H

#include <stdint.h>

#include "GpuHostData.h"
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

__global__ void gl_bruteforce_AR(
    const bruteConfigStruct* __restrict__ config,
    const bruteJOBStruct* __restrict__ job,
    retStruct* __restrict__ ret
);

#endif // GPU_H
