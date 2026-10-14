@echo off
cd /d "c:\Users\tlhol\OneDrive\Documents\shift-reminders-1\shifts_app"
"C:\Users\tlhol\Downloads\flutter\bin\flutter.bat" analyze > analyze_output.txt 2>&1
echo Exit: %errorlevel% >> analyze_output.txt
