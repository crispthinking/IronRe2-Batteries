@echo off
setlocal EnableDelayedExpansion

REM --- Locate VsDevCmd.bat ---
if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat" (
    set "VSDIR=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat"
) else (
    echo VsDevCmd.bat not found.
    exit /b 1
)
echo Found VsDevCmd.bat at "%VSDIR%"

REM --- Set up the Visual Studio environment for x64 ---
call "%VSDIR%" -arch=x64
if errorlevel 1 (
    echo Failed to initialize VS environment.
    exit /b 1
)

REM --- Build RE2 using CMake ---
echo Building RE2...
if not exist "bin\re2" mkdir bin\re2
cmake -S thirdparty\re2 -B bin\re2 -G "Visual Studio 17 2022" -A x64 -D BUILD_TESTING=OFF -D BUILD_SHARED_LIBS=OFF -D RE2_BUILD_TESTING=OFF -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake
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

REM --- Dynamically discover Abseil libraries from vcpkg ---
REM Define ABSEIL_LIB_DIR outside the loop so it persists.
set "ABSEIL_LIB_DIR=C:\vcpkg\installed\x64-windows\lib"
set "ABSEIL_LIBS="
for %%f in ("%ABSEIL_LIB_DIR%\absl_*.lib") do (
    rem Append the file name (with extension) to ABSEIL_LIBS.
    set "ABSEIL_LIBS=!ABSEIL_LIBS! %%~nxf"
)
echo Abseil libraries found: !ABSEIL_LIBS!
REM End local environment and reassign variables so they're available outside.
endlocal & (
    set "ABSEIL_LIBS=%ABSEIL_LIBS%"
    set "ABSEIL_LIB_DIR=C:\vcpkg\installed\x64-windows\lib"
)

REM --- Invoke the compiler/linker ---
cl.exe /EHsc /std:c++17 /LD /MD /O2 /DNDEBUG ^
  /Dcre2_VERSION_INTERFACE_CURRENT=0 ^
  /Dcre2_VERSION_INTERFACE_REVISION=0 ^
  /Dcre2_VERSION_INTERFACE_AGE=0 ^
  /Dcre2_VERSION_INTERFACE_STRING="\"0.0.0\"" ^
  /Dcre2_decl=__declspec(dllexport) ^
  /Ithirdparty\re2\ ^
  /I"C:\vcpkg\installed\x64-windows\include" ^
  thirdparty\cre2\src\cre2.cpp ^
  /link /machine:x64 bin\re2\Release\re2.lib ^
  /LIBPATH:"%ABSEIL_LIB_DIR%" %ABSEIL_LIBS% ^
  /out:bin\contents\runtimes\win-x64\native\cre2.dll
if errorlevel 1 exit /b 1

REM --- Package with dotnet pack ---
echo Packaging NuGet package...
gitversion /output json > gitversion.json
for /f "usebackq delims=" %%i in (`jq -r ".NuGetVersionV2" gitversion.json`) do set "VERSION=%%i"
if "%VERSION%"=="" (
    echo Failed to retrieve version from GitVersion.
    exit /b 1
)
dotnet pack BatteryPackage.csproj -c Release -o bin\artifacts /p:PackageVersion=%VERSION%
if errorlevel 1 exit /b 1

exit /b 0
