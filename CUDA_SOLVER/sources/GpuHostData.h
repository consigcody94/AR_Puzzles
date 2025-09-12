#ifndef GPUhostDATA_H   // include guard
#define GPUhostDATA_H

#include "stdafx.h"

#include <stdint.h>
#include <string>
#include <iostream>
#include <chrono>
#include <thread>
#include <fstream>
#include <string>
#include <memory>
#include <sstream>
#include <iomanip>
#include <vector>
#include <map>
#include <omp.h>

#include <vector>       // std::vector
#include <iterator>     // std::istreambuf_iterator
#include <algorithm>    // std::remove
#include <cstdint>      // uint8_t
#include <cstring>   // for memcpy

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "tools.hpp"

#pragma pack(push, 1)
struct retStruct {
    uint8_t found_phrase[MAX_PHRASE_SIZE] = {0};
    uint16_t found_phrase_length          = 0;
    uint8_t found_flag                    = 0;
};
#pragma pack(pop)

#pragma pack(push, 1) 
struct bruteConfigStruct
{
    uint8_t* solution_tag;
    uint16_t solution_tag_len = 0;

    uint8_t* salt;
    uint32_t salt_size = 0;
    uint8_t* ciphertext;
    uint32_t ciphertext_size = 0;

    uint16_t keys_num       = 0;
    struct key* keys;
};
#pragma pack(pop) 

#pragma pack(push, 1) 
struct bruteJOBStruct
{
    uint16_t loops_num = 0;

    uint64_t index_0   = 0;
    uint64_t index_end = 0;
};
#pragma pack(pop) 

class host_buffers_class
{
public:
    bruteConfigStruct* config = NULL;
    bruteJOBStruct* job = NULL;
    retStruct* ret = NULL;

	size_t cuda_grid = 0;
	size_t cuda_block = 0;
    
    uint64_t memory_size = 0;
    
	host_buffers_class(size_t cuda_grid, size_t cuda_block)
	{
		this->cuda_grid = cuda_grid;
		this->cuda_block = cuda_block;
	}
	host_buffers_class()
	{
		this->cuda_grid = 0;
		this->cuda_block = 0;
	}

    int alignedMalloc(void** point, uint64_t size, uint64_t* all_ram_memory_size, std::string buff_name, std::string log_name)
    {
        int result = posix_memalign(point, 4096, size);
        if (NULL == *point) 
        { 
            //tools::logMessage("ERROR: _aligned_malloc ("+buff_name+") failed! Size: "+std::string(tools::formatWithCommas(size).data()), log_name);
            return 1; 
        }
        *all_ram_memory_size += size;
        return 0;
    }
    
    int mallocHost(void** point, uint64_t size, uint64_t* all_ram_memory_size, std::string buff_name, std::string log_name) 
    {
        if (cudaMallocHost(point, size) != cudaSuccess) {            
            //tools::logMessage("ERROR: cudaMallocHost ("+buff_name+") failed! Size: "+std::string(tools::formatWithCommas(size).data()), log_name);
            return -1;
        }
        *all_ram_memory_size += size;
        return 0;
    }
    
    int malloc(std::string log_name)
    {
        memory_size = 0;
        if (mallocHost((void**)&job, sizeof(bruteJOBStruct), &memory_size, "brute job",log_name) != 0) return -1;

        if (mallocHost((void**)&config, sizeof(bruteConfigStruct), &memory_size, "brute config",log_name) != 0) return -1;

        if (mallocHost((void**)&ret, sizeof(retStruct), &memory_size, "ret",log_name) != 0) return -1;
        //tools::logMessage("MALLOC ALL RAM MEMORY SIZE (HOST): "+ std::to_string((float)memory_size / (1024.0f * 1024.0f)) +" MB", log_name);
        return 0;
    }
 
    int malloc_and_set_SOLUTION_TAG(const char* solution_tag, std::string log_name)
    {
        config->solution_tag_len = strlen(solution_tag);
        
        if (mallocHost((void**)&(config->solution_tag), config->solution_tag_len, &memory_size, "solution tag", log_name) != 0)
            return -1;

        memcpy(config->solution_tag, solution_tag, config->solution_tag_len);
        return 0;
    }
    

