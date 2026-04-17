@echo off
setlocal
set "WRAPPER_PS1=%~dp0claude.ps1"

if exist "%WRAPPER_PS1%" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%WRAPPER_PS1%" %*
  exit /b %errorlevel%
)

echo Claude cache-fix wrapper not found at "%WRAPPER_PS1%". 1>&2
exit /b 1
