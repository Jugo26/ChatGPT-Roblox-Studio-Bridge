@echo off
chcp 65001 >nul
cd /d "%~dp0"
python install.py
if errorlevel 1 (echo Falha na instalacao & pause & exit /b 1)
echo Roblox Studio Bridge instalado. Abra Plugins > ChatGPT Bridge > CONECTAR.
python bridge.py
pause