    int malloc_and_read_MESSAGE(const char* msg_file_path, std::string log_name)
    {
        std::vector<uint8_t> salt;
        std::vector<uint8_t> ciphertext;
        
        std::ifstream infile(msg_file_path);
        if (!infile) 
            return false;
        std::string b64_data((std::istreambuf_iterator<char>(infile)), std::istreambuf_iterator<char>());
        infile.close();
        b64_data.erase(std::remove(b64_data.begin(), b64_data.end(), '\n'), b64_data.end());
        b64_data.erase(std::remove(b64_data.begin(), b64_data.end(), '\r'), b64_data.end());

        std::string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        std::vector<uint8_t> decoded;
        int val = 0, bits = 0;
        for (char c : b64_data) 
        {
            if (c == '=') break;
            auto pos = chars.find(c);
            if (pos == std::string::npos) continue;
            val = (val << 6) | pos;
            bits += 6;
            if (bits >= 8) 
            {
                bits -= 8;
                decoded.push_back(val >> bits);
            }
        }
        if (decoded.size() < 16 || std::string(decoded.begin(), decoded.begin() + 8) != "Salted__")
            return -1;
        salt.assign(decoded.begin() + 8, decoded.begin() + 16);
        ciphertext.assign(decoded.begin() + 16, decoded.end());
           
        if (mallocHost((void**)&(config->salt), salt.size(), &memory_size, "config->keys",log_name) != 0) 
            return -1;
        if (mallocHost((void**)&(config->ciphertext), ciphertext.size(), &memory_size, "config->keys",log_name) != 0) 
            return -1;
            
        memcpy(config->salt, salt.data(), salt.size());
        memcpy(config->ciphertext, ciphertext.data(), ciphertext.size());
        config->salt_size = salt.size();
        config->ciphertext_size = ciphertext.size();
               
        return 0;    
        
    }

    int malloc_and_read_KEYS(const char* keys_file_path, std::string log_name)
    {
        //config->keys = (struct key*)malloc(sizeof(struct key) * config->keys_num);
        if (mallocHost((void**)&(config->keys),sizeof(struct key) * (config->keys_num), &memory_size, "config->keys",log_name) != 0) return -1;
        
        FILE* f = fopen(keys_file_path, "r");
        if (!f) 
        {
            perror("fopen");
            return -1;
        }

        char* line = NULL;
        size_t len = 0;
        ssize_t nread;
        int line_index = 0;

        while ((nread = getline(&line, &len, f)) != -1 && line_index < config->keys_num) 
        {
            // Strip newline if present
            if (nread > 0 && line[nread - 1] == '\n')
                line[nread - 1] = '\0';

            //config->keys[line_index] = parse_line(line);
            if (parse_line(line, &(config->keys[line_index]), log_name) == -1)
            {
                fclose(f);
                free(line);
                return -1;
            }
            line_index++;
        }
        
        fclose(f);
        free(line);
        
        return 0;
    }
    
    int parse_line(const char* line, struct key* k, std::string log_name) 
    {

        // 1. Count words
        k->words_number = 1;
        for (const char* p = line; *p; p++) 
        {
            if (*p == ',') k->words_number++;
        }

        // 2. Allocate arrays
        //k.words_lengths   = (uint64_t*)malloc(sizeof(uint64_t) * k.words_number);
        if (mallocHost((void**)&(k->words_lengths),sizeof(uint64_t) * k->words_number, &memory_size, "config->keys[i].words_lengths",log_name) != 0) return -1;
        //k.words_positions = (uint64_t*)malloc(sizeof(uint64_t) * k.words_number);
        if (mallocHost((void**)&(k->words_positions),sizeof(uint64_t) * k->words_number, &memory_size, "config->keys[i].words_positions",log_name) != 0) return -1;
        
        if (!k->words_lengths || !k->words_positions) 
        {
            tools::logMessage("ERROR: Allocation failed", log_name);
            return -1;
        }

        // 3. Compute lengths and positions
        size_t total_len = 0;
        size_t word_idx = 0;
        const char* start = line;

        for (const char* p = line; ; p++) 
        {
            if (*p == ',' || *p == '\0') 
            {
                size_t len = p - start;
                k->words_lengths[word_idx]   = len;
                k->words_positions[word_idx] = total_len;
                total_len += len;
                word_idx++;
                if (*p == '\0') break;
                start = p + 1;
            }
        }

        k->words_pool_size = total_len;
        
        // 4. Allocate pool
        //k.words_pool = (uint8_t*)malloc(total_len);
        if (mallocHost((void**)&(k->words_pool),total_len, &memory_size, "config->keys[i].words_pool",log_name) != 0) return -1;
        if (!k->words_pool) 
        {
            tools::logMessage("ERROR: Allocation failed", log_name);
            return -1;
        }

        // 5. Copy words into pool
        word_idx = 0;
        start = line;
        for (const char* p = line; ; p++) 
        {
            if (*p == ',' || *p == '\0') 
            {
                size_t len = p - start;
                memcpy(k->words_pool + k->words_positions[word_idx], start, len);
                word_idx++;
                if (*p == '\0') break;
                start = p + 1;
            }
        }

        return 0;
    }

