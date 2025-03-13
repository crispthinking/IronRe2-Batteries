#!/bin/bash
set -euo pipefail

OS="$(uname)"

# ------------------------------
# Global Configuration
# ------------------------------

if [[ "$OS" == "Linux" ]]; then
  export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  export CXXFLAGS="-std=c++17 -fPIC -O3 -g -I/usr/local/include"
  export LDFLAGS="-L/usr/local/lib"
  DYLIB_EXT="so"
  DYLIB_PREFIX="lib"
  TARGET_RID="linux-x64"
  TARGET_ARCH=""  # Not used on Linux.
  NUM_PROC=$(nproc)
elif [[ "$OS" == "Darwin" ]]; then
  # For Darwin, we leave target-specific variables unset globally.
  DYLIB_EXT="dylib"
  DYLIB_PREFIX="lib"
  NUM_PROC=$(sysctl -n hw.logicalcpu)
else
  echo "This build script currently supports only Linux and macOS."
  exit 1
fi

# Company name used in packaging.
CRISP_GROUP="Crisp Thinking Group Ltd."

# ------------------------------
# Darwin-specific Configuration
# ------------------------------
# When building on Darwin, call this function with "x64" or "arm64" to
# set the environment variables and TARGET_RID/ARCH appropriately.
configure_darwin_env() {
  local arch="$1"
  if [[ "$arch" == "x64" ]]; then
    # Use the Intel Homebrew installation (requires you have installed it under Rosetta,
    # e.g. in /usr/local/Homebrew)
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
    export CXXFLAGS="-std=c++17 -fPIC -O3 -g -I/usr/local/include"
    export LDFLAGS="-L/usr/local/lib"
    TARGET_RID="osx-x64"
    TARGET_ARCH="x86_64"
  elif [[ "$arch" == "arm64" ]]; then
    # Use the native Homebrew (installed at /opt/homebrew)
    export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"
    export CXXFLAGS="-std=c++17 -fPIC -O3 -g -I/opt/homebrew/include"
    export LDFLAGS="-L/opt/homebrew/lib"
    TARGET_RID="osx-arm64"
    TARGET_ARCH="arm64"
  else
    echo "Invalid Darwin architecture: $arch"
    exit 1
  fi
}

# ------------------------------
# Helper Function
# ------------------------------
check_exit() {
  if [ "$1" -ne 0 ]; then
    echo "Process exited with code $1" >&2
    exit $1
  fi
}

# ------------------------------
# Unified Build Function
# ------------------------------
build_cre2() {
  local build_dir="bin/cre2"
  if [[ "$OS" == "Darwin" ]]; then
    build_dir="${build_dir}/${TARGET_RID}"
  fi

  echo "=== Build Make (RID: ${TARGET_RID}, CMake Arch: ${TARGET_ARCH}) ==="
  cmake . -B "${build_dir}" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
    -DRID="${TARGET_RID}" \
    -DCMAKE_OSX_ARCHITECTURES="${TARGET_ARCH}" \
    -DDYLIB_EXT="$DYLIB_EXT" \
    -DDYLIB_PREFIX="$DYLIB_PREFIX"
  check_exit $?

  pushd "${build_dir}" > /dev/null
  echo "Running: make -j$(( NUM_PROC * 2 ))"
  make -j$(( NUM_PROC * 2 ))
  check_exit $?
  popd > /dev/null
}

pack_nuget() {
  echo "=== Get Version Number ==="
  mkdir -p bin/artifacts

  if [ ! -f "./.config/dotnet-tools.json" ]; then
    echo "No tool manifest found. Creating one..."
    dotnet new tool-manifest
    echo "Installing GitVersion.Tool as a local tool..."
    dotnet tool install GitVersion.Tool --version 6.1.0
  else
    echo "Tool manifest found. Restoring tools..."
    dotnet tool restore
  fi

  if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed. Please install jq and try again."
    exit 1
  fi

  echo "Retrieving version from GitVersion..."
  json_output=$(dotnet tool run dotnet-gitversion /output json 2>&1 || true)
  echo "GitVersion output: $json_output"
  json_output=$(echo "$json_output" | sed -n '/^{/,$p')
  echo "Filtered JSON output: $json_output"
  version=$(echo "$json_output" | jq -r '.SemVer')
  if [ -z "$version" ]; then
    echo "Error: Failed to retrieve version from GitVersion."
    exit 1
  fi
  echo "Version determined: $version"

  echo "=== Packing NuGet Package ==="
  mkdir -p bin/artifacts
  echo "BatteryPackage.${OS}.csproj"
  echo "Packaging version: $version"
  dotnet pack BatteryPackage.${OS}.csproj -c Release -o bin/artifacts/ \
    -p:PackageVersion="$version" -p:Company="$CRISP_GROUP"
  check_exit $?
}

clean() {
  echo "=== Cleaning Build Artifacts ==="
  rm -rf bin/
  pushd thirdparty/re2 > /dev/null
  make clean
  popd > /dev/null
}

# ------------------------------
# Main Entry Point
# ------------------------------
main() {
  TARGET="${1:-Default}"
  case "$TARGET" in
    Clean)
      clean
      ;;
    *)
      if [[ "$OS" == "Darwin" ]]; then
        # Build for Intel (x64). Make sure your CI environment has the Intel Homebrew installed (usually at /usr/local).
        # configure_darwin_env "x64"
        # build_cre2

        # Then build for Apple Silicon (arm64).
        configure_darwin_env "arm64"
        build_cre2
      else
        build_cre2
      fi
      pack_nuget
      ;;
  esac
}

main "$@"
