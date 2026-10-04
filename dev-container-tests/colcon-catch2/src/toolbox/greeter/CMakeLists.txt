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
    # neotest-testmate's GTest support.
    include(FetchContent)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.17.0
        GIT_SHALLOW TRUE)
    # Keep googletest's own headers and libraries out of this package's install space.
    set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googletest)

    # One executable per package, registered with CTest as a single test, like
    # the Catch2 packages. gmock_main provides main().
    add_executable(${PROJECT_NAME}_test test/${PROJECT_NAME}_test.cpp)
    target_link_libraries(${PROJECT_NAME}_test PRIVATE ${PROJECT_NAME} GTest::gmock_main)
    add_test(NAME ${PROJECT_NAME} COMMAND ${PROJECT_NAME}_test WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
endif()
