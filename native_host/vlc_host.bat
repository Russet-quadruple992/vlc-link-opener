@echo off
:: 1. Try virtual environment Python first
if exist "%~dp0..\.venv\Scripts\python.exe" (
    "%~dp0..\.venv\Scripts\python.exe" "%~dp0vlc_host.py" %*
    exit /b
)

:: 2. Try 'python' command from system PATH
where python >nul 2>nul
if %errorlevel% equ 0 (
    python "%~dp0vlc_host.py" %*
    exit /b
)

:: 3. Try 'py' launcher (standard Windows Python installer launcher)
where py >nul 2>nul
if %errorlevel% equ 0 (
    py "%~dp0vlc_host.py" %*
    exit /b
)

:: 4. Try standard local AppData installation path (if Python was installed without 'Add to PATH' checked)
for /d %%d in ("%USERPROFILE%\AppData\Local\Programs\Python\Python*") do (
    if exist "%%d\python.exe" (
        "%%d\python.exe" "%~dp0vlc_host.py" %*
        exit /b
    )
)

:: 5. If all lookups fail, log error to stderr (using >&2 to avoid corrupting Chrome's stdout channel)
echo ERROR: Python executable was not found on this system. >&2
exit /b 1
