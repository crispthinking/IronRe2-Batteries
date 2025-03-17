cmake_minimum_required(VERSION 3.24)
project(IronRe-Batteries)

# Require C++17.
set(CMAKE_CXX_STANDARD 17)

# Global settings: force static linking and disable testing.
set(BUILD_SHARED_LIBS OFF)
set(BUILD_TESTING OFF)
set(RE2_BUILD_TESTING OFF)

# MSVC-specific settings.
if(MSVC)
  # Force /MT for Release and /MTd for Debug.
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
  # Ensure RE2 builds as static.
  set(RE2_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
endif()

# Define RE2_STATIC globally.
add_definitions(-DRE2_STATIC)

# Define the cre2 DLL target.
add_library(cre2 SHARED "${CMAKE_SOURCE_DIR}/thirdparty/cre2/src/cre2.cpp")

# On Windows, export all symbols (for MSVC).
if(WIN32)
  set_target_properties(cre2 PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

# Set compile definitions for cre2.
target_compile_definitions(cre2 PRIVATE
  cre2_VERSION_INTERFACE_CURRENT=0
  cre2_VERSION_INTERFACE_REVISION=0
  cre2_VERSION_INTERFACE_AGE=0
  cre2_VERSION_INTERFACE_STRING="0.0.0"
  RE2_STATIC  # Ensure that cre2's translation units know we're linking statically.
)

# Specify include directories for cre2.
target_include_directories(cre2 PRIVATE "${CMAKE_SOURCE_DIR}/thirdparty/re2")

# Set up Abseil package location for Windows.
if(WIN32)
  set(absl_DIR "C:/vcpkg/installed/x64-windows-static/share/absl")
endif()
find_package(absl CONFIG REQUIRED)

# Build re2 as a subdirectory.
add_subdirectory("${CMAKE_SOURCE_DIR}/thirdparty/re2" re2)

# Ensure the re2 target sees RE2_STATIC.
target_compile_definitions(re2 PUBLIC RE2_STATIC)

# Link required libraries.
target_link_libraries(cre2 PRIVATE 
  absl::base
  absl::strings
  absl::synchronization
  absl::time
  re2
)

# On MSVC, force whole-archive linking for re2; otherwise, use a generator expression.
if(MSVC)
  target_link_options(cre2 PRIVATE "/WHOLEARCHIVE:re2.lib")
else()
  target_link_libraries(cre2 PRIVATE "$<LINK_WHOLE_ARCHIVE:re2>")
endif()
