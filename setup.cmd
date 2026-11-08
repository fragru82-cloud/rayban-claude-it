@echo off
rem Installa RayBan Claude (basta un doppio clic)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
pause
