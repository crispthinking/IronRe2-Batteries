cmake_minimum_required(VERSION 3.16)
project(cre2)

# Abseil requires C++14
set(CMAKE_CXX_STANDARD 14)

add_library(cre2 SHARED "${CMAKE_SOURCE_DIR}/thirdparty/cre2/src/cre2.cpp")

target_compile_definitions(cre2 PRIVATE 
    cre2_VERSION_INTERFACE_CURRENT=0
    cre2_VERSION_INTERFACE_REVISION=0
    cre2_VERSION_INTERFACE_AGE=0
    cre2_VERSION_INTERFACE_STRING="0.0.0"
)

set(BUILD_TESTING OFF)
set(BUILD_SHARED_LIBS OFF)
set(RE2_BUILD_TESTING OFF)

add_subdirectory("${CMAKE_SOURCE_DIR}/thirdparty/re2" re2)

# Import Abseil's CMake targets.
#find_package(absl REQUIRED)

target_link_libraries(cre2 PRIVATE re2)
