@echo off
title MCons for Windows
set SCRIPT_DIR=%~dp0
python "%SCRIPT_DIR%mcons_app.py" %*
