#pragma once

#include <string>

namespace greeter {

// Where the hour comes from; an interface, so that tests can mock it.
class Clock {
  public:
    virtual ~Clock() = default;
    virtual int hour() const = 0;
};

std::string greet(const Clock &clock, const std::string &name);

} // namespace greeter
