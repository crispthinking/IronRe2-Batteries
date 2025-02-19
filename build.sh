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

  # Initialize variables to avoid unbound variable errors.
  ABSEIL_LIB=""
  ABSEIL_INCLUDE=""

  # Set Abseil include and library flags based on OS.
  if [[ "$OS" == "Linux" ]]; then
    ABSEIL_INCLUDE="-I/usr/include/absl"
    ABSEIL_LIB="-L/usr/lib -labsl_base -labsl_raw_logging_internal -labsl_str_format_internal"
  elif [[ "$OS" == "Darwin" ]]; then
    ABSEIL_INCLUDE="-I/opt/homebrew/Cellar/abseil/20240722.1/include"
    ABSEIL_LIB="-L/opt/homebrew/lib -labsl_log_internal -labsl_raw_logging_internal -labsl_str_format_internal -labsl_synchronization -labsl_time -labsl_strings -labsl_base -labsl_flags -labsl_flags_parse"
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

  # Ensure GitVersion.Tool is updated/installed.
  dotnet tool update -g GitVersion.Tool || dotnet tool install -g GitVersion.Tool || true
  export PATH="$HOME/.dotnet/tools:$PATH"

  # Run GitVersion directly by full path
  versionInfo=$("$HOME/.dotnet/tools/gitversion" /output json)
  
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

  # Use dotnet pack on your package project file, passing the version.
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
