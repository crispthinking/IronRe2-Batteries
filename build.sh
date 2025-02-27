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

# --- Build RE2 ---
build_re2() {
  echo "=== Building RE2 ==="
  pushd thirdparty/re2 > /dev/null
  echo "Running: make obj/libre2.a -j$(( NUM_PROC * 2 ))"
  make obj/libre2.a -j$(( NUM_PROC * 2 ))
  check_exit $?
  popd > /dev/null
}

# --- Build cre2 (the C FFI interface) ---
build_cre2() {
  echo "=== Building cre2 ==="
  OUTFILE="$PWD/bin/contents/runtimes/${RID}/native/${DYLIB_PREFIX}cre2.${DYLIB_EXT}"
  echo "Output file will be: ${OUTFILE}"
  mkdir -p "$(dirname "$OUTFILE")"

  # Initialize variables.
  ABSEIL_LIB=""
  ABSEIL_INCLUDE=""

  # Set Abseil include path and libraries based on OS.
  if [[ "$OS" == "Linux" ]]; then
    ABSEIL_INCLUDE="-I/usr/include/absl"
    ABSEIL_LIB="-L/usr/lib -labsl_base -labsl_raw_logging_internal -labsl_str_format_internal"
  elif [[ "$OS" == "Darwin" ]]; then
    ABSEIL_INCLUDE="-I/opt/homebrew/Cellar/abseil/20240722.1/include"
    # Dynamically collect all Abseil libraries from Homebrew's lib folder.
    ABSEIL_LIB_DIR="/opt/homebrew/lib"
    ABSEIL_LIBS=""
    for lib in "$ABSEIL_LIB_DIR"/libabsl_*.dylib; do
      # Get the base filename without extension.
      libname=$(basename "$lib" .dylib)
      # Remove the leading 'lib' so that -l flag is correct.
      libname=${libname#lib}
      ABSEIL_LIBS="$ABSEIL_LIBS -l$libname"
    done
    ABSEIL_LIB="-L$ABSEIL_LIB_DIR $ABSEIL_LIBS"
  fi

  pushd thirdparty/cre2 > /dev/null
  echo "Building with clang++; output: ${OUTFILE}"
  clang++ --verbose \
    -shared -fpic -std=c++17 -O3 -g -DNDEBUG \
    -Dcre2_VERSION_INTERFACE_CURRENT=0 \
    -Dcre2_VERSION_INTERFACE_REVISION=0 \
    -Dcre2_VERSION_INTERFACE_AGE=0 \
    -Dcre2_VERSION_INTERFACE_STRING="\"0.0.0\"" \
    -I../re2/ \
    ${ABSEIL_INCLUDE} \
    src/cre2.cpp \
    ../re2/obj/libre2.a \
    ${ABSEIL_LIB} \
    -o "${OUTFILE}"
  check_exit $?
  popd > /dev/null
}

pack_nuget() {
  echo "=== Packing NuGet Package ==="
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
  # Filter the output so that only the JSON part (starting with '{') is processed.
  json_output=$(dotnet gitversion /output json 2>&1 | sed -n '/^{/,$p')
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
      build_re2
      build_cre2
      pack_nuget
      ;;
  esac
}

main "$@"
