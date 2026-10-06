@echo off
setlocal
rem DRAGON_BUILD=6
title Dragon Bowling S905L - Gerar APK Android
cd /d "%~dp0"

echo ============================================================
echo   DRAGON BOWLING - BUILD 1 - TV BOX S905L (ANDROID 7.1) - GODOT 3.6
echo   GERA O APK COMPLETO (PLUGIN USB DOS LEDS + JOGO)
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\gerar_apk\GERAR_APK_COMPLETO.ps1"
if errorlevel 1 (
  echo.
  echo FALHA: o APK nao foi criado. Fotografe esta janela inteira.
  pause
  exit /b 1
)

echo.
echo SUCESSO. APK criado em:
echo %~dp0build\android\DragonBowling-S905L.apk
echo.
echo Copie o APK para o pendrive e instale na TV Box.
pause
exit /b 0