    ~host_buffers_class()
    {
    
        cudaFreeHost(config->solution_tag);
        cudaFreeHost(config->salt);
        cudaFreeHost(config->ciphertext);
        
            // Free everything
        for (int i = 0; i < config->keys_num; i++)
        {
            cudaFreeHost(config->keys[i].words_lengths);
            cudaFreeHost(config->keys[i].words_positions);
            cudaFreeHost(config->keys[i].words_pool);
        }
        cudaFreeHost(config->keys);    
    
        cudaFreeHost(config);
        
        cudaFreeHost(job);
        cudaFreeHost(ret);
    }
};






class device_buffers_class
{
public:
    bruteConfigStruct* config = NULL;
    bruteJOBStruct* job = NULL;
    retStruct* ret = NULL;

    key* host_keys_dev = nullptr;         // host-side array with device pointers
    key* device_keys = nullptr;           // device memory for keys array (structs themselves)
 
    // Just a buffer to properly keep config fields pointers onto device memory
    bruteConfigStruct temp_config;
 
    uint16_t num_keys = 0;

	size_t cuda_grid = 0;
	size_t cuda_block = 0;

    uint64_t memory_size = 0;

	device_buffers_class(size_t cuda_grid, size_t cuda_block)
	{
		this->cuda_grid = cuda_grid;
		this->cuda_block = cuda_block;
	}
	device_buffers_class()
	{
		this->cuda_grid = 0;
		this->cuda_block = 0;
	}

    int cudaMallocDevice(void** point, uint64_t size, uint64_t* all_gpu_memory_size, std::string buff_name,std::string log_name) 
    {

        if (cudaMalloc(point, size) != cudaSuccess) 
        {
            //tools::logMessage("ERROR: cudaMalloc ("+buff_name+") failed! Size: "+std::string(tools::formatWithCommas(size).data()), log_name);
            tools::logMessage("ERROR: cudaMalloc ("+buff_name+") failed! Size: "+std::to_string(size), log_name);
            return -1;
        }
        *all_gpu_memory_size += size;
        
        return 0;
    }
    int malloc(std::string log_name)
    {
        memory_size = 0;    
        if (cudaMallocDevice((void**)&job, sizeof(bruteJOBStruct), &memory_size, "brute job", log_name) != 0) return -1;
        if (cudaMallocDevice((void**)&config, sizeof(bruteConfigStruct), &memory_size, "brute config", log_name) != 0) return -1;
        if (cudaMallocDevice((void**)&ret, sizeof(retStruct), &memory_size, "ret", log_name) != 0) return -1;
        
        //tools::logMessage("MALLOC ALL RAM MEMORY SIZE (GPU): "+ std::to_string((float)memory_size / (1024.0f * 1024.0f)) +" MB", log_name);
        return 0;
    }


