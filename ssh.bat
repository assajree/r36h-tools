@echo off
title R36H SSH Connection
color 0B

set DEFAULT_IP=192.168.1.9
set TARGET_USER=ark

echo ===================================================
echo               SSH Quick Connect
echo ===================================================
echo.
set /p TARGET_IP="Enter Device IP (Press Enter for %DEFAULT_IP%): "
if "%TARGET_IP%"=="" set TARGET_IP=%DEFAULT_IP%

echo.
echo Connecting to %TARGET_USER%@%TARGET_IP% ...
echo (Default Password: ark)
echo.

ssh.exe %TARGET_USER%@%TARGET_IP%

echo.
echo Connection closed.
pause