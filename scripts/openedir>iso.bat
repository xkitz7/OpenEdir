@echo off
setlocal enabledelayedexpansion
echo ====== OpenEdir ISO Maker =================================================================================================================================================================================================================================================echo.
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set "REPO_URL=https://github.com/xkitz7/OpenEdir.git"
set "BUILD_DIR=..\openedir-build"
set "ISO_NAME=OpenEdir.iso"
set "LOG_FILE=build.log"

if not exist "..\boot" (
    echo [ERROR] This script should be run from the scripts/ directory
    echo [ERROR] Expected to find ../boot directory
    pause
    exit /b 1
)

net file >nul 2>nul
if '%erorrlevel%' neq '0' (
    echo _
    echo(
    powershell.exe -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [INFO] Starting OpenEdir build process, please wait...
echo [INFO] Build log: %LOG_FILE%
echo.

call :check_dependencies
if !errorlevel! neq 0 (
    echo [ERROR] Dependency check failed
    pause
    exit /b 1
)

call :clone_repository
if !errorlevel! neq 0 (
    echo [ERROR] Repository cloning failed
    pause
    exit /b 1
)

call :compile_project
if !errorlevel! neq 0 (
    echo [ERROR] Compilation failed
    pause
    exit /b 1
)

call :create_iso
if !errorlevel! neq 0 (
    echo [ERROR] ISO creation failed
    pause
    exit /b 1
)

echo.
echo [SUCCESS] BUILD SUCCESSFUL!
echo [INFO] ISO Created: %ISO_NAME%
echo.
pause
exit /b 0

:check_dependencies
echo [STEP 1/4] Checking dependencies...
echo Checking dependencies... > "%LOG_FILE%"
echo.

where nasm >nul 2>nul
if !errorlevel! neq 0 (
    echo [ERROR] NASM not found. Please install NASM assembler
    echo [INFO] Download from: https://www.nasm.us/
    goto :install_deps_prompt
)

where gcc >nul 2>nul
if !errorlevel! neq 0 (
    echo [ERROR] GCC not found. Please install MinGW-w64
    echo [INFO] Download from: https://www.mingw-w64.org/
    goto :install_deps_prompt
)

where git >nul 2>nul
if !errorlevel! neq 0 (
    echo [ERROR] Git not found. Please install Git
    echo [INFO] Download from: https://git-scm.com/
    goto :install_deps_prompt
)

where make >nul 2>nul
if !errorlevel! neq 0 (
    echo [ERROR] Make not found. Please install Make
    echo [INFO] Usually comes with MinGW or DevKit
    goto :install_deps_prompt
)

echo [SUCCESS] All dependencies found!
echo [INFO] NASM, GCC, Git, and Make are available
goto :eof

:install_deps_prompt
echo.
set /p "install_prompt=Do you want to open dependency download pages? (y/n): "
if /i "!install_prompt!"=="y" (
    start https://www.nasm.us/
    start https://www.mingw-w64.org/
    start https://git-scm.com/
)
exit /b 1

:clone_repository
echo.
echo [STEP 2/4] Setting up repository...

if exist "%BUILD_DIR%" (
    echo [INFO] Build directory exists, updating...
    cd "%BUILD_DIR%"
    git pull >> "..\scripts\%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
        echo [WARNING] Git pull failed, but continuing...
    )
    cd ..\scripts
) else (
    echo [INFO] Cloning repository from %REPO_URL%
    git clone "%REPO_URL%" "%BUILD_DIR%" >> "%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to clone repository
        exit /b 1
    )
)

if not exist "%BUILD_DIR%\boot\boot.asm" (
    echo [ERROR] Repository structure invalid - missing boot/boot.asm
    exit /b 1
)

if not exist "%BUILD_DIR%\krnl\src\main.c" (
    echo [ERROR] Repository structure invalid - missing krnl/src/main.c
    exit /b 1
)

echo [SUCCESS] Repository ready!
goto :eof

:compile_project
echo.
echo [STEP 3/4] Compiling OpenEdir...
cd "%BUILD_DIR%"

echo [INFO] Building bootloader...
nasm -f bin boot\boot.asm -o boot.bin >> "..\scripts\%LOG_FILE%" 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Bootloader assembly failed
    exit /b 1
)

echo [INFO] Building multiboot header...
nasm -f elf32 boot\multiboot.asm -o multiboot.o >> "..\scripts\%LOG_FILE%" 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Multiboot assembly failed
    exit /b 1
)

echo [INFO] Compiling kernel C files...

for %%f in (krnl\src\*.c) do (
    echo [INFO] Compiling %%~nf.c...
    gcc -m32 -ffreestanding -nostdlib -nostartfiles -nodefaultlibs -Ikrnl\include -c "%%f" -o "%%~nf.o" >> "..\scripts\%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Compilation failed for %%~nf.c
        exit /b 1
    )
)

echo [INFO] Linking kernel...
ld -m elf_i386 -T boot\linker.ld -o kernel.bin multiboot.o main.o terminal.o memory.o interrupts.o process.o >> "..\scripts\%LOG_FILE%" 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Linking failed
    exit /b 1
)

echo [SUCCESS] Compilation completed!
cd ..\scripts
goto :eof

:create_iso
echo.
echo [STEP 4/4] Creating ISO...

cd "%BUILD_DIR%"

if exist iso rd /s /q iso
mkdir iso
mkdir iso\boot
mkdir iso\boot\grub

copy boot.bin iso\boot\ >nul
copy kernel.bin iso\boot\ >nul

echo set timeout=0 > iso\boot\grub\grub.cfg
echo set default=0 >> iso\boot\grub\grub.cfg
echo. >> iso\boot\grub\grub.cfg
echo menuentry "OpenEdir" { >> iso\boot\grub\grub.cfg
echo     multiboot /boot/kernel.bin >> iso\boot\grub\grub.cfg
echo     boot >> iso\boot\grub\grub.cfg
echo } >> iso\boot\grub\grub.cfg

where genisoimage >nul 2>nul
if !errorlevel! equ 0 (
    echo [INFO] Using genisoimage...
    genisoimage -R -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table -o "%ISO_NAME%" iso >> "..\scripts\%LOG_FILE%" 2>&1
) else (
    where mkisofs >nul 2>nul
    if !errorlevel! equ 0 (
        echo [INFO] Using mkisofs...
        mkisofs -R -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table -o "%ISO_NAME%" iso >> "..\scripts\%LOG_FILE%" 2>&1
    ) else (
        where oscdimg >nul 2>nul
        if !errorlevel! equ 0 (
            echo [INFO] Using oscdimg (Windows)...
            oscdimg -b"iso\boot\grub\stage2_eltorito" -lOpenEdir iso "%ISO_NAME%" >> "..\scripts\%LOG_FILE%" 2>&1
        ) else (
            echo [ERROR] No ISO creation tool found!
            echo [INFO] Install one of: genisoimage, mkisofs, or oscdimg
            exit /b 1
        )
    )
)

if !errorlevel! neq 0 (
    echo [ERROR] ISO creation failed
    exit /b 1
)

copy "%ISO_NAME%" "..\scripts\" >nul

echo [SUCCESS] ISO created: %ISO_NAME%
cd ..\scripts
goto :eof
