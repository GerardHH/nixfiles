#pragma once

#include <string>
#include <string_view>
#include <vector>

namespace text {

std::vector<std::string> split(std::string_view input, char delimiter);
std::string to_upper(std::string_view input);

} // namespace text
