@echo off
rem StickShift for Windows — produce self-contained single-file executables.
rem Output: windows\publish\  (stickshift.exe + StickShiftGearbox.exe + gearbox.html)
rem The results run on any Windows 10/11 x64 machine with NO .NET installed —
rem zip the publish folder and share it.

where dotnet >nul 2>nul
if errorlevel 1 (
  echo This needs the .NET 10 SDK: https://dotnet.microsoft.com/download
  pause
  exit /b 1
)

cd /d "%~dp0"
dotnet publish StickShift.Cli\StickShift.Cli.csproj -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o publish
if errorlevel 1 ( pause & exit /b 1 )
dotnet publish StickShift.App\StickShift.App.csproj -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o publish
if errorlevel 1 ( pause & exit /b 1 )

echo.
echo Done: %~dp0publish
pause
