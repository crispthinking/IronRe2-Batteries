setlocal EnableDelayedExpansion

REM --- Locate VsDevCmd.bat ---
set "VS_PATHS=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat;C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat"
set "VSDIR="
for %%p in ("%VS_PATHS:;=" "%") do (
    echo Checking path: %%~p
    if exist "%%~p" (
        set "VSDIR=%%~p"
        goto :found_vsdevcmd
    )
)
echo VsDevCmd.bat not found.
exit /b 1

:found_vsdevcmd
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

REM --- Setup basic environment variables ---
set "RID=win-x64"
set "DYLIB_PREFIX="
set "DYLIB_EXT=dll"

REM Set compiler flags (adjust as needed)
set "CXX_FLAGS=/std:c++17 /O2 /EHsc /MD"

REM Set number of processor cores for parallel build
for /f "tokens=2 delims==" %%a in ('wmic cpu get NumberOfLogicalProcessors /value') do (
    set /a NUM_PROC=%%a
)
set /a PARALLEL_JOBS=%NUM_PROC% * 2

REM Create the output directory if it doesn't exist
if not exist "bin\cre2" mkdir "bin\cre2"

echo Building cre2 with CMake...
cmake -S windows -B bin\cre2 -G "Visual Studio 17 2022" -A x64 ^
  -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_CXX_FLAGS="%CXX_FLAGS%" ^
  -DCMAKE_CXX_STANDARD=17 ^
  -DVCPKG_TARGET_TRIPLET=x64-windows-static
if errorlevel 1 exit /b 1

echo Building with parallel jobs: %PARALLEL_JOBS%
cmake --build bin\cre2 --config Release --parallel %PARALLEL_JOBS%
if errorlevel 1 exit /b 1

echo Checking for built DLL...
if exist "bin\cre2\Release\cre2.dll" (
    echo DLL found at bin\cre2\Release\cre2.dll
    for %%F in ("bin\cre2\Release\cre2.dll") do (
        echo DLL size: %%~zF bytes
        if %%~zF LSS 1000000 (
            echo WARNING: DLL might be smaller than expected. It may not include all dependencies.
        )
    )
) else (
    echo DLL not found! Checking Release directory content:
    dir "bin\cre2\Release" /B
    exit /b 1
)

echo Copying cre2.dll and dependencies...
copy /Y "bin\cre2\Release\cre2.dll" "bin\cre2\cre2.dll"
if errorlevel 1 exit /b 1

echo Packaging NuGet package...
FOR /F "tokens=*" %%i in ('dotnet tool run dotnet-gitversion /showvariable FullSemVer') do set VERSION=%%i
echo Packaging version: %VERSION%
dotnet pack BatteryPackage.Windows.csproj -c Release -o bin\artifacts /p:PackageVersion=%VERSION%
if errorlevel 1 exit /b 1

exit /b 0
