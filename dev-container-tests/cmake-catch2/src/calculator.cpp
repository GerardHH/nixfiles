#include "calculator.h"

#include <numeric>

namespace calculator {

int add(int lhs, int rhs) { return lhs + rhs; }

int divide(int numerator, int denominator) {
  if (denominator == 0) {
    throw std::invalid_argument("division by zero");
  }
  return numerator / denominator;
}

double mean(const std::vector<int> &values) {
  if (values.empty()) {
    throw std::invalid_argument("mean of empty range");
  }
  const int sum = std::accumulate(values.begin(), values.end(), 0);
  return static_cast<double>(sum) / static_cast<double>(values.size());
}

} // namespace calculator
