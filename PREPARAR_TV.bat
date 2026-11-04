@echo off
setlocal
cd /d "%~dp0"
title Dragon Bowling - Preparar a TV (so o jogo, sempre ligado)
rem PREPARA A TV PELO ADB (placa da TV - Google TV / Android TV - ou TV Box,
rem Android 7.1 a 14), uma vez por TV:
rem  - instala o APK de APK-Pronto na memoria interna (se o jogo ja esta na
rem    TV, pelo pendrive, nao mexe);
rem  - o jogo vira a TELA INICIAL e as outras telas da TV sao desligadas (no
rem    Google TV, a tela do Google TV e o assistente que a religaria): ao
rem    ligar, a TV abre SO o jogo;
rem  - TV sempre ligada: sem descanso de tela e sem desligar por inatividade;
rem  - confere tudo e diz TV PRONTA (ou o que faltou). Nada aparece na TV,
rem    menos "Permitir depuracao?" na 1a conexao.
rem Na TV, antes: Configuracoes > Sistema > Sobre > clique 7 vezes em
rem "Build do SO do Android TV" > Configuracoes > Sistema > Opcoes do
rem desenvolvedor > Depuracao USB LIGADA. PC e TV na mesma rede.
rem Opcoes (opcionais):
rem   PREPARAR_TV.bat -Ip 192.168.0.50     (o IP da TV; sem ele, pergunta)
rem   PREPARAR_TV.bat -DevolverTv          (desfaz: a TV volta a ser TV)
rem   PREPARAR_TV.bat -ManterTelaDaTv      (nao desliga a tela da TV)
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
