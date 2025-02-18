# build.ps1
Write-Host "Setting up Visual Studio environment..."

# Adjust the path as needed.
# GitHub Actions Windows runners typically have VS 2019 installed.
$vsDevCmd = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\Tools\VsDevCmd.bat"
if (-Not (Test-Path $vsDevCmd)) {
    Write-Error "VsDevCmd.bat not found at $vsDevCmd"
    exit 1
}

# Call the VS Developer Command Prompt to set up environment variables.
& $vsDevCmd

# --- Build RE2 using CMake and MSBuild ---
Write-Host "Building RE2..."

# Create output directory for RE2 build.
$re2BuildDir = "bin\re2"
New-Item -ItemType Directory -Force -Path $re2BuildDir | Out-Null

# Configure RE2 via CMake.
cmake -S thirdparty\re2 -B $re2BuildDir -G "Visual Studio 16 2019" -A x64 `
    -D BUILD_TESTING=OFF -D BUILD_SHARED_LIBS=OFF -D RE2_BUILD_TESTING=OFF

# Build the generated solution in Release mode.
msbuild "$re2BuildDir\RE2.sln" /p:Configuration=Release

# --- Build cre2 (the C FFI interface) ---
Write-Host "Building cre2..."

# Compute the output file path.
$RID = "win-x64"
$DYLIB_PREFIX = ""  # On Windows, no prefix.
$DYLIB_EXT = "dll"
$outDir = "bin\contents\runtimes\$RID\native"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir ("{0}cre2.{1}" -f $DYLIB_PREFIX, $DYLIB_EXT)

# Build cre2 using cl.exe.
# (This example mimics the options from your Bash script.)
# Adjust the include/library paths as needed.
$clArgs = @(
    "/EHsc", "/std:c++14", "/LD", "/MD",
    "/O2", "/DNDEBUG",
    '/Dcre2_VERSION_INTERFACE_CURRENT=0',
    '/Dcre2_VERSION_INTERFACE_REVISION=0',
    '/Dcre2_VERSION_INTERFACE_AGE=0',
    '/Dcre2_VERSION_INTERFACE_STRING=\"0.0.0\"',
    "/Dcre2_decl=__declspec(dllexport)",
    "/I..\\re2\\",
    "src\\cre2.cpp",
    "/Fo..\\..\\bin",
    "/link",
    "..\\..\\bin\\re2\\Release\\re2.lib",
    "/out:$outFile"
)

# Call cl.exe – ensure that cl.exe is in PATH (set by VsDevCmd.bat).
Write-Host "Invoking cl.exe with arguments: $($clArgs -join ' ')"
cl.exe @clArgs

# --- Package with dotnet pack ---
Write-Host "Packaging NuGet package..."
# Retrieve version info using GitVersion. (Assumes it's available in PATH.)
$gitVersionOutput = & gitversion /output json | Out-String
# For JSON parsing in PowerShell, convert the output.
$versionInfo = $gitVersionOutput | ConvertFrom-Json
$version = $versionInfo.NuGetVersionV2
if (-not $version) {
    Write-Error "Version not determined from GitVersion."
    exit 1
}

# Assume you have a project file (e.g., BatteryPackage.csproj) that defines your package metadata.
dotnet pack BatteryPackage.csproj -c Release -o bin\artifacts /p:PackageVersion=$version