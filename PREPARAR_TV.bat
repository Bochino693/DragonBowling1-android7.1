@echo off
setlocal
cd /d "%~dp0"
title Dragon Bowling - Preparar a TV (abrir sozinho ao ligar)
rem PREPARA A TV PELO ADB (placa da TV ou TV Box, Android 7.1 a 14): instala
rem o APK de APK-Pronto na memoria interna, poe o jogo como TELA INICIAL
rem (abre sozinho ao ligar, ao voltar da espera e a cada HOME), permite
rem "Sobrepor a outros apps" (Android 10+) e confere tudo.
rem Na TV, antes: Configuracoes > Sistema > Sobre > clique 7 vezes em
rem "Build do SO do Android TV" > Opcoes do desenvolvedor > Depuracao USB
rem LIGADA. PC e TV na mesma rede. Opcoes (opcionais):
rem   PREPARAR_TV.bat -Ip 192.168.0.50     (o IP da TV; sem ele, pergunta)
rem   PREPARAR_TV.bat -Ip 192.168.0.50 -SoOJogo
rem        (desliga a tela inicial da TV: so o jogo abre ao ligar)
rem   PREPARAR_TV.bat -Parear 192.168.0.50:37123 -Codigo 123456 -Ip 192.168.0.50:41567
rem        (Depuracao por Wi-Fi do Android 11+: porta e codigo da tela "Parear")
if exist "%~dp0project.godot" if exist "%~dp0tools\android\GERAR_APK.ps1" goto projeto_ok
echo.
echo ERRO: extraia o ZIP inteiro antes e rode o PREPARAR_TV.bat de dentro
echo da pasta do Dragon Bowling (junto do arquivo project.godot).
echo.
pause
exit /b 1
:projeto_ok
if exist "%~dp0APK-Pronto\DragonBowling_Mali450.apk" goto apk_ok
echo.
echo ERRO: falta APK-Pronto\DragonBowling_Mali450.apk. Gere com o
echo GERAR_APK_AGORA.bat (ou copie o APK pronto para a pasta APK-Pronto).
echo.
pause
exit /b 1
:apk_ok
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\android\GERAR_APK.ps1" -PrepararTv %*
set "RESULTADO=%ERRORLEVEL%"
echo.
if "%RESULTADO%"=="0" goto fim
echo ============================================================
echo  NAO FOI POSSIVEL PREPARAR A TV. Veja a mensagem acima e envie
echo  o arquivo build\android\GERACAO-COMPLETA.log
echo ============================================================
:fim
echo.
pause
exit /b %RESULTADO%
