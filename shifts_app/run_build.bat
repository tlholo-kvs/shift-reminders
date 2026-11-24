@echo off
cd /d "%~dp0"
"C:\Users\tlhol\Downloads\flutter\bin\flutter.bat" build apk --debug > build_output.txt 2>&1
echo Exit: %errorlevel% >> build_output.txt
