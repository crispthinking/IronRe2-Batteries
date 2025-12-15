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

# Define RE2_STATIC globally so that RE2�s headers treat the library as static.
add_definitions(-DRE2_STATIC)

# Define the cre2 shared library target.
add_library(cre2 SHARED "${CMAKE_SOURCE_DIR}/thirdparty/cre2/src/cre2.cpp")
if(MSVC)
  set_target_properties(cre2 PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

target_compile_definitions(cre2 PRIVATE
    cre2_VERSION_INTERFACE_CURRENT=0
    cre2_VERSION_INTERFACE_REVISION=0
    cre2_VERSION_INTERFACE_AGE=0
    cre2_VERSION_INTERFACE_STRING="0.0.0"
    RE2_STATIC  # Ensure static linking is known in cre2.
)

target_include_directories(cre2 PRIVATE "${CMAKE_SOURCE_DIR}/thirdparty/re2")

# Build Abseil from the vendored thirdparty directory.
# This will make absl targets available to RE2 and cre2.
set(ABSL_PROPAGATE_CXX_STD ON)
set(BUILD_TESTING OFF)
add_subdirectory("${CMAKE_SOURCE_DIR}/thirdparty/abseil-cpp" abseil-cpp)

# Build re2 as a subdirectory.
# RE2 will automatically use the Abseil targets we just added.
add_subdirectory("${CMAKE_SOURCE_DIR}/thirdparty/re2" re2)

# Link libraries. On all platforms, link Abseil targets statically together with re2.
target_link_libraries(cre2 PRIVATE 
      absl::base
      absl::strings
      absl::synchronization
      absl::time
      re2
)

if(MSVC)
  # For MSVC, force whole-archive linking of re2.
  target_link_options(cre2 PRIVATE "/WHOLEARCHIVE:re2.lib")
elseif(WIN32)
  target_link_libraries(cre2 PRIVATE "$<LINK_WHOLE_ARCHIVE:re2>")
endif()
