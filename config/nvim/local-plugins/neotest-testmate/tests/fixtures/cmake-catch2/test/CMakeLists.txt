include(FetchContent)
FetchContent_Declare(
  Catch2
  GIT_REPOSITORY https://github.com/catchorg/Catch2.git
  GIT_TAG v3.8.1
  GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(Catch2)

list(APPEND CMAKE_MODULE_PATH ${catch2_SOURCE_DIR}/extras)
include(Catch)

add_executable(calculator_tests calculator_test.cpp)
target_link_libraries(calculator_tests PRIVATE calculator Catch2::Catch2WithMain)

catch_discover_tests(calculator_tests)

# Crashes on purpose, for the adapter's crash reporting (see crash_test.cpp).
# Left out of catch_discover_tests, so CTest doesn't run it.
add_executable(crash_tests crash_test.cpp)
target_link_libraries(crash_tests PRIVATE Catch2::Catch2WithMain)
