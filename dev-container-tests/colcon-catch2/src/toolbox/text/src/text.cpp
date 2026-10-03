#include "text.h"

#include <algorithm>
#include <cctype>

namespace text {

std::vector<std::string> split(std::string_view input, char delimiter) {
    std::vector<std::string> fields;
    std::size_t start = 0;
    while (true) {
        const std::size_t end = input.find(delimiter, start);
        fields.emplace_back(input.substr(start, end - start));
        if (end == std::string_view::npos) {
            return fields;
        }
        start = end + 1;
    }
}

std::string to_upper(std::string_view input) {
    std::string result(input);
    std::transform(
        result.begin(), result.end(), result.begin(),
        [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
    return result;
}

} // namespace text
