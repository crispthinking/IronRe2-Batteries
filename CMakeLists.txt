cmake_minimum_required(VERSION 3.24)
project(IronRe-Batteries)

# Require C++17.
set(CMAKE_CXX_STANDARD 17)

# Force static linking and turn off shared libraries globally.
set(BUILD_SHARED_LIBS OFF)
set(BUILD_TESTING OFF)
set(RE2_BUILD_TESTING OFF)

# On Windows/MSVC, force the static runtime.
if(MSVC)
  # This forces /MT for Release and /MTd for Debug.
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
  # Also ensure RE2 builds as static.
  set(RE2_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
endif()

# On Windows, define RE2_STATIC so that RE2’s headers treat the library as static.
if(WIN32)
  add_definitions(-DRE2_STATIC)
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
)
# On Windows, add RE2_STATIC so that cre2’s translation units know they’re linking statically.
if(WIN32)
  target_compile_definitions(cre2 PRIVATE RE2_STATIC)
endif()

target_include_directories(cre2 PRIVATE "${CMAKE_SOURCE_DIR}/thirdparty/re2")

# Set up Abseil package location.
if(WIN32)
  # Use the vcpkg-installed Abseil from the static triplet.
  set(absl_DIR "C:/vcpkg/installed/x64-windows-static/share/absl")
endif()
find_package(absl CONFIG REQUIRED)

# For UNIX, tell RE2 to use Abseil from the system.
if(NOT WIN32)
  set(RE2_USE_ABSEIL ON)
  set(RE2_ABSEIL_SOURCE "system")
endif()

# Build re2 as a subdirectory.
add_subdirectory("${CMAKE_SOURCE_DIR}/thirdparty/re2" re2)
# On Windows, ensure the re2 target sees RE2_STATIC.
if(WIN32)
  target_compile_definitions(re2 PUBLIC RE2_STATIC)
endif()

# Link libraries.
if(WIN32)
  # Link required Abseil static libraries.
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
  else()
    target_link_libraries(cre2 PRIVATE "$<LINK_WHOLE_ARCHIVE:re2>")
  endif()
else()
  # On UNIX, simply link re2 normally.
  target_link_libraries(cre2 PRIVATE re2)
endif()
