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
