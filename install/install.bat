@echo off
REM ────────────────────────────────────────────────────────────────
REM  TerminalStack — WezTerm Config Installer (Stackschmiede)
REM  Wrapper: startet install.ps1 mit passender ExecutionPolicy.
REM ────────────────────────────────────────────────────────────────

setlocal
set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%install.ps1"

if not exist "%PS1%" (
  echo [X] install.ps1 nicht gefunden: %PS1%
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "RC=%ERRORLEVEL%"

endlocal & exit /b %RC%
