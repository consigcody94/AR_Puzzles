#ifndef K_Stride_H   // include guard
#define K_Stride_H

#include "stdafx.h"
#include <stdint.h>

#include "GpuHostData.h"


class KernelStrideClass
{
public:
	DataClass* dt;

	KernelStrideClass(DataClass* data)
	{
		dt = data;
	}

	int init(std::string log_name);
	int start(uint64_t grid, uint64_t block, std::string log_name);
	int end(std::string log_name);
};

#endif
