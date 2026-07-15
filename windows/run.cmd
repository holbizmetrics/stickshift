@echo off
rem StickShift for Windows — build and launch the gearbox in one step.
rem Usage: run.cmd [--target "<window-title-substring>"]
rem Requires the .NET 10 SDK (https://dotnet.microsoft.com/download).
rem No SDK? Use publish.cmd once on any machine that has it, then share the
rem self-contained exes it produces.

where dotnet >nul 2>nul
if errorlevel 1 (
  echo This needs the .NET 10 SDK: https://dotnet.microsoft.com/download
  pause
  exit /b 1
)

cd /d "%~dp0"
dotnet build StickShift.Windows.slnx -c Release --nologo
if errorlevel 1 (
  echo Build failed — see errors above.
  pause
  exit /b 1
)

start "" "StickShift.App\bin\Release\net10.0-windows\StickShiftGearbox.exe" %*
