cmake_minimum_required(VERSION 3.21)
project(calculator LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(calculator src/calculator.cpp)
target_include_directories(calculator PUBLIC src)

include(CTest)
if(BUILD_TESTING)
  add_subdirectory(test)
endif()
