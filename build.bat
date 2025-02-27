@echo off
REM --- Set up Visual Studio environment for x64 (without delayed expansion) ---
set VSDIR="%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat"
if not exist %VSDIR% (
    echo VsDevCmd.bat not found.
    exit /b 1
)
echo Found VsDevCmd.bat at %VSDIR%
call %VSDIR% -arch=x64
if errorlevel 1 (
    echo Failed to initialize VS environment.
    exit /b 1
)

REM --- Rest of the file remains the same ---
