cmake_minimum_required(VERSION 3.21)
project(calculator LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(${PROJECT_NAME} src/${PROJECT_NAME}.cpp)
target_include_directories(${PROJECT_NAME} PUBLIC src)

include(CTest)
if(BUILD_TESTING)
    include(FetchContent)
    FetchContent_Declare(
        Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG v2.13.10
        GIT_SHALLOW TRUE)
    FetchContent_MakeAvailable(Catch2)

    # One executable per package, registered with CTest as a single test, so
    # CTest knows nothing about the test cases inside it.
    add_executable(${PROJECT_NAME}_test test/main.cpp test/${PROJECT_NAME}_test.cpp)
    target_link_libraries(${PROJECT_NAME}_test PRIVATE ${PROJECT_NAME} Catch2::Catch2)
    add_test(NAME ${PROJECT_NAME} COMMAND ${PROJECT_NAME}_test WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
endif()
