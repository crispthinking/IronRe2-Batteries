#!/bin/bash

set -euo pipefail

OS="$(uname)"

if [[ "$OS" == "Darwin" ]]; then
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/opt/homebrew/lib/pkgconfig"
  export CXXFLAGS="-std=c++17 -fPIC -O3 -g -I/opt/homebrew/include"
elif [[ "$OS" == "Linux" ]]; then
  export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"
  export CXXFLAGS="-std=c++17 -fPIC -O3 -g -I/usr/include"
  export PATH="$HOME/.dotnet/tools:$PATH"
fi

if [[ "$OS" == "Linux" ]]; then
  DYLIB_EXT="so"
  DYLIB_PREFIX="lib"
  RID="linux-x64"
  NUM_PROC=$(nproc)
elif [[ "$OS" == "Darwin" ]]; then
  DYLIB_EXT="dylib"
  DYLIB_PREFIX="lib"
  RID="osx-x64"
  NUM_PROC=$(sysctl -n hw.logicalcpu)
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
  cmake . --build bin/cre2 --config Release
  check_exit $?

  pushd bin/cre2 > /dev/null
  echo "Running: make -j$(( NUM_PROC * 2 ))"
  make -j$(( NUM_PROC * 2 ))
  check_exit $?
  popd > /dev/null
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
  json_output=$(dotnet-gitversion /output json 2>&1 || true)
  echo "GitVersion output: $json_output"  # Debugging line
  json_output=$(echo "$json_output" | sed -n '/^{/,$p')
  echo "Filtered JSON output: $json_output"  # Debugging line
  version=$(echo "$json_output" | jq -r '.SemVer')

  if [ -z "$version" ]; then
    echo "Error: Failed to retrieve version from GitVersion."
    exit 1
  fi

  echo "Version determined: $version"

  echo "=== Packing NuGet Package ==="
  mkdir -p bin/artifacts

  echo "Packaging version: $version"
  dotnet pack BatteryPackage.csproj -c Release -o bin/artifacts/ -p:PackageVersion="$version"
  check_exit $?
}


# --- Clean Build Artifacts ---
clean() {
  echo "=== Cleaning Build Artifacts ==="
  rm -rf bin/
  pushd thirdparty/re2 > /dev/null
  make clean
  popd > /dev/null
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
