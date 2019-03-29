call "%VS140COMNTOOLS%\..\..\VC\vcvarsall.bat" x64

echo "looking for CL"
where cl

echo "looking for LINK"
where link

powershell -ExecutionPolicy ByPass -File .\build.ps1
