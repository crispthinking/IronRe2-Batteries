cmake_minimum_required(VERSION 3.24)
project(IronRe-Batteries)

# Require C++17.
set(CMAKE_CXX_STANDARD 17)

# Force static linking and turn off shared libraries and tests globally.
set(BUILD_SHARED_LIBS OFF)
set(BUILD_TESTING OFF)
set(RE2_BUILD_TESTING OFF)

# On MSVC, force the static runtime and ensure RE2 builds as a static library.
if(MSVC)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
  set(RE2_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
endif()

# Define RE2_STATIC so that RE2’s headers treat the library as static.
add_definitions(-DRE2_STATIC)

# Setup Abseil package location.
# For Windows, use the vcpkg-installed Abseil from the static triplet.
if(WIN32)
  set(absl_DIR "C:/vcpkg/installed/x64-windows-static/share/absl")
# For macOS, adjust this path to point to your static Abseil installation.

find_package(absl CONFIG REQUIRED)

# For non-Windows platforms, instruct RE2 to use system Abseil.
if(NOT WIN32)
  set(RE2_USE_ABSEIL ON)
  set(RE2_ABSEIL_SOURCE "system")
endif()

# Define the cre2 DLL target.
add_library(cre2 SHARED "${CMAKE_SOURCE_DIR}/thirdparty/cre2/src/cre2.cpp")
if(MSVC)
  set_target_properties(cre2 PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

target_compile_definitions(cre2 PRIVATE
    cre2_VERSION_INTERFACE_CURRENT=0
    cre2_VERSION_INTERFACE_REVISION=0
    cre2_VERSION_INTERFACE_AGE=0
    cre2_VERSION_INTERFACE_STRING="0.0.0"
    RE2_STATIC  # Ensure translation units know they’re linking statically.
)

target_include_directories(cre2 PRIVATE "${CMAKE_SOURCE_DIR}/thirdparty/re2")

# Build re2 as a subdirectory.
add_subdirectory("${CMAKE_SOURCE_DIR}/thirdparty/re2" re2)

# Ensure the re2 target sees RE2_STATIC.
target_compile_definitions(re2 PUBLIC RE2_STATIC)

# Link libraries.
target_link_libraries(cre2 PRIVATE 
    absl::base
    absl::strings
    absl::synchronization
    absl::time
    re2
)

# On MSVC, force whole-archive linking of re2 so its entire static library is pulled in.
if(MSVC)
  target_link_options(cre2 PRIVATE "/WHOLEARCHIVE:re2.lib")
endif()
