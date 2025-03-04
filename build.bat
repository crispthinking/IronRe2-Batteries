REM --- Locate VsDevCmd.bat ---
set "VSDIR=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat"
if not exist "%VSDIR%" (
    echo VsDevCmd.bat not found.
    exit /b 1
)
echo Found VsDevCmd.bat at "%VSDIR%"

echo "Tool manifest found. Restoring tools..."
dotnet tool restore

REM --- Set up the Visual Studio environment ---
echo Setting up Visual Studio environment...
call "%VSDIR%" -arch=x64 -host_arch=x64
if errorlevel 1 (
    echo Failed to initialize VS environment.
    exit /b 1
)
echo Visual Studio environment set up successfully.

REM Capture the current VS-modified PATH.
set "VS_ENV=!PATH!"



REM --- Build cre2 (the C FFI interface) ---
echo Building cre2...
set "RID=win-x64"
set "DYLIB_PREFIX="
set "DYLIB_EXT=dll"
set "OUTFILE=bin\contents\runtimes\win-x64\native\cre2.dll"
if not exist "bin\contents\runtimes\%RID%\native" mkdir "bin\contents\runtimes\%RID%\native"

dir "C:\vcpkg\packages"

set "VPCKG_DIR=C:\vcpkg\"
echo Listing all files in %VPCKG_DIR%:
for %%f in ("%VPCKG_DIR%\*") do (
    echo %%f
)

echo Building cre2 with CMake...
cmake . -B bin/cre2 -G "Visual Studio 17 2022" -A x64 -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake
if errorlevel 1 exit /b 1


:: Copy the built DLL to the expected location for packaging
REM echo Copying cre2.dll from Release folder to expected location...
REM copy /Y "bin\cre2\Release\cre2.dll" "bin\cre2\cre2.dll"
REM if errorlevel 1 exit /b 1

REM --- Package with dotnet pack ---
echo Packaging NuGet package...

REM Capture the version from GitVersion (FullSemVer in this example)
FOR /F "tokens=*" %%i in ('dotnet tool run dotnet-gitversion /showvariable FullSemVer') do set VERSION=%%i

echo Packaging version: %VERSION%
dotnet pack BatteryPackage.Windows.csproj -c Release -o bin\artifacts /p:PackageVersion=%VERSION%
if errorlevel 1 exit /b 1

exit /b 0
