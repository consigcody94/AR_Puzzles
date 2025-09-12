#include <stdio.h>
#include <cuda.h>
#include "stdafx.h"

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "GPU.h"
#include "GpuHostData.h"

#include "crypto_kernels.cuh"

__device__ 
uint8_t generation_and_validation_kernel(
    const uint8_t* pw, uint16_t pw_len,
    const uint8_t* salt, const uint8_t* ciphertext, size_t ciphertext_len,
    const uint8_t* solution_tag, uint16_t solution_tag_len,
    int sha_iterations, int kdf_iterations, int key_len_bytes, int iv_len_bytes)
{
    // --- PART 1: Key & IV Generation ---
    uint8_t local_pw[128];
    for(int i=0; i<pw_len; ++i) local_pw[i] = pw[i];

    char sha512_hex_output[129] = {0};
    iterative_sha512(local_pw, pw_len, sha512_hex_output, sha_iterations);
    
    uint8_t kdf_key_iv[144];
    int kdf_key_iv_len = 0;
    uint8_t md5_prev[16] = {0};
    bool has_prev = false;
    int total_bytes_needed = key_len_bytes + iv_len_bytes;

    while (kdf_key_iv_len < total_bytes_needed) 
    {
        uint8_t block[256];
        int block_len = 0;
        if (has_prev) for (int i = 0; i < 16; ++i) block[block_len++] = md5_prev[i];
        for (int i = 0; i < 128; ++i) block[block_len++] = (uint8_t)sha512_hex_output[i];
        for (int i = 0; i < 8; ++i) block[block_len++] = salt[i];

        md5_cuda(block, block_len, md5_prev);
        for (int i = 1; i < kdf_iterations; ++i) md5_cuda(md5_prev, 16, md5_prev);

        int copy_len = 16;
        if (kdf_key_iv_len + copy_len > total_bytes_needed) copy_len = total_bytes_needed - kdf_key_iv_len;
        for (int i = 0; i < copy_len; ++i) kdf_key_iv[kdf_key_iv_len + i] = md5_prev[i];
        
        kdf_key_iv_len += copy_len;
        has_prev = true;
    }

    uint8_t* generated_key = kdf_key_iv;
    uint8_t* generated_iv = kdf_key_iv + key_len_bytes;
    
    // --- PART 2: AES Decryption & Validation ---
    uint8_t round_key[240 * 4];
    uint8_t local_iv[AES_BLOCKLEN];
    uint8_t decrypted_buffer[4096]; 
    uint8_t aes_rounds = 38, aes_Nk = 32;

    KeyExpansion(round_key, generated_key, aes_rounds, aes_Nk);
    for(int i=0; i<AES_BLOCKLEN; ++i) local_iv[i] = generated_iv[i];
    for(size_t i=0; i<ciphertext_len; ++i) decrypted_buffer[i] = ciphertext[i];

    uint8_t storeNextIv[AES_BLOCKLEN];
    for (size_t i = 0; i < ciphertext_len; i += AES_BLOCKLEN) {
        for(int j=0; j<AES_BLOCKLEN; ++j) storeNextIv[j] = decrypted_buffer[i+j];
        InvCipher((state_t*)(decrypted_buffer + i), round_key, aes_rounds);
        XorWithIv(decrypted_buffer + i, local_iv);
        for(int j=0; j<AES_BLOCKLEN; ++j) local_iv[j] = storeNextIv[j];
    }

    for (size_t i = 0; i + (solution_tag_len-1) <= ciphertext_len; ++i) 
    {
        bool match = true;
        for(int j=0; j<(solution_tag_len-1); ++j) 
            if (decrypted_buffer[i+j] != solution_tag[j]) 
            {
                match = false; 
                break; 
            }
        if (match) 
            return 1;
    }
    
    return 0;
}

__device__
uint16_t index_to_keys_phrase( uint64_t index, const bruteConfigStruct* __restrict__ config,  uint64_t digitsWeights[MAX_KEYS_NUMBER-1], uint8_t* keys_phrase)
{
    int16_t indices[MAX_KEYS_NUMBER] = {0};
    for(int i = 0; i< (config->keys_num)-1; i++)
    {
        indices[i] = index / digitsWeights[i];
        index      = index - indices[i] * digitsWeights[i];   
    }
    indices[(config->keys_num)-1] = index;


    uint16_t keys_phrase_length = 0;
    for (int i = 0; i < (config->keys_num); i++) 
        for (int j = 0; j < config->keys[i].words_lengths[indices[i]]; j++) 
        {
            keys_phrase[keys_phrase_length] = config->keys[i].words_pool[config->keys[i].words_positions[indices[i]] + j];
            keys_phrase_length++;
        }
    
    return keys_phrase_length;
}
  
    
__global__ void gl_bruteforce_AR(
    const bruteConfigStruct* __restrict__ config,
    const bruteJOBStruct* __restrict__ job,
    retStruct* __restrict__ ret
)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    
    uint8_t keys_phrase[MAX_PHRASE_SIZE] = { 0 };
    uint16_t keys_phrase_length = 0;
    
    uint8_t res = 0;

    uint64_t working_keys_phrase_index = job->index_0 + idx* (job->loops_num);

    uint64_t digitsWeights[MAX_KEYS_NUMBER-1];    
    for(int i1 = 1; i1 < config->keys_num; i1++ )
    {
        digitsWeights[i1-1] = 1;
        for(int i2 = i1; i2 < config->keys_num; i2++)
            digitsWeights[i1-1] = digitsWeights[i1-1] * config->keys[i2].words_number;
    }

    for (uint64_t l = 0; l < (job->loops_num); l++)
        if ( ( (working_keys_phrase_index+l) <=  job->index_end)  && (ret->found_flag == 0) )
        {
            keys_phrase_length = index_to_keys_phrase(working_keys_phrase_index + l, config, digitsWeights, keys_phrase);
            
                
            res =  generation_and_validation_kernel(keys_phrase,  keys_phrase_length,
                                                    config->salt, config->ciphertext, config->ciphertext_size,
                                                    config->solution_tag, config->solution_tag_len,
                                                    11513, 10000, 128, 16);
            if (res == 1)
            {
                for (int i =0; i < keys_phrase_length; i++)
                    ret->found_phrase[i] = keys_phrase[i];
                ret->found_phrase_length = keys_phrase_length;
                ret->found_flag = 1;      
            }                                         
        }    

}
