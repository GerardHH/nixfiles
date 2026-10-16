// Crashes on purpose, for the adapter's crash reporting
// (tests/unit/crash_spec.lua). GTest writes no report after a crash, so the
// adapter reads the results from the console output. The tests run in this
// order, and the run ends at Crash.Segfaults.
#include <gtest/gtest.h>

#include <csignal>
#include <iostream>
#include <stdexcept>

namespace {

TEST(Crash, PassesBefore) { EXPECT_EQ(1 + 1, 2); }

// Prints, then fails: the output holds both, and only the failure belongs in
// the test's message.
TEST(Crash, FailsBefore) {
    std::cout << "printed by the test" << std::endl;
    EXPECT_EQ(1 + 1, 3) << "a message";
}

TEST(Crash, ThrowsOutsideAnAssertion) {
    throw std::runtime_error("thrown outside an assertion");
}

// A failure before the crash, which the message keeps. raise rather than a bad
// pointer: a crash that no optimiser or allocator can turn into something else.
TEST(Crash, Segfaults) {
    EXPECT_TRUE(false) << "failed before the crash";
    std::raise(SIGSEGV);
}

TEST(Crash, NotRunAfter) { EXPECT_TRUE(true); }

} // namespace
