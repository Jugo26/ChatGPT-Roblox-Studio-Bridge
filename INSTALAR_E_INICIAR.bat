@echo off
chcp 65001 >nul
cd /d "%~dp0"
python install.py
if errorlevel 1 (echo Falha na instalacao & pause & exit /b 1)
python studio_agent.py start
if errorlevel 1 (echo Falha ao iniciar a ponte & pause & exit /b 1)
echo Ponte instalada e iniciada. No Roblox Studio: Plugins > ChatGPT Bridge > CONECTAR.
pause
