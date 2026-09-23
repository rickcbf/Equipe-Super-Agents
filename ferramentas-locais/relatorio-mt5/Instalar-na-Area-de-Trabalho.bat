@echo off
title Instalar Relatorio MT5 - RickEA
cd /d "%~dp0"

if not exist "RelatorioMT5-RickEA.html" (
  echo.
  echo  ERRO: o arquivo RelatorioMT5-RickEA.html precisa estar na mesma pasta deste instalador.
  echo  Extraia o .zip inteiro antes de rodar.
  echo.
  pause
  exit /b 1
)

set "DEST=%LOCALAPPDATA%\RickEA\RelatorioMT5"
if not exist "%DEST%" mkdir "%DEST%"
copy /y "RelatorioMT5-RickEA.html" "%DEST%\RelatorioMT5-RickEA.html" >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$d=[Environment]::GetFolderPath('Desktop');" ^
  "$s=(New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $d 'Relatorio MT5 - RickEA.lnk'));" ^
  "$s.TargetPath=Join-Path $env:LOCALAPPDATA 'RickEA\RelatorioMT5\RelatorioMT5-RickEA.html';" ^
  "$s.Description='Relatorio de performance do MT5 - RickEA';" ^
  "$s.Save()"

if errorlevel 1 (
  echo.
  echo  Nao consegui criar o atalho. Copie o arquivo RelatorioMT5-RickEA.html
  echo  para a Area de Trabalho manualmente - ele funciona do mesmo jeito.
  echo.
  pause
  exit /b 1
)

echo.
echo  Pronto! O atalho "Relatorio MT5 - RickEA" esta na sua Area de Trabalho.
echo  Clique duas vezes nele e arraste o ReportHistory do MT5 para a janela.
echo.
pause
