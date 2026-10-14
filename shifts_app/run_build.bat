@echo off
cd /d "c:\Users\tlhol\OneDrive\Documents\shift-reminders-1\shifts_app"
"C:\Users\tlhol\Downloads\flutter\bin\flutter.bat" build apk --debug > build_output.txt 2>&1
echo Exit: %errorlevel% >> build_output.txt
