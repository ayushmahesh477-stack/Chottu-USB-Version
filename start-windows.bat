@echo off
title Chottu AI - Launcher with Jarvis Mode
color 0A

echo ===================================================
echo     Launching Chottu AI with Jarvis Mode...       
echo ===================================================

:: -------------------------------------------------------
:: IMPORTANT: All paths must point to USB, not the PC!
:: -------------------------------------------------------

:: Set Ollama model data path to the USB drive
set "OLLAMA_MODELS=%~dp0ollama\data"

:: Tell Chottu (formerly AnythingLLM) to store ALL its data on the USB
:: STORAGE_DIR is the official storage path for Chottu
set "STORAGE_DIR=%~dp0chottu_data"
set "CHOTTU_PROFILE=%STORAGE_DIR%\chottu-desktop"
set "ROAMING_PROFILE=%USERPROFILE%\AppData\Roaming\chottu-desktop"
set "PROFILE_BACKUP=%USERPROFILE%\AppData\Roaming\chottu-desktop.host-backup"

:: Also override APPDATA AND XDG paths for Electron safety net
set "APPDATA=%~dp0chottu_data"
set "LOCALAPPDATA=%~dp0chottu_data"

:: Create the data folder on USB if it doesn't exist
if not exist "%~dp0chottu_data" mkdir "%~dp0chottu_data"
if not exist "%CHOTTU_PROFILE%" mkdir "%CHOTTU_PROFILE%"

:: -------------------------------------------------------
:: ENSURE CHOTTU USES EXTERNAL OLLAMA (not built-in)
:: -------------------------------------------------------
set "ENV_FILE=%~dp0chottu_data\storage\.env"
if not exist "%~dp0chottu_data\storage" mkdir "%~dp0chottu_data\storage"

:: Read the first model from installed-models.txt if it exists
set "DEFAULT_MODEL=nemomix-local"
if exist "%~dp0models\installed-models.txt" (
    for /f "usebackq tokens=1 delims=|" %%a in ("%~dp0models\installed-models.txt") do (
        set "DEFAULT_MODEL=%%a"
        goto :GotModel
    )
)
:GotModel

:: Check if .env needs fixing (missing or using built-in ollama)
set "NEEDS_FIX=0"
if not exist "%ENV_FILE%" set "NEEDS_FIX=1"
if exist "%ENV_FILE%" (
    findstr /C:"LLM_PROVIDER=ollama" "%ENV_FILE%" >nul 2>&1
    if errorlevel 1 (
        findstr /C:"LLM_PROVIDER=anythingllm_ollama" "%ENV_FILE%" >nul 2>&1
        if not errorlevel 1 set "NEEDS_FIX=1"
    )
)

if "%NEEDS_FIX%"=="1" (
    echo Configuring Chottu to use external Ollama engine...
    (
        echo LLM_PROVIDER=ollama
        echo OLLAMA_BASE_PATH=http://127.0.0.1:11434
        echo OLLAMA_MODEL_PREF=%DEFAULT_MODEL%
        echo OLLAMA_MODEL_TOKEN_LIMIT=4096
        echo EMBEDDING_ENGINE=native
        echo VECTOR_DB=lancedb
    ) > "%ENV_FILE%"
    echo Done. Default model: %DEFAULT_MODEL%
)

:: -------------------------------------------------------
:: PROFILE REDIRECT PREVENTED
:: -------------------------------------------------------
:: Electron '--user-data-dir' completely overrides profile creation,
:: ensuring Everything is purely portable on the USB drive.


:: -------------------------------------------------------
:: SHOW INSTALLED MODELS
:: -------------------------------------------------------
if exist "%~dp0models\installed-models.txt" (
    echo.
    echo Installed models:
    for /f "usebackq tokens=1,2,3 delims=|" %%a in ("%~dp0models\installed-models.txt") do (
        echo   - %%b [%%c]
    )
    echo.
)

:: Start Ollama Engine silently in the background
echo Starting Ollama Engine...
start "" /B "%~dp0ollama\ollama.exe" serve

