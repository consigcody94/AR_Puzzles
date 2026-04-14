#include "stdafx.h"
#include <stdio.h>
#include <stdint.h>

#include "KernelStride.hpp"
#include "GpuHostData.h"
#include "GPU.h"

#include "tools.hpp"

cudaError_t deviceSynchronize(std::string name_kernel, std::string log_name) {
    cudaError_t cudaStatus = cudaSuccess;
        // Check for any errors launching the kernel
    cudaStatus = cudaGetLastError();
    if (cudaStatus != cudaSuccess) 
    {
        tools::logMessage("ERROR: cudaGetLastError \"" +name_kernel+"\" launch failed: "+cudaGetErrorString(cudaStatus), log_name);
        return cudaStatus;
    }

    // cudaDeviceSynchronize waits for the kernel to finish, and returns
    // any errors encountered during the launch.
    cudaStatus = cudaDeviceSynchronize();
    if (cudaStatus != cudaSuccess) 
    {
        tools::logMessage("ERROR: cudaDeviceSynchronize \"" +name_kernel+"\" returned error code: \""+cudaGetErrorString(cudaStatus)+"\" after launching addKernel!", log_name);
        return cudaStatus;
    }
    return cudaStatus;
}


int KernelStrideClass::init(std::string log_name)
{

    for(int i = 0; i < (dt->host.config)->keys_num; i++)
    {

        if (cudaMemcpyAsync( dt->dev.host_keys_dev[i].words_lengths,   ((dt->host.config)->keys[i]).words_lengths,  sizeof(uint64_t) * ((dt->host.config)->keys[i]).words_number, cudaMemcpyHostToDevice, dt->stream1) != cudaSuccess) 
        {
            tools::logMessage("ERROR: cudaMemcpyAsync to ->dev.config->keys[]->words_lengths failed!", log_name);
            return -1; 
        }

        if (cudaMemcpyAsync( dt->dev.host_keys_dev[i].words_positions, ((dt->host.config)->keys[i]).words_positions, sizeof(uint64_t) * ((dt->host.config)->keys[i]).words_number, cudaMemcpyHostToDevice, dt->stream1) != cudaSuccess) 
        {
            tools::logMessage("ERROR: cudaMemcpyAsync to ->dev.config->keys[]->words_positions failed!", log_name);
            return -1; 
        }

        if (cudaMemcpyAsync( dt->dev.host_keys_dev[i].words_pool,      ((dt->host.config)->keys[i]).words_pool,      ((dt->host.config)->keys[i]).words_pool_size, cudaMemcpyHostToDevice, dt->stream1) != cudaSuccess) 
        {
            tools::logMessage("ERROR: cudaMemcpyAsync to ->dev.config->keys[]->words_pool failed!", log_name);
            return -1; 
        }
    }   

    if (deviceSynchronize("init", log_name) != cudaSuccess) return -1;

    return 0;
}

int KernelStrideClass::start(uint64_t grid, uint64_t block, std::string log_name)
{
    if (cudaMemcpyAsync(dt->dev.job, dt->host.job, sizeof(bruteJOBStruct), cudaMemcpyHostToDevice, dt->stream1) != cudaSuccess) 
    {
        tools::logMessage("ERROR: cudaMemcpyAsync to ->dev.job failed!", log_name);
        return -1; 
    }
    if (cudaMemsetAsync(dt->dev.ret, 0, sizeof(retStruct), dt->stream1) != cudaSuccess) 
    { 
        tools::logMessage("ERROR: cudaMemset ->dev.ret failed!", log_name);
        return -1; 
    }
        
    gl_bruteforce_AR << <(uint32_t)grid, (uint32_t)block, 0, dt->stream1 >> > (dt->dev.config, dt->dev.job, dt->dev.ret);

    return 0;
}

int KernelStrideClass::end(std::string log_name)
{
    cudaError_t cudaStatus = cudaSuccess;
    if (deviceSynchronize("end", log_name) != cudaSuccess)
        return -1; 
        
    cudaStatus = cudaMemcpy(dt->host.ret, dt->dev.ret, sizeof(retStruct), cudaMemcpyDeviceToHost);
    
    if (cudaStatus != cudaSuccess)
    {
        tools::logMessage("ERROR: cudaMemcpy dev->ret to host->ret failed!", log_name);
        return -1;
    }

    return 0;
}

