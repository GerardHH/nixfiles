#include <catch2/catch.hpp>

#include "text.h"

TEST_CASE("split on a delimiter", "[split]") {
    const std::vector<std::string> expected{"a", "b", "c"};
    REQUIRE(text::split("a,b,c", ',') == expected);
}

TEST_CASE("split keeps empty fields, even at the ends", "[split]") {
    const std::vector<std::string> expected{"", "a", "", "b", ""};
    REQUIRE(text::split(",a,,b,", ',') == expected);
}

TEST_CASE("to_upper converts ASCII letters", "[to_upper]") {
    const std::string result =
        text::to_upper("Hello, World!"); // breakpoint target
    REQUIRE(result == "HELLO, WORLD!");
}

// The ">" lands unescaped in Catch2's XML report, which used to break the
// report parsing in neotest-testmate. Keeps that case in the test bed.
TEST_CASE("to_upper -> leaves digits alone", "[to_upper]") {
    REQUIRE(text::to_upper("a1") == "A1");
}
