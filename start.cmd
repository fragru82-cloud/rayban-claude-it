@echo off
rem Avvia RayBan Claude (basta un doppio clic)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1" %*