:: Give it a few seconds to boot up
timeout /t 3 >nul

:: Find and launch Chottu (formerly AnythingLLM)
echo Starting Chottu AI Interface...

if exist "%~dp0chottu\Chottu.exe" (
    set "APP_PATH=%~dp0chottu\Chottu.exe"
    goto LaunchApp
)

:: Also check for original AnythingLLM name (fallback for compatibility)
if exist "%~dp0chottu\AnythingLLM.exe" (
    set "APP_PATH=%~dp0chottu\AnythingLLM.exe"
    goto LaunchApp
)

echo.
echo ERROR: Chottu was not found in 'chottu' folder!
echo.
echo Directory Listing for Diagnostic:
dir "%~dp0chottu"
echo.
echo Please run install.bat first to download and extract everything.
echo.
pause
exit /b

:LaunchApp
:: CRITICAL: We MUST wipe Electron path caches for true portability!
:: This fixes the "JavaScript error (ENOENT)" when moving USBs between PCs.
if exist "%~dp0chottu_data\config.json" del /q "%~dp0chottu_data\config.json"
if exist "%~dp0chottu_data\Cache" rmdir /s /q "%~dp0chottu_data\Cache"
if exist "%~dp0chottu_data\Code Cache" rmdir /s /q "%~dp0chottu_data\Code Cache"
if exist "%~dp0chottu_data\GPUCache" rmdir /s /q "%~dp0chottu_data\GPUCache"

:: CRITICAL: We MUST pushd into the app directory for the portable app to find its own resources!
pushd "%~dp0chottu"
:: Pass --user-data-dir 
start "" "Chottu.exe" --user-data-dir="%~dp0chottu_data"
popd

:Running
echo.
echo ===================================================
echo   CHOTTU ONLINE: Your AI is running from the USB!  
echo ===================================================
echo.
echo You can now use the Chottu window to chat.
echo.

:: ===================================================
:: JARVIS COMMAND MODE - INTEGRATED
:: ===================================================

:: Check if Python and Jarvis bridge are available
set "JARVIS_AVAILABLE=0"
python --version >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%~dp0chottu_bridge.py" (
        set "JARVIS_AVAILABLE=1"
    )
)

if "%JARVIS_AVAILABLE%"=="1" (
    echo.
    echo ===================================================
    echo     🦾 JARVIS COMMAND MODE ACTIVE 🦾
    echo ===================================================
    echo.
    echo You can type commands directly here:
    echo   • open notepad          - Launch applications
    echo   • open website google   - Open websites
    echo   • find report           - Search for files
    echo   • battery               - Check battery status
    echo   • memory                - Check RAM usage
    echo   • what time is it       - Get current time
    echo   • who are you           - About Chottu
    echo   • help                  - Show all commands
    echo.
    echo Or just ask questions normally!
    echo The Chottu window also stays open for chatting.
    echo.
    echo ===================================================
    echo.
    echo Tip: Type 'exit' to shut down everything.
    echo.
    
    :: Launch Jarvis command loop
    python "%~dp0chottu_bridge.py"
    
) else (
    echo.
    echo ===================================================
    echo   ℹ️  JARVIS MODE NOT AVAILABLE
    echo ===================================================
    echo.
    echo To enable Jarvis commands, install:
    echo   1. Python from python.org
    echo   2. Run: pip install psutil requests
    echo   3. Create chottu_bridge.py on USB
    echo.
    echo For now, you can still chat in the Chottu window.
    echo.
    echo Keep this black window open to keep the AI engine running!
    echo.
    echo TIP: Go to Settings ^> LLM to switch between models.
    echo.
    echo Press any key to SHUT DOWN Chottu AI safely...
    echo.
    pause >nul
)

:: Clean shutdown
taskkill /F /IM "ollama.exe" >nul 2>&1
taskkill /F /IM "Chottu.exe" >nul 2>&1
taskkill /F /IM "AnythingLLM.exe" >nul 2>&1
echo.
echo Chottu AI Engine shut down. You may safely eject the USB.
timeout /t 3 >nul