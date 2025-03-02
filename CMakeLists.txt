cmake_minimum_required(VERSION 3.16)
project(cre2)

# Abseil requires C++17
set(CMAKE_CXX_STANDARD 17)

# Import Abseil's CMake targets first
find_package(absl CONFIG REQUIRED)

# Set RE2 configuration variables
set(BUILD_TESTING OFF)
set(BUILD_SHARED_LIBS OFF)
set(RE2_BUILD_TESTING OFF)

# Explicitly tell RE2 to use the system Abseil instead of downloading it
set(RE2_USE_ABSEIL ON)
set(RE2_ABSEIL_SOURCE "system")

# Add RE2 directory
add_subdirectory("${CMAKE_SOURCE_DIR}/thirdparty/re2" re2)

# Create the cre2 library
add_library(cre2 SHARED "${CMAKE_SOURCE_DIR}/thirdparty/cre2/src/cre2.cpp")

target_compile_definitions(cre2 PRIVATE 
    cre2_VERSION_INTERFACE_CURRENT=0
    cre2_VERSION_INTERFACE_REVISION=0
    cre2_VERSION_INTERFACE_AGE=0
    cre2_VERSION_INTERFACE_STRING="0.0.0"
)
