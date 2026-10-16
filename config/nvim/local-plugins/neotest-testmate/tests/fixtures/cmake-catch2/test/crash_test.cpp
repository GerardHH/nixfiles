// Crashes on purpose, for the adapter's crash reporting
// (tests/unit/crash_spec.lua). The test cases run in this order, and the run
// ends at "segfaults". Same test cases as text_crash_test.cpp in the colcon
// fixture, for Catch2 v2.
#include <catch2/catch_test_macros.hpp>

#include <csignal>
#include <stdexcept>

namespace {
int throws() { throw std::runtime_error("thrown inside an assertion"); }
} // namespace

TEST_CASE("passes before the crash") { CHECK(1 + 1 == 2); }

// Catch2 reports this exception inside the assertion's <Expression>.
TEST_CASE("throws inside an assertion") { CHECK(throws() == 1); }

TEST_CASE("throws outside an assertion") {
    throw std::runtime_error("thrown outside an assertion");
}

// After an assertion, Catch2 reports the exception as an expression without
// type, at that assertion's line.
TEST_CASE("throws after an assertion") {
    CHECK(true); // last assertion before the exception
    throw std::runtime_error("thrown after an assertion");
}

// raise rather than a bad pointer: a crash that no optimiser or allocator can
// turn into something else. Catch2 reports it at the last assertion before it.
TEST_CASE("segfaults") {
    CHECK(true); // last assertion before the crash
    std::raise(SIGSEGV);
}

TEST_CASE("not run after the crash") { CHECK(true); }
