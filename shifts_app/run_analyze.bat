@echo off
cd /d "%~dp0"
"C:\Users\tlhol\Downloads\flutter\bin\flutter.bat" analyze > analyze_output.txt 2>&1
echo Exit: %errorlevel% >> analyze_output.txt
