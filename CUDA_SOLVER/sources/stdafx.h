#ifndef STDafx_H   // include guard
#define STDafx_H

#include <cstddef>
#include <stdint.h>  // for uint64_t


#define MAX_PHRASE_SIZE (256)
#define MAX_KEYS_NUMBER (8)

struct key {
    uint64_t  words_number;
    uint64_t* words_lengths;
    uint64_t* words_positions;
    uint8_t*  words_pool;
    uint64_t  words_pool_size;
};


#endif // STDafx_H
