#include "stdafx.h"

#include "manager.h"

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "GpuHostData.h"

#include "KernelStride.hpp"

#include "tools.hpp"

#include <thread>
static std::thread save_thread;

int ProcessKeysInterval(uint16_t cu_dev_id, uint16_t cu_grid, uint16_t cu_block, uint16_t loops_num, const char* msg_file_path, const char* solution_tag, const char* keys_file_path, uint16_t keys_num, uint64_t index_begin, uint64_t index_interval, const char* log_folder)
{
    cudaError_t cudaStatus = cudaSuccess;
    std::string log_name = std::string(log_folder) + "/" + std::to_string(0) + ".log";
    uint64_t phrases_in_round_gpu = loops_num * cu_block * cu_grid;
    uint64_t cuda_rounds_number = index_interval / phrases_in_round_gpu;
    if ((index_interval  % phrases_in_round_gpu ) != 0)
        cuda_rounds_number = cuda_rounds_number + 1;

    int solution_found_flag = 0;

    tools::logMessage("ID: "+std::to_string(cu_dev_id)+", grid: "+ std::to_string(cu_grid)+" , block: "+std::to_string(cu_block)+ " , loops: "+std::to_string(loops_num)+
    ", msg file: "  + msg_file_path + ", solution tag: "+solution_tag + ", keys number: " +  std::to_string(keys_num)+
    ", index begin: " + std::to_string(index_begin) + ", index interval: "+ std::to_string(index_interval), log_name);

    devicesInfo(log_name);

    cudaStatus = cudaSetDevice(cu_dev_id);
    if (cudaStatus != cudaSuccess) 
    {
        tools::logMessage("ERROR: cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?", log_name);
        return -1;
    }

    DataClass* Data = new DataClass(cu_grid, cu_block);
    KernelStrideClass* Stride = new KernelStrideClass(Data);

    if (Data->malloc(log_name) != 0) 
    {
        tools::logMessage("ERROR:  Data->Malloc()!", log_name);
        return -1;
    }
//---------------------------------
    Data->host.config->keys_num = keys_num;
    if ((Data->host.malloc_and_read_KEYS(keys_file_path, log_name) == -1) || !Data->host.config->keys)
    {
        tools::logMessage("ERROR:  Allocation failed for host keys array",log_name);
        return -1;
    }

    if (Data->host.malloc_and_set_SOLUTION_TAG(solution_tag, log_name)== -1)
    {
        tools::logMessage("ERROR:  Allocation failed for host keys array", log_name);
        return -1;
    }
    
    if (Data->host.malloc_and_read_MESSAGE(msg_file_path, log_name) == -1)
    {
        tools::logMessage("ERROR: 'message.b64' could not be read or decoded.", log_name); 
        return -1;
    }

    
    if (Data->dev.malloc_CONFIG(&Data->host, log_name) == -1)
    {
        tools::logMessage("ERROR: Allocation failed for device CONFIG(keys and message) array", log_name);
        return -1;
    }
    
    if (Stride->init(log_name) != 0) 
    {
        tools::logMessage("ERROR:  Stride->INIT!!", log_name);
        return -1;
    }
    Data->host.job->loops_num = loops_num;
    Data->host.job->index_end = index_begin + index_interval;

    tools::logMessage("Brute begun", log_name);
    for (uint64_t cuda_round = 0; cuda_round < cuda_rounds_number; cuda_round++)
    {
        Data->host.job->index_0 = index_begin + cuda_round * phrases_in_round_gpu;      
        tools::start_time();
        
        if (Stride->start(cu_grid, cu_block, log_name) != 0) 
        {
            tools::logMessage("ERROR:  Stride->START!!", log_name);
            return -1;
        }
        
        if (save_thread.joinable())
            save_thread.join();
            
        if (Stride->end(log_name) != 0) 
        {
            tools::logMessage("ERROR:  Stride->END!!", log_name);
            return -1;
        }
     
        float delay;
        tools::stop_time_and_calc_sec(&delay);
        tools::logMessage(std::to_string(cuda_round)+": "+std::string(tools::formatWithCommas( (uint64_t)((double)phrases_in_round_gpu/ delay) ) )+ " PHRASEs / SEC | "+
                          std::string(tools::formatWithCommas(((double)phrases_in_round_gpu / delay)/(cu_grid*cu_block)) )+ " PHRASEs/SEC per thread" , log_name); 
        
        if( Data->host.ret->found_flag == 1)
        {
            printf("%.*s\n",Data->host.ret->found_phrase_length ,Data->host.ret->found_phrase);
            solution_found_flag = 1;
            break;
        }    


        
    }

    tools::logMessage("Brute ended", log_name);
    if (save_thread.joinable()) 
        save_thread.join();


    // cudaDeviceReset must be called before exiting in order for profiling and
    // tracing tools such as Nsight and Visual Profiler to show complete traces.
    cudaStatus = cudaDeviceReset();
    if (cudaStatus != cudaSuccess) 
    {
        tools::logMessage("ERROR: cudaDeviceReset failed!", log_name);
        
        if (solution_found_flag == 1)
            return 1;
        
        return -1;
    }

//---------------------------------
    if (solution_found_flag == 1)
        return 1;
    else
        return 0;
}



void devicesInfo( std::string log_name )
{
    int deviceCount = 0;
    cudaGetDeviceCount(&deviceCount);

    if (deviceCount == 0)
        tools::logMessage("ERROR: There are no available device(s) that support CUDA", log_name);
    else
        tools::logMessage("Detected "+std::to_string(deviceCount)+" CUDA Capable device(s)", log_name);

    int dev;
    for (dev = 0; dev < deviceCount; ++dev)
    {
        cudaSetDevice(dev);
        cudaDeviceProp deviceProp;
        cudaGetDeviceProperties(&deviceProp, dev);

        tools::logMessage("Device "+std::to_string(dev)+": \""+deviceProp.name+"\"", log_name);

    }
}

