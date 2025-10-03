@echo off
echo.
echo ====== OpenEdir Environment Setup =================================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo This script helps set up the build environment for OpenEdir.
echo.
echo Required tools:
echo - NASM Assembler
echo - MinGW-w64 (GCC for Windows) 
echo - Git
echo - Make
echo - ISO creation tool (genisoimage, mkisofs, or oscdimg)
echo.

:TEST
set /p "test=Run environment check only, skip download? (y/n): "
if /i "%test%"=="y" (
    goto CHECK_ENV
)

set /p "download=Open dependency download pages? (y/n): "
if /i "%download%"=="y" (
    echo Opening download pages...
    start "" "https://www.nasm.us/"
    timeout /t 2 >nul
    start "" "https://www.mingw-w64.org/"
    timeout /t 2 >nul
    start "" "https://git-scm.com/"
    timeout /t 2 >nul
    start "" "https://www.gnu.org/software/make/"
    timeout /t 2 >nul
)

:CHECK_ENV
echo.
echo Installation tips:
echo 1. Install NASM and add to PATH
echo 2. Install MinGW-w64 and add bin/ to PATH
echo 3. Install Git and choose "Git from command line" option
echo 4. Make sure all tools are accessible from Command Prompt
echo.

echo Checking current environment...
where nasm >nul 2>&1 && echo [✓] NASM found || echo [✗] NASM missing
where gcc >nul 2>&1 && echo [✓] GCC found || echo [✗] GCC missing
where git >nul 2>&1 && echo [✓] Git found || echo [✗] Git missing
where make >nul 2>&1 && echo [✓] Make found || echo [✗] Make missing

echo.
echo After installation, run build.bat to compile OpenEdir.
pause
exit /b
