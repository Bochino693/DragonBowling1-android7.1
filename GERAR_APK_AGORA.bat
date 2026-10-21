@echo off
setlocal
cd /d "%~dp0"
title Dragon Bowling (TV Box Mali-450) - Gerar APK
rem Gera o APK da TV Box (Godot 3.6.3, OpenGL ES 2.0, Mali-450: S905L, TX9...)
rem SEM GRADLE: mostra cada passo nesta janela e guarda o historico em
rem build\android\GERACAO-COMPLETA.log. Opcoes (opcionais):
rem   GERAR_APK_AGORA.bat -Giro -1         (topo do jogo na direita do HDMI)
rem   GERAR_APK_AGORA.bat -Giro 0          (TV deitada, sem giro)
rem   GERAR_APK_AGORA.bat -Instalar        (instala na TV Box pelo adb)
rem   GERAR_APK_AGORA.bat -Versao 1.0.12-mali450
if exist "%~dp0project.godot" if exist "%~dp0tools\android\GERAR_APK.ps1" goto projeto_ok
echo.
echo ERRO: extraia o ZIP inteiro antes e rode o GERAR_APK_AGORA.bat de dentro
echo da pasta do Dragon Bowling (junto do arquivo project.godot).
echo.
pause
exit /b 1
:projeto_ok
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\android\GERAR_APK.ps1" %*
set "RESULTADO=%ERRORLEVEL%"
echo.
if "%RESULTADO%"=="0" goto sucesso
echo ============================================================
echo  NAO FOI POSSIVEL GERAR O APK. Envie o arquivo:
echo  build\android\GERACAO-COMPLETA.log
echo ============================================================
goto fim
:sucesso
echo ============================================================
echo  PRONTO: APK-Pronto\DragonBowling_Mali450.apk
echo  1a vez com esta versao: desinstale o Dragon Bowling antigo da
echo  TV Box antes de instalar (a assinatura mudou). Depois, por cima.
echo ============================================================
:fim
echo.
pause
exit /b %RESULTADO%
