// Includes only <gmock/gmock.h>, not <gtest/gtest.h>: the adapter has to
// recognise GTest by either header.
#include <gmock/gmock.h>

#include <cstdint>

#include "greeter.h"

namespace {

using testing::NiceMock;
using testing::Return;

class MockClock : public greeter::Clock {
  public:
    MOCK_METHOD(int, hour, (), (const, override));
};

// TEST: runs with --gtest_filter=Greet.UsesTheName.
TEST(Greet, UsesTheName) {
    MockClock clock;
    EXPECT_CALL(clock, hour()).WillOnce(Return(9));
    EXPECT_EQ(greeter::greet(clock, "Ada"), "Good morning, Ada!");
}

// TEST_F: a fixture, filtered the same way as TEST.
class GreetEvening : public testing::Test {
  protected:
    void SetUp() override { ON_CALL(clock, hour()).WillByDefault(Return(20)); }

    NiceMock<MockClock> clock;
};

TEST_F(GreetEvening, SaysGoodEvening) {
    EXPECT_EQ(greeter::greet(clock, "Bob"), "Good evening, Bob!");
}

// TEST_P: one test per value, named Hours/GreetAfternoon.CoversEachHour/0 to
// /2 by index, not by value. neotest shows them as one test.
class GreetAfternoon : public testing::TestWithParam<int> {};

TEST_P(GreetAfternoon, CoversEachHour) {
    NiceMock<MockClock> clock;
    ON_CALL(clock, hour()).WillByDefault(Return(GetParam()));
    EXPECT_EQ(greeter::greet(clock, "Cy"), "Good afternoon, Cy!");
}

INSTANTIATE_TEST_SUITE_P(Hours, GreetAfternoon, testing::Values(12, 15, 17));

// TYPED_TEST: one test per type, in suites GreetTyped/0 and /1.
template <typename T> class GreetTyped : public testing::Test {};
using HourTypes = testing::Types<int, std::int64_t>;
TYPED_TEST_SUITE(GreetTyped, HourTypes);

TYPED_TEST(GreetTyped, AcceptsHourType) {
    const TypeParam hour = 23;
    NiceMock<MockClock> clock;
    ON_CALL(clock, hour()).WillByDefault(Return(static_cast<int>(hour)));
    EXPECT_EQ(greeter::greet(clock, "Di"), "Good evening, Di!");
}

// GTEST_SKIP: reported as skipped, not as passed.
TEST(Greet, SkipsItself) { GTEST_SKIP() << "nothing to check yet"; }

// Fails on purpose, twice: a multi-line EXPECT_EQ message, and an EXPECT_LT
// message with "<" in it, which the report holds in CDATA.
TEST(Greet, DeliberatelyFailing) {
    NiceMock<MockClock> clock;
    ON_CALL(clock, hour()).WillByDefault(Return(9));
    EXPECT_EQ(greeter::greet(clock, "Eve"), "Good evening, Eve!");
    EXPECT_LT(clock.hour(), 6);
}

} // namespace
