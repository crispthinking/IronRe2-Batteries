REM --- Locate VsDevCmd.bat ---
set "VSDIR=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat"
if not exist "%VSDIR%" (
    echo VsDevCmd.bat not found.
    exit /b 1
)
echo Found VsDevCmd.bat at "%VSDIR%"

REM --- Set up the Visual Studio environment ---
echo Setting up Visual Studio environment...
call "%VSDIR%" -arch=x64 -host_arch=x64
if errorlevel 1 (
    echo Failed to initialize VS environment.
    exit /b 1
)
echo Visual Studio environment set up successfully.

REM --- Verify that cl.exe is available ---
echo Verifying cl.exe availability...
where cl.exe >nul 2>&1
if errorlevel 1 (
    echo cl.exe not found in PATH. Ensure that the VS environment was set up correctly.
    echo Current PATH: !PATH!
    exit /b 1
) else (
    echo cl.exe found. Current PATH:
    echo !PATH!
)

REM Capture the current VS-modified PATH.
set "VS_ENV=!PATH!"

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
echo Discovering Abseil libraries from vcpkg...
set "ABSEIL_LIB_DIR=C:\vcpkg\installed\x64-windows\lib"
set "ABSEIL_LINKS="
for %%f in ("%ABSEIL_LIB_DIR%\absl*.lib") do (
    rem Append the file name (with extension) to ABSEIL_LINKS.
    set "ABSEIL_LINKS=%ABSEIL_LINKS% /link %%f"
)
echo Abseil libraries found: %ABSEIL_LINKS%

dir "C:\vcpkg\installed"

set "VPCKG_DIR=C:\vcpkg\"
echo Listing all files in %VPCKG_DIR%:
for %%f in ("%VPCKG_DIR%\*") do (
    echo %%f
)

REM --- Build cre2 using CMake ---
echo Building cre2 with CMake...
cmake . -B bin/cre2
if errorlevel 1 exit /b 1

cmake --build bin/cre2 --config Release
if errorlevel 1 exit /b 1

REM --- Package with dotnet pack ---
echo Packaging NuGet package...

REM Capture the version from GitVersion (FullSemVer in this example)
FOR /F "tokens=*" %%i in ('dotnet-gitversion /showvariable FullSemVer') do set VERSION=%%i

echo Packaging version: %VERSION%
dotnet pack BatteryPackage.csproj -c Release -o bin\artifacts /p:PackageVersion=%VERSION%
if errorlevel 1 exit /b 1

exit /b 0
