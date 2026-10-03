#include <catch2/catch.hpp>

#include "calculator.h"

TEST_CASE("add sums two integers", "[add]") {
    REQUIRE(calculator::add(2, 3) == 5);
    REQUIRE(calculator::add(-2, 2) == 0);
}

TEST_CASE("divide", "[divide]") {
    SECTION("divides evenly") { REQUIRE(calculator::divide(10, 2) == 5); }
    SECTION("truncates toward zero") { REQUIRE(calculator::divide(7, 2) == 3); }
    SECTION("throws on zero denominator") {
        REQUIRE_THROWS_AS(calculator::divide(1, 0), std::invalid_argument);
    }
}

TEST_CASE("mean of a range", "[mean]") {
    const std::vector<int> values{1, 2, 3, 4};
    const double result = calculator::mean(values); // breakpoint target
    REQUIRE_THAT(result, Catch::Matchers::WithinAbs(2.5, 1e-9));
}

// Fails on purpose, so neotest's failure status and diagnostics can be checked.
TEST_CASE("deliberately failing", "[demo]") {
    const int result = calculator::add(2, 2);
    CHECK(result == 5);
}
