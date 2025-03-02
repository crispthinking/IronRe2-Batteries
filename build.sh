#!/bin/bash

set -euo pipefail

OS="$(uname)"

# Set up environment variables based on OS
if [[ "$OS" == "Darwin" ]]; then
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/opt/homebrew/lib/pkgconfig"
  export CXXFLAGS="-std=c++17 -fPIC -O3 -g -I/opt/homebrew/include -I/usr/local/include"
  export LDFLAGS="-L/opt/homebrew/lib -L/usr/local/lib"
  DYLIB_EXT="dylib"
  DYLIB_PREFIX="lib"
  RID="osx-x64"
  NUM_PROC=$(sysctl -n hw.logicalcpu)
elif [[ "$OS" == "Linux" ]]; then
  export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  export CXXFLAGS="-std=c++17 -fPIC -O3 -g -I/usr/local/include"
  export LDFLAGS="-L/usr/local/lib"
  DYLIB_EXT="so"
  DYLIB_PREFIX="lib"
  RID="linux-x64"
  NUM_PROC=$(nproc)
else
  echo "This build script currently supports only Linux and macOS."
  exit 1
fi

CRISP_GROUP="Crisp Thinking Group Ltd."

# --- Helper Functions ---
check_exit() {
  if [ "$1" -ne 0 ]; then
    echo "Process exited with code $1" >&2
    exit $1
  fi
}

# --- Make ---
build_cre2() {
  echo "=== Build Make ==="
  # Configure with CMake
  mkdir -p bin/cre2
  cmake . -B bin/cre2 -DCMAKE_CXX_FLAGS="$CXXFLAGS" -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS"
  check_exit $?

  # Build
  pushd bin/cre2 > /dev/null
  echo "Running: make -j$(( NUM_PROC * 2 ))"
  make -j$(( NUM_PROC * 2 ))
  check_exit $?
  popd > /dev/null
  
  # Copy the built library to the artifacts directory
  mkdir -p bin/artifacts/runtimes/$RID/native
  cp bin/cre2/${DYLIB_PREFIX}cre2.${DYLIB_EXT} bin/artifacts/runtimes/$RID/native/
}

pack_nuget() {
  echo "=== Get Version Number ==="
  mkdir -p bin/artifacts

  # Ensure a local dotnet tool manifest exists.
  if [ ! -f "./.config/dotnet-tools.json" ]; then
    echo "No tool manifest found. Creating one..."
    dotnet new tool-manifest
    echo "Installing GitVersion.Tool as a local tool..."
    dotnet tool install GitVersion.Tool --version 6.1.0
  else
    echo "Tool manifest found. Restoring tools..."
    dotnet tool restore
  fi

  # Check if jq is installed for parsing JSON output.
  if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed. Please install jq and try again."
    exit 1
  fi

  # Retrieve version information using GitVersion.
  echo "Retrieving version from GitVersion..."
  json_output=$(dotnet tool run dotnet-gitversion /output json 2>&1 || true)
  echo "GitVersion output: $json_output"  # Debugging line
  
  # Extract just the JSON part
  json_output=$(echo "$json_output" | sed -n '/^{/,$p')
  echo "Filtered JSON output: $json_output"  # Debugging line
  
  # Try to parse with jq, with error handling
  if ! version=$(echo "$json_output" | jq -r '.SemVer' 2>/dev/null); then
    echo "Failed to parse GitVersion output with jq. Using fallback version."
    version="0.1.0"
  fi

  if [ -z "$version" ] || [ "$version" = "null" ]; then
    echo "Warning: Failed to retrieve version from GitVersion. Using fallback version."
    version="0.1.0"
  fi

  echo "Version determined: $version"

  echo "=== Packing NuGet Package ==="
  mkdir -p bin/artifacts

  echo "BatteryPackage.${OS}.csproj"
  echo "Packaging version: $version"
  dotnet pack BatteryPackage.${OS}.csproj -c Release -o bin/artifacts/ -p:PackageVersion="$version"
  check_exit $?
}

# --- Clean Build Artifacts ---
clean() {
  echo "=== Cleaning Build Artifacts ==="
  rm -rf bin/
  if [ -d "thirdparty/re2" ]; then
    pushd thirdparty/re2 > /dev/null
    if [ -f "Makefile" ]; then
      make clean || true
    fi
    popd > /dev/null
  fi
}

# --- Main ---
main() {
  TARGET="${1:-Default}"
  case "$TARGET" in
    Clean)
      clean
      ;;
    *)
      build_cre2
      pack_nuget
      ;;
  esac
}

main "$@"
