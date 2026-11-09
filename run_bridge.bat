@echo off
chcp 65001 >nul
cd /d "%~dp0"
python studio_agent.py start
if errorlevel 1 (
    echo.
    echo Falha ao iniciar. Verifique se outra instancia esta ocupando a porta 48765.
    pause
    exit /b 1
)
echo.
echo Ponte iniciada. Abra o Roblox Studio, Plugins, ChatGPT Bridge, CONECTAR.
echo Voce pode fechar esta janela; o servidor segue ativo.
pause
