cmake_minimum_required(VERSION 3.16)

project(cre2)

# Abseil requires C++14
set(CMAKE_CXX_STANDARD 14)

add_library(cre2 SHARED "${CMAKE_SOURCE_DIR}/thirdparty/cre2/src/cre2.cpp")

# Define compile definitions that were previously passed via cl.exe.
target_compile_definitions(cre2 PRIVATE 
    cre2_VERSION_INTERFACE_CURRENT=0
    cre2_VERSION_INTERFACE_REVISION=0
    cre2_VERSION_INTERFACE_AGE=0
    cre2_VERSION_INTERFACE_STRING="\"0.0.0\""
    cre2_decl=__declspec(dllexport)
)

# Import Abseil's CMake targets
find_package(absl REQUIRED)
add_library(re2 STATIC IMPORTED)
set_target_properties(re2 PROPERTIES
    IMPORTED_LOCATION "${CMAKE_SOURCE_DIR}/bin/re2/Release/re2.lib"
)
target_link_libraries(cre2 PRIVATE re2)


