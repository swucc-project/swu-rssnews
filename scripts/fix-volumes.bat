@echo off
REM ═══════════════════════════════════════════════════════════
REM Volume Fix Wrapper - No Execution Policy Changes Needed
REM ═══════════════════════════════════════════════════════════
echo.
echo ═══════════════════════════════════════════════════════════
echo   SQL Server Volume Fix (Windows Batch)
echo ═══════════════════════════════════════════════════════════
echo.

REM Check if PowerShell is available
where pwsh >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    where powershell >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] PowerShell not found!
        exit /b 1
    )
    set PS_CMD=powershell
) else (
    set PS_CMD=pwsh
)

echo [INFO] Using: %PS_CMD%
echo.

REM Run the PowerShell script with Bypass policy
REM FIX: %~dp0 already points to scripts folder, so no need to add "scripts\" again
echo [INFO] Running fix-volumes.ps1 with Bypass policy...
echo.

%PS_CMD% -ExecutionPolicy Bypass -File "%~dp0fix-volumes.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Volume fix failed with exit code: %ERRORLEVEL%
    echo.
    echo Troubleshooting:
    echo   1. Make sure Docker Desktop is running
    echo   2. Check if you have sufficient permissions
    echo   3. Try: docker volume ls
    echo.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Volume fix completed!
echo.
pause