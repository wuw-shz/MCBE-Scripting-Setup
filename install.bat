@echo off
setlocal

powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/wuw-shz/MCBE-Scripting-Setup/powershell/install.ps1' -UseBasicParsing | Select-Object -ExpandProperty Content | Invoke-Expression"

endlocal