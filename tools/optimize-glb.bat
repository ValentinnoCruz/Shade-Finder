@echo off
REM Drag a .glb file onto this .bat to optimize it (meshopt + WebP).
REM The optimized copy is written next to the original as "<name>-optimized.glb".

if "%~1"=="" (
    echo.
    echo   Drag a .glb file onto this file to optimize it.
    echo   Or run optimize-glb.ps1 directly in PowerShell.
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0optimize-glb.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0optimize-glb.ps1" -InputPath "%~1"
)

echo.
pause
