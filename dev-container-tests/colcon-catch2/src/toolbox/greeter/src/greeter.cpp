#include "greeter.h"

namespace greeter {

std::string greet(const Clock &clock, const std::string &name) {
    const int hour = clock.hour();
    const char *part = hour < 12   ? "Good morning"
                       : hour < 18 ? "Good afternoon"
                                   : "Good evening";
    return std::string(part) + ", " + name + "!";
}

} // namespace greeter
