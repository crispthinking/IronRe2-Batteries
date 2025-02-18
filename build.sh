#!/bin/bash
set -euo pipefail

# --- Platform-specific Settings ---
OS="$(uname)"

if [[ "$OS" == "Darwin" ]]; then
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/opt/homebrew/lib/pkgconfig"
fi

if [[ "$OS" == "Linux" ]]; then
  export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"
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
  export CXXFLAGS="-std=c++17 -fPIC -O3 -g"
  # Run make for target "obj/libre2.a" using twice the number of available processors
  echo "Running: make obj/libre2.a -j$(( NUM_PROC * 2 ))"
  make obj/libre2.a -j$(( NUM_PROC * 2 ))
  check_exit $?
  popd > /dev/null
}

# --- Build cre2 (the C FFI interface) ---
build_cre2() {
  echo "=== Building cre2 ==="
  # Compute the output file path:
  # bin/contents/runtimes/${RID}/native/${DYLIB_PREFIX}cre2.${DYLIB_EXT}
  OUTFILE="bin/contents/runtimes/${RID}/native/${DYLIB_PREFIX}cre2.${DYLIB_EXT}"
  mkdir -p "$(dirname "$OUTFILE")"

  pushd thirdparty/cre2 > /dev/null
  echo "Building with clang++; output: ${OUTFILE}"
  clang++ --verbose \
    -shared -fpic -std=c++17 -O3 -g -DNDEBUG \
    -Dcre2_VERSION_INTERFACE_CURRENT=0 \
    -Dcre2_VERSION_INTERFACE_REVISION=0 \
    -Dcre2_VERSION_INTERFACE_AGE=0 \
    -Dcre2_VERSION_INTERFACE_STRING="\"0.0.0\"" \
    -I../re2/ \
    src/cre2.cpp \
    ../re2/obj/libre2.a \
    -o "${OUTFILE}"
  check_exit $?
  popd > /dev/null
}

# --- Package into a NuGet Battery Pack ---
pack_nuget() {
  echo "=== Packing NuGet Package ==="
  mkdir -p bin/artifacts

  # Retrieve version info using GitVersion (assumes it outputs JSON)
  if ! command -v gitversion &> /dev/null; then
    echo "Error: gitversion not found. Please install it." >&2
    exit 1
  fi
  versionInfo=$(gitversion /output json)
  # Requires 'jq' to parse JSON
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is required to parse GitVersion output." >&2
    exit 1
  fi
  version=$(echo "$versionInfo" | jq -r '.NuGetVersionV2')
  if [[ -z "$version" ]]; then
    echo "Could not determine version from gitversion output." >&2
    exit 1
  fi

  # Use dotnet pack on your package project file, passing the version
  dotnet pack BatteryPackage.csproj -c Release -o bin/artifacts/ /p:PackageVersion=${version}
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