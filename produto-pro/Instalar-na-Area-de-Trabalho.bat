@echo off
title Instalar RickEA Relatorio Pro
cd /d "%~dp0"

if not exist "RelatorioPro-RickEA.html" (
  echo.
  echo  ERRO: o arquivo RelatorioPro-RickEA.html precisa estar na mesma pasta deste instalador.
  echo  Extraia o .zip inteiro antes de rodar.
  echo.
  pause
  exit /b 1
)

set "DEST=%LOCALAPPDATA%\RickEA\RelatorioPro"
if not exist "%DEST%" mkdir "%DEST%"
copy /y "RelatorioPro-RickEA.html" "%DEST%\RelatorioPro-RickEA.html" >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$d=[Environment]::GetFolderPath('Desktop');" ^
  "$s=(New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $d 'RickEA Relatorio Pro.lnk'));" ^
  "$s.TargetPath=Join-Path $env:LOCALAPPDATA 'RickEA\RelatorioPro\RelatorioPro-RickEA.html';" ^
  "$s.Description='RickEA Relatorio de Performance Pro';" ^
  "$s.Save()"

if errorlevel 1 (
  echo.
  echo  Nao consegui criar o atalho. Copie o arquivo RelatorioPro-RickEA.html
  echo  para a Area de Trabalho manualmente - ele funciona do mesmo jeito.
  echo.
  pause
  exit /b 1
)

echo.
echo  Pronto! O atalho "RickEA Relatorio Pro" esta na sua Area de Trabalho.
echo  Clique duas vezes nele e arraste o ReportHistory do MT5 para a janela.
echo.
pause
