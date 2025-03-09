cmake_minimum_required(VERSION 3.24)
project(IronRe-Batteries)

# Require C++17.
set(CMAKE_CXX_STANDARD 17)

# Force all targets to use the static runtime on MSVC.
if(MSVC)
  # This forces /MT for Release and /MTd for Debug.
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

# Force static linking for dependencies.
set(BUILD_SHARED_LIBS OFF)
set(RE2_BUILD_TESTING OFF)
set(RE2_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)  # Ensure RE2 builds as a static library

# Define RE2_STATIC globally.
add_definitions(-DRE2_STATIC)

# Define the cre2 DLL target.
add_library(cre2 SHARED "${CMAKE_SOURCE_DIR}/thirdparty/cre2/src/cre2.cpp")
set_target_properties(cre2 PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)

target_compile_definitions(cre2 PRIVATE 
    cre2_VERSION_INTERFACE_CURRENT=0
    cre2_VERSION_INTERFACE_REVISION=0
    cre2_VERSION_INTERFACE_AGE=0
    cre2_VERSION_INTERFACE_STRING="0.0.0"
    RE2_STATIC
)
target_include_directories(cre2 PRIVATE "${CMAKE_SOURCE_DIR}/thirdparty/re2")

# (The global runtime setting should now apply to cre2.)
  
# Tell RE2 to use the system Abseil.
# Make sure the path points to the static triplet libraries.
# set(absl_DIR "C:/Users/Aorus/vcpkg/installed/x64-windows-static/share/absl")
find_package(absl CONFIG REQUIRED)

# Build RE2 as a subdirectory.
add_subdirectory("${CMAKE_SOURCE_DIR}/thirdparty/re2" re2)

# Force re2 target to use the static runtime as well.
if(MSVC)
  set_property(TARGET re2 PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()
target_compile_definitions(re2 PUBLIC RE2_STATIC)

if(MSVC)
  # Link cre2 with RE2 and required Abseil static libraries.
  target_link_libraries(cre2 PRIVATE 
      absl::base 
      absl::strings 
      absl::synchronization
      absl::time
      re2
  )
  # Force the linker to include all object files from re2.lib.
  target_link_options(cre2 PRIVATE "/WHOLEARCHIVE:re2.lib")
else()
  target_link_libraries(cre2 PRIVATE 
      absl::base 
      absl::strings 
      absl::synchronization
      absl::time
      "$<LINK_WHOLE_ARCHIVE:re2>"
  )
endif()
