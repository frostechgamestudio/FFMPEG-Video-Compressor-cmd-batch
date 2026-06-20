@echo off
setlocal enabledelayedexpansion
set start=%time%

:: ===== FFMPEG VIDEO COMPRESSOR =====
:: Orchestrator for Windows.
:: Picks format + hardware accelerator, then asks for audio, quality, FPS and scale.
:: Dispatches to a sub-script in lib\.

echo FFMPEG Video Compressor
echo =======================
echo.
echo Put videos into the Input\ folder.
echo Encoded files will appear in Output\.
echo.

:: Check FFmpeg availability
where ffmpeg >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: FFmpeg not found in PATH
    echo Install FFmpeg 7.1+ or add it to system PATH.
    echo Download: https://ffmpeg.org/download.html
    pause
    exit /b 1
)

:: Create required directories
if not exist "Input\" mkdir "Input"
if not exist "Output\" mkdir "Output"

:: ===== FORMAT AND HARDWARE ACCELERATOR SELECTION =====
echo =========================================
echo Select Format and Hardware Accelerator
echo =========================================
echo [1] H.264 - NVIDIA  ^(h264_nvenc^)
echo [2] H.264 - AMD     ^(h264_amf^)
echo [3] H.264 - Intel   ^(h264_qsv^)
echo [4] H.265/HEVC - NVIDIA  ^(hevc_nvenc^)
echo [5] H.265/HEVC - AMD     ^(hevc_amf^)
echo [6] H.265/HEVC - Intel   ^(hevc_qsv^)
echo [7] GIF - NVIDIA  ^(hevc_nvenc first pass^)
echo [8] GIF - AMD     ^(hevc_amf first pass^)
echo [9] GIF - Intel   ^(hevc_qsv first pass^)
echo =========================================
choice /C:123456789 /M:"Select option:"
set "menuChoice=%ERRORLEVEL%"

:: Map choice to format and sub-script
set "FORMAT="
set "HW="
set "ENCODER_CHECK="

if "%menuChoice%"=="1" (
    set "FORMAT=h264"
    set "HW=nvidia"
    set "ENCODER_CHECK=h264_nvenc"
)
if "%menuChoice%"=="2" (
    set "FORMAT=h264"
    set "HW=amd"
    set "ENCODER_CHECK=h264_amf"
)
if "%menuChoice%"=="3" (
    set "FORMAT=h264"
    set "HW=intel"
    set "ENCODER_CHECK=h264_qsv"
)
if "%menuChoice%"=="4" (
    set "FORMAT=hevc"
    set "HW=nvidia"
    set "ENCODER_CHECK=hevc_nvenc"
)
if "%menuChoice%"=="5" (
    set "FORMAT=hevc"
    set "HW=amd"
    set "ENCODER_CHECK=hevc_amf"
)
if "%menuChoice%"=="6" (
    set "FORMAT=hevc"
    set "HW=intel"
    set "ENCODER_CHECK=hevc_qsv"
)
if "%menuChoice%"=="7" (
    set "FORMAT=gif"
    set "HW=nvidia"
    set "ENCODER_CHECK=hevc_nvenc"
)
if "%menuChoice%"=="8" (
    set "FORMAT=gif"
    set "HW=amd"
    set "ENCODER_CHECK=hevc_amf"
)
if "%menuChoice%"=="9" (
    set "FORMAT=gif"
    set "HW=intel"
    set "ENCODER_CHECK=hevc_qsv"
)

:: Validate the selected encoder is available in this FFmpeg build
echo.
echo Checking selected encoder availability...
ffmpeg -encoders 2>nul | findstr /I "%ENCODER_CHECK%" >nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Selected encoder %ENCODER_CHECK% is not available.
    echo Reason: no compatible hardware encoder found in this FFmpeg build or system.
    echo Falling back to CPU encoding. Encoding will be significantly slower.
    set "HW=cpu"
)

:: ===== AUDIO SETTINGS =====
echo.
echo =========================================
echo Audio Settings
echo =========================================
echo [1] Include audio (AAC q:a 0.75)
echo [2] No audio
echo =========================================
choice /C:12 /M:"Select audio option:"
set "audioChoice=%ERRORLEVEL%"

