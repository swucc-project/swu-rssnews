@echo off
REM ═══════════════════════════════════════════════════════════
REM Quick Start Wrapper - Improved Version (Fixed)
REM ═══════════════════════════════════════════════════════════
setlocal EnableDelayedExpansion

echo.
echo ===========================================================
echo   SWU RSS News System - Quick Start (Windows)
echo ===========================================================
echo.

REM ───────────────────────────────────────────────────────────
REM Check Docker Desktop
REM ───────────────────────────────────────────────────────────
echo [1/4] Checking Docker...

REM Check if Docker command exists
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not installed!
    echo Please install Docker Desktop
    pause
    exit /b 1
)

REM Check if Docker daemon is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Desktop is not running!
    echo.
    echo Please follow these steps:
    echo   1. Open Docker Desktop application
    echo   2. Wait until it is fully started
    echo   3. Run this script again
    echo.
    pause
    exit /b 1
)
echo       [OK] Docker Desktop is running
echo.

REM ───────────────────────────────────────────────────────────
REM Find PowerShell
REM ───────────────────────────────────────────────────────────
echo [2/4] Detecting PowerShell...

set "PS_CMD="
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    set "PS_CMD=pwsh"
    echo       [OK] Using PowerShell Core (pwsh)
    goto :ps_found
)

where powershell >nul 2>&1
if %errorlevel% equ 0 (
    set "PS_CMD=powershell"
    echo       [OK] Using Windows PowerShell
    goto :ps_found
)

echo [ERROR] PowerShell not found!
pause
goto :EOF

:ps_found
echo.

REM ───────────────────────────────────────────────────────────
REM Locate script file
REM ───────────────────────────────────────────────────────────
echo [3/4] Locating PowerShell script...

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%quick-start.ps1"

REM Remove trailing backslash if present
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] Script not found: %PS_SCRIPT%
    echo.
    echo Expected location: %SCRIPT_DIR%\quick-start.ps1
    echo Current directory: %CD%
    echo.
    pause
    goto :EOF
)
echo       [OK] Found: quick-start.ps1
echo.

REM ───────────────────────────────────────────────────────────
REM Execute PowerShell script with Skip Docker Check
REM ───────────────────────────────────────────────────────────
echo [4/4] Running quick-start.ps1...
echo       (Docker check already passed, skipping in PowerShell)
echo.
echo ───────────────────────────────────────────────────────────
echo.

REM Pass -SkipDockerCheck parameter to avoid duplicate checking
%PS_CMD% -ExecutionPolicy Bypass -NoProfile -File "%PS_SCRIPT%" -SkipDockerCheck %*

set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo ───────────────────────────────────────────────────────────
echo.

if %EXIT_CODE% NEQ 0 (
    echo [ERROR] Script failed with exit code: %EXIT_CODE%
    echo.
    echo Troubleshooting steps:
    echo   1. Ensure Docker Desktop is running
    echo   2. Check you have sufficient permissions
    echo   3. Try: docker compose down -v
    echo   4. Check logs: docker compose logs
    echo.
    pause
    goto :EOF
)

echo [SUCCESS] Quick start completed successfully!
echo.
echo Next steps:
echo   • Application: http://localhost:5000
echo   • Health check: http://localhost:5000/health
echo   • View logs: docker compose logs -f
echo.
pause
goto :EOF