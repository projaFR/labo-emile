@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
set "EXE=build\windows\x64\runner\Release\labo_emile.exe"
if not exist "%EXE%" (
  echo Le Labo n'est pas encore compile pour Windows.
  echo Il faut d'abord faire, dans ce dossier : flutter build windows --release
  pause
  exit /b 1
)
start "" "%EXE%"
exit /b 0
