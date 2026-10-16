cmake_minimum_required(VERSION 3.21)
project(greeter LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(${PROJECT_NAME} src/${PROJECT_NAME}.cpp)
target_include_directories(${PROJECT_NAME} PUBLIC src)

include(CTest)
if(BUILD_TESTING)
    # GTest and GMock, where the other packages use Catch2: the test bed for
    # neotest-testmate's GTest support. Catch2 too, for a Catch2 test that
    # mocks with GMock.
    include(FetchContent)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.17.0
        GIT_SHALLOW TRUE)
    # Keep googletest's own headers and libraries out of this package's install space.
    set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
    FetchContent_Declare(
        Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG v2.13.10
        GIT_SHALLOW TRUE)
    FetchContent_MakeAvailable(googletest Catch2)

    # One executable per package, registered with CTest as a single test, like
    # the Catch2 packages. gmock_main provides main().
    add_executable(${PROJECT_NAME}_test test/${PROJECT_NAME}_test.cpp)
    target_link_libraries(${PROJECT_NAME}_test PRIVATE ${PROJECT_NAME} GTest::gmock_main)
    add_test(NAME ${PROJECT_NAME} COMMAND ${PROJECT_NAME}_test WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

    # Catch2 with GMock's mocks, a second executable: gmock without _main, as
    # the test file's CATCH_CONFIG_MAIN provides main(). The adapter has to
    # tell the two apart by framework, though both include gmock.h.
    add_executable(${PROJECT_NAME}_catch2_test test/${PROJECT_NAME}_catch2_test.cpp)
    target_link_libraries(${PROJECT_NAME}_catch2_test PRIVATE ${PROJECT_NAME} GTest::gmock Catch2::Catch2)
    add_test(NAME ${PROJECT_NAME}_catch2 COMMAND ${PROJECT_NAME}_catch2_test WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

    # Crashes on purpose, for the adapter's crash reporting (see
    # test/greeter_crash_test.cpp). Not registered with CTest.
    add_executable(${PROJECT_NAME}_crash_test test/${PROJECT_NAME}_crash_test.cpp)
    target_link_libraries(${PROJECT_NAME}_crash_test PRIVATE GTest::gtest_main)
endif()
