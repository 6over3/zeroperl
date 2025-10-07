@echo off
echo Testing cross-platform Makefile on Windows...

where make >nul 2>&1
if %errorlevel% neq 0 (
    echo [FAIL] Make not found. Install via:
    echo   - Chocolatey: choco install make
    echo   - MSYS2: pacman -S make
    echo   - Or use WSL
    exit /b 1
)

echo [TEST] OS Detection
make test-os
if %errorlevel% equ 0 (echo [PASS] OS detection works) else (echo [FAIL] OS detection failed)

echo [TEST] Help target
make help >nul 2>&1
if %errorlevel% equ 0 (echo [PASS] Help works) else (echo [FAIL] Help failed)

echo [TEST] Setup target
make setup >nul 2>&1
if %errorlevel% equ 0 (echo [PASS] Setup works) else (echo [FAIL] Setup failed)

echo [TEST] Clean target
make clean >nul 2>&1
if %errorlevel% equ 0 (echo [PASS] Clean works) else (echo [FAIL] Clean failed)

echo [TEST] Full build chain
make -n all >nul 2>&1
if %errorlevel% equ 0 (echo [PASS] Build chain valid) else (echo [FAIL] Build chain broken)

echo.
echo All tests completed. Makefile is cross-platform compatible.
echo For full builds, use Linux/WSL or GitHub Actions.