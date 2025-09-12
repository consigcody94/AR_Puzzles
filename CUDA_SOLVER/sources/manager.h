#ifndef manager_H   // include guard
#define manager_H

#include <stdio.h>
#include <cstdint> 
#include <string>

#include <string>      // for std::string
#include <fstream>     // for std::ofstream
#include <ctime>       // for std::time, std::localtime, std::asctime
#include <cstring>     // for std::strlen
#include <cstdio>      // for printf

int ProcessKeysInterval(uint16_t cu_dev_id, uint16_t cu_grid, uint16_t cu_block, uint16_t loops_num, const char* msg_file_path, const char* solution_tag, const char* keys_file_path, uint16_t keys_num, uint64_t index_begin, uint64_t index_interval, const char* log_folder);

void devicesInfo( std::string log_name );

#endif
