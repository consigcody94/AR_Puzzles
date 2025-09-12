#ifndef tools_H   // include guard
#define tools_H

#include <string>
#include <vector>

namespace tools {
    void logMessage(std::string msg, std::string log_name);
	void start_time(void);
	void stop_time_and_calc_sec(float* delay);
	std::string formatWithCommas(double val);
	std::string formatWithCommas(uint64_t value);
	std::string formatPrefix(double val);
}

#endif
