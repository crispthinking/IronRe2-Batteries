@echo off
REM --- Locate VsDevCmd.bat using vswhere ---
for /f "usebackq tokens=*" %%i in (`"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find "Common7\Tools\VsDevCmd.bat"`) do (
    set "VSDIR=%%i"
)
if not defined VSDIR (
    echo VsDevCmd.bat not found.
    exit /b 1
)
echo Found VsDevCmd.bat at %VSDIR%

REM --- Set up the Visual Studio environment ---
call "%VSDIR%"
if errorlevel 1 (
    echo Failed to initialize VS environment.
    exit /b 1
)

REM --- Build RE2 using CMake ---
echo Building RE2...
if not exist "bin\re2" mkdir bin\re2
cmake -S thirdparty\re2 -B bin\re2 -G "Visual Studio 17 2022" -A x64 -D BUILD_TESTING=OFF -D BUILD_SHARED_LIBS=OFF -D RE2_BUILD_TESTING=OFF
if errorlevel 1 exit /b 1

cmake --build bin\re2 --config Release
if errorlevel 1 exit /b 1

REM --- Build cre2 (the C FFI interface) ---
echo Building cre2...
set "RID=win-x64"
set "DYLIB_PREFIX="
set "DYLIB_EXT=dll"
set "OUTFILE=bin\contents\runtimes\%RID%\native\cre2.%DYLIB_EXT%"
if not exist "bin\contents\runtimes\%RID%\native" mkdir "bin\contents\runtimes\%RID%\native"

REM Compile cre2; adjust paths if needed.
cl.exe /EHsc /std:c++14 /LD /MD /O2 /DNDEBUG ^
  /Dcre2_VERSION_INTERFACE_CURRENT=0 ^
  /Dcre2_VERSION_INTERFACE_REVISION=0 ^
  /Dcre2_VERSION_INTERFACE_AGE=0 ^
  /Dcre2_VERSION_INTERFACE_STRING="\"0.0.0\"" ^
  /Dcre2_decl=__declspec(dllexport) ^
  /Ithirdparty\re2\ ^
  src\cre2.cpp ^
  /link bin\re2\Release\re2.lib ^
  /out:%OUTFILE%
if errorlevel 1 exit /b 1

REM --- Package with dotnet pack ---
echo Packaging NuGet package...
REM Get version information from GitVersion and parse with jq (assumes both are in PATH)
gitversion /output json > gitversion.json
for /f "usebackq tokens=*" %%i in (`jq -r ".NuGetVersionV2" gitversion.json`) do set "VERSION=%%i"
if "%VERSION%"=="" (
    echo Failed to retrieve version from GitVersion.
    exit /b 1
)

dotnet pack BatteryPackage.csproj -c Release -o bin\artifacts /p:PackageVersion=%VERSION%
if errorlevel 1 exit /b 1

exit /b 0