    int malloc_CONFIG(host_buffers_class* host, std::string log_name)
    {
        num_keys = host->config->keys_num;

        // Allocate host-side mirror array of keys
        host_keys_dev = new key[num_keys];

        // Allocate device array for keys structs
        if (cudaMallocDevice((void**)&device_keys, sizeof(key) * num_keys, &memory_size, "device_keys", log_name) != 0) return -1;

        // Allocate nested arrays for each key and copy data
        for (size_t i = 0; i < num_keys; i++)
        {
            host_keys_dev[i] = host->config->keys[i]; // copy host key struct

            // Allocate nested arrays on device
            if (cudaMallocDevice((void**)&host_keys_dev[i].words_lengths,
                                 sizeof(uint64_t) * host->config->keys[i].words_number,
                                 &memory_size, "words_lengths", log_name) != 0) return -1;

            if (cudaMallocDevice((void**)&host_keys_dev[i].words_positions,
                                 sizeof(uint64_t) * host->config->keys[i].words_number,
                                 &memory_size, "words_positions", log_name) != 0) return -1;

            if (cudaMallocDevice((void**)&host_keys_dev[i].words_pool,
                                 host->config->keys[i].words_pool_size,
                                 &memory_size, "words_pool", log_name) != 0) return -1;

            // Copy inner arrays from host to device
            cudaMemcpy(host_keys_dev[i].words_lengths, host->config->keys[i].words_lengths,
                       sizeof(uint64_t) * host->config->keys[i].words_number, cudaMemcpyHostToDevice);
            cudaMemcpy(host_keys_dev[i].words_positions, host->config->keys[i].words_positions,
                       sizeof(uint64_t) * host->config->keys[i].words_number, cudaMemcpyHostToDevice);
            cudaMemcpy(host_keys_dev[i].words_pool, host->config->keys[i].words_pool,
                       host->config->keys[i].words_pool_size, cudaMemcpyHostToDevice);
        }

        // Copy host_keys_dev to device_keys on GPU
        cudaMemcpy(device_keys, host_keys_dev, sizeof(key) * num_keys, cudaMemcpyHostToDevice);

        // Copy pointer and keys_num into device config struct
       
        temp_config.keys_num = num_keys;
        temp_config.keys = device_keys;
        
        temp_config.solution_tag_len = host->config->solution_tag_len;
        temp_config.salt_size = host->config->salt_size;
        temp_config.ciphertext_size = host->config->ciphertext_size;

        if (cudaMallocDevice((void**)&temp_config.solution_tag,
                              host->config->solution_tag_len,
                             &memory_size, "solution tag", log_name) != 0) return -1; 
        if (cudaMallocDevice((void**)&temp_config.salt,
                              host->config->salt_size,
                             &memory_size, "salt", log_name) != 0) return -1;
        if (cudaMallocDevice((void**)&temp_config.ciphertext,
                              host->config->ciphertext_size,
                             &memory_size, "ciphertext", log_name) != 0) return -1;   
 
        cudaMemcpy(temp_config.solution_tag, host->config->solution_tag,
                       host->config->solution_tag_len, cudaMemcpyHostToDevice);                                                                 
        cudaMemcpy(temp_config.salt, host->config->salt,
                       host->config->salt_size, cudaMemcpyHostToDevice);
        cudaMemcpy(temp_config.ciphertext, host->config->ciphertext,
                       host->config->ciphertext_size, cudaMemcpyHostToDevice);
                                              
        // Copy to device memory pointed by config
        cudaMemcpy(config, &temp_config, sizeof(bruteConfigStruct), cudaMemcpyHostToDevice);

        return 0;
    }

    ~device_buffers_class()
    {
        // Free nested arrays using host mirror
        if (host_keys_dev)
        {
            for (size_t i = 0; i < num_keys; i++)
            {
                cudaFree(host_keys_dev[i].words_lengths);
                cudaFree(host_keys_dev[i].words_positions);
                cudaFree(host_keys_dev[i].words_pool);
            }
            delete[] host_keys_dev;
        }

       cudaFree(temp_config.solution_tag);
       cudaFree(temp_config.salt);
       cudaFree(temp_config.ciphertext);
              
        // Free keys array and outer config struct
        cudaFree(device_keys);   // keys array on device
        cudaFree(config);        // config struct on device

        cudaFree(job);
        cudaFree(ret);
    }
};


class DataClass
{
	public:
	
	host_buffers_class host;
	device_buffers_class dev;

	cudaStream_t stream1 = NULL;
	
	size_t cuda_grid = 0;
	size_t cuda_block = 0;
	
	public:
	DataClass(size_t cuda_grid, size_t cuda_block) : dev(cuda_grid, cuda_block), host(cuda_grid, cuda_block)
	{
	    this->cuda_grid = cuda_grid;
	    this->cuda_block = cuda_block;
	}

	int malloc(std::string log_name)
	{
 	
		if (cudaStreamCreate(&stream1) != cudaSuccess) 
		{
		    //tools::logMessage("ERROR: cudaStreamCreate failed!  stream1", log_name); 
		    return -1; 
		}
 		
		if (dev.malloc(log_name) != 0) 
		    return -1;
	 
		if (host.malloc(log_name) != 0) 
		    return -1;
	 
		return 0;	 
	}
	
	~DataClass()
	{
		cudaStreamDestroy(stream1);
	}
};

#endif
