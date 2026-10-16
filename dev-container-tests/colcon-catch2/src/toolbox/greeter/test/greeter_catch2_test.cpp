// A Catch2 test that mocks with GMock. gmock.h comes before Catch2's header on
// purpose: the adapter has to take the file for Catch2 by any of its
// #includes, not for GTest by the first one.
#include <gmock/gmock.h>

#define CATCH_CONFIG_MAIN
#include <catch2/catch.hpp>

#include "greeter.h"

namespace {

using testing::NiceMock;
using testing::Return;

class MockClock : public greeter::Clock {
  public:
    MOCK_METHOD(int, hour, (), (const, override));
};

// Stubs only (ON_CALL): without GTest running the test, a broken EXPECT_CALL
// is printed but doesn't fail the Catch2 test case.
TEST_CASE("greet in the morning", "[greet]") {
    NiceMock<MockClock> clock;
    ON_CALL(clock, hour()).WillByDefault(Return(9));
    REQUIRE(greeter::greet(clock, "Ada") == "Good morning, Ada!");
}

TEST_CASE("greet in the evening", "[greet]") {
    NiceMock<MockClock> clock;
    ON_CALL(clock, hour()).WillByDefault(Return(20));
    REQUIRE(greeter::greet(clock, "Bob") == "Good evening, Bob!");
}

} // namespace