:: ===== QUALITY SETTINGS =====
echo.
echo =========================================
echo Video Quality
echo =========================================
echo CQ/CRF value (0-51): Lower = Higher quality
echo Recommended: 18-23 (high), 24-28 (medium), 29-36 (low)
echo =========================================
set /p qualityValue="Enter quality value (default 23): "

:: Validate quality input
if "%qualityValue%"=="" set "qualityValue=23"
echo %qualityValue%| findstr /r "^[0-9][0-9]*$" >nul
if %ERRORLEVEL% neq 0 (
    echo Invalid input. Using default: 23
    set "qualityValue=23"
)

:: ===== FPS SETTINGS =====
echo.
echo =========================================
echo Frame Rate (FPS)
echo =========================================
echo Target frame rate: Higher = Smoother motion
echo Common values: 24, 30, 60, 120
echo =========================================
set /p fpsValue="Enter FPS value (default 60): "

:: Validate FPS input
if "%fpsValue%"=="" set "fpsValue=60"
echo %fpsValue%| findstr /r "^[0-9][0-9]*$" >nul
if %ERRORLEVEL% neq 0 (
    echo Invalid input. Using default: 60
    set "fpsValue=60"
)

:: ===== SCALING SETTINGS =====
echo.
echo =========================================
echo Video Scaling
echo =========================================
echo Scaling percentage (50-200)
echo 100 = Original size, 50 = Half size, 200 = Double size
echo =========================================
set /p scaleValue="Enter scale percentage (default 100): "

:: Validate scaling input
if "%scaleValue%"=="" set "scaleValue=100"
echo %scaleValue%| findstr /r "^[0-9][0-9]*$" >nul
if %ERRORLEVEL% neq 0 (
    echo Invalid input. Using default: 100
    set "scaleValue=100"
)

:: ===== DISPLAY SETTINGS AND START ENCODING =====
cls
echo =========================================
echo ENCODING SETTINGS
echo =========================================
echo Format: %FORMAT%
echo Hardware: %HW%
echo Audio: %audioChoice% ^(1=Yes, 2=No^)
echo Quality: %qualityValue%
echo FPS: %fpsValue%
echo Scale: %scaleValue%%%
echo =========================================
echo Starting encoding...
echo.

if /I "%FORMAT%"=="gif" (
    call "lib\encode_gif.bat" "%HW%" "%audioChoice%" "%qualityValue%" "%fpsValue%" "%scaleValue%"
) else (
    call "lib\encode_%HW%.bat" "%FORMAT%" "%audioChoice%" "%qualityValue%" "%fpsValue%" "%scaleValue%"
)

:: ===== CALCULATE AND DISPLAY EXECUTION TIME =====
set end=%time%
set options="tokens=1-4 delims=:.," 
for /f %options% %%a in ("%start%") do set start_h=%%a&set /a start_m=100%%b %% 100&set /a start_s=100%%c %% 100&set /a start_ms=100%%d %% 100
for /f %options% %%a in ("%end%") do set end_h=%%a&set /a end_m=100%%b %% 100&set /a end_s=100%%c %% 100&set /a end_ms=100%%d %% 100

set /a hours=%end_h%-%start_h%
set /a mins=%end_m%-%start_m%
set /a secs=%end_s%-%start_s%
set /a ms=%end_ms%-%start_ms%
if %ms% lss 0 set /a secs = %secs% - 1 & set /a ms = 100%ms%
if %secs% lss 0 set /a mins = %mins% - 1 & set /a secs = 60%secs%
if %mins% lss 0 set /a hours = %hours% - 1 & set /a mins = 60%mins%
if %hours% lss 0 set /a hours = 24%hours%
if 1%ms% lss 100 set ms=0%ms%

set /a totalsecs = %hours%*3600 + %mins%*60 + %secs%
echo.
echo =========================================
echo ENCODING COMPLETED!
echo Total time: %hours%:%mins%:%secs%.%ms% (%totalsecs%.%ms%s)
echo =========================================
echo.

pause