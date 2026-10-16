#pragma once

#include <stdexcept>
#include <vector>

namespace calculator {

int add(int lhs, int rhs);
int divide(int numerator, int denominator);
double mean(const std::vector<int> &values);

} // namespace calculator
