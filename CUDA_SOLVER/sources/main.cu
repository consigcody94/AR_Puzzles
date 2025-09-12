#include "stdafx.h"

#include <stdio.h>
#include <getopt.h>

#include <stdint.h>
#include <string.h>

#include "manager.h"

void print_usage(char *prog_name)
{
    fprintf(stderr, "Usage example: %s --cuda_device_id=0 --cuda_grid=256 --cuda_block=1024 --loops_num=128 --msg_file=\"/path/to/msg_file\" --solution_tag={\"version\" --keys_file=\"/path/to/keys_file\" --keys_num=8 --index_begin=1024 --index_interval=2048 --log_folder=\"/path/to/log_folder\" \n", prog_name);
}

struct key parse_line(const char* line);
void free_key(struct key* k);

int main(int argc, char *argv[])
{
    uint16_t    cu_dev_id      = 0;
    uint16_t    cu_grid        = 0;
    uint16_t    cu_block       = 0;
      
    uint16_t    loops_num      = 0;  
      
    const char* msg_file_path;
    const char* solution_tag;
    
    const char* keys_file_path;
    
    uint16_t    keys_num       = 0;

    uint64_t    index_begin    = 0;      
    uint64_t    index_interval = 0;  

    const char* log_folder;

    bool cuda_device_id_set = false;
    bool cuda_grid_set      = false;
    bool cuda_block_set     = false;
    bool loops_num_set      = false;
    bool msg_file_set       = false;
    bool solution_tag_set   = false;
    bool keys_file_set      = false;
    bool keys_num_set       = false;
    bool index_begin_set    = false;
    bool index_interval_set = false;
    bool log_folder_set     = false;

    // Long options for command-line parsing
    struct option long_options[] = {
        {"cuda_device_id",required_argument, 0, 0},
        {"cuda_grid",     required_argument, 0, 0},
        {"cuda_block",    required_argument, 0, 0},
        {"loops_num",     required_argument, 0, 0},
        {"msg_file",      required_argument, 0, 0},
        {"solution_tag",  required_argument, 0, 0},
        {"keys_file",     required_argument, 0, 0},
        {"keys_num",      required_argument, 0, 0},
        {"index_begin",   required_argument, 0, 0},
        {"index_interval",required_argument, 0, 0},
        {"log_folder",    required_argument, 0, 0},
        {0, 0, 0, 0}
    };

    int option_index = 0;
    while (1) {
        int c = getopt_long(argc, argv, "", long_options, &option_index);
        if (c == -1)
            break; // End of options


        switch (c) 
        {
            case 0:
                if (     strcmp(long_options[option_index].name, "cuda_device_id" ) == 0){
                    cu_dev_id      = atoi(optarg);
                    cuda_device_id_set = true;}
                else if (strcmp(long_options[option_index].name, "cuda_grid"      ) == 0){
                    cu_grid        = atoi(optarg);
                    cuda_grid_set = true;}
                else if (strcmp(long_options[option_index].name, "cuda_block"     ) == 0){
                    cu_block       = atoi(optarg);
                    cuda_block_set = true;}
                else if (strcmp(long_options[option_index].name, "loops_num"      ) == 0){
                    loops_num      = atoi(optarg);              
                    loops_num_set = true;}      
                else if (strcmp(long_options[option_index].name, "msg_file"       ) == 0){
                    msg_file_path  = strdup(optarg);
                    msg_file_set = true;}                                      
                else if (strcmp(long_options[option_index].name, "solution_tag"   ) == 0){
                    solution_tag   = strdup(optarg);
                    solution_tag_set = true;}
                else if (strcmp(long_options[option_index].name, "keys_file"      ) == 0){
                    keys_file_path = strdup(optarg);
                    keys_file_set = true;}
                else if (strcmp(long_options[option_index].name, "keys_num"       ) == 0){
                    keys_num       = atol(optarg);
                    keys_num_set = true;}
                else if (strcmp(long_options[option_index].name, "index_begin"    ) == 0){
                    index_begin    = atol(optarg);
                    index_begin_set = true;}
                else if (strcmp(long_options[option_index].name, "index_interval" ) == 0){
                    index_interval = atol(optarg);
                    index_interval_set = true;}
                else if (strcmp(long_options[option_index].name, "log_folder"     ) == 0){
                    log_folder     = strdup(optarg); 
                    log_folder_set = true;}                         
                break;    
            default:
                print_usage(argv[0]);
                return 1;
        }
    }
    
    if (!cuda_device_id_set || !cuda_grid_set || !cuda_block_set || !loops_num_set ||
    !msg_file_set || !solution_tag_set || !keys_file_set || !keys_num_set ||
    !index_begin_set || !index_interval_set || !log_folder_set)
    {
        fprintf(stderr, "Error: missing required arguments.\n");
        print_usage(argv[0]);
        return 1;
    }
    
    if (keys_num <= 0) 
    {
        fprintf(stderr, "Invalid keys_number\n");
        return 1;
    }
    
    // add here different checks of given arguments if needed

    int exit_status = -1;
    
    exit_status = ProcessKeysInterval(cu_dev_id, cu_grid, cu_block, loops_num, msg_file_path, solution_tag, keys_file_path, keys_num, index_begin, index_interval, log_folder);
    
    return exit_status;
}




