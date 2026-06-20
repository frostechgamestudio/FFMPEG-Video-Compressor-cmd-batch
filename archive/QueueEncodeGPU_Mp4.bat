@echo off
setlocal enabledelayedexpansion
set start=%time%

:: ===== GPU VIDEO ENCODER =====
:: Enhanced batch script for GPU-accelerated video encoding
:: 
:: Features:
:: - Two-process H.264 encoding (HEVC first process for better quality/size ratio)
:: - Purely for archival purposes
:: - Support for NVIDIA, AMD, and Intel GPUs
:: - Batch processing of multiple files in subdirectories, output to corresponding subdirectories
:: 
:: Compatible with FFmpeg 7.1 and uses optimized encoding pipelines

:: ===== INITIALIZATION =====
echo HEVC or Two-Process H.264 GPU encoder
echo Supports NVIDIA, AMD, and Intel GPUs
echo.

:: Check FFmpeg availability
where ffmpeg >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: FFmpeg not found in PATH
    echo Install FFmpeg or add it to system PATH
    echo Download: https://ffmpeg.org/download.html
    pause
    exit /b 1
)

:: Create required directories
if not exist "Input\" mkdir "Input"
if not exist "Output\" mkdir "Output"

:: ===== ENCODER SELECTION =====
echo =========================================
echo "(1/5) Select GPU Encoder"
echo =========================================
echo "[1] NVIDIA - h264_nvenc (Best compatibility)"
echo "[2] NVIDIA - hevc_nvenc (Best compression)"
echo "[3] AMD - h264_amf (Good compatibility)"
echo "[4] AMD - hevc_amf (Good compression)"
echo "[5] Intel - h264_qsv (Fast encoding)"
echo "[6] Intel - hevc_qsv (Efficient compression)"
echo =========================================
choice /C:123456 /M:"Select encoder:"
set "encoderChoice=%ERRORLEVEL%"

:: ===== AUDIO SETTINGS =====
echo.
echo =========================================
echo "(2/5) Audio Settings"
echo =========================================
echo "[1] Include audio (AAC 128kbps)"
echo "[2] No audio"
echo =========================================
choice /C:12 /M:"Select audio option:"
set "audioChoice=%ERRORLEVEL%"

:: ===== QUALITY SETTINGS =====
echo.
echo =========================================
echo "(3/5) Video Quality"
echo =========================================
echo "CQ/CRF value (0-51): Lower = Higher quality"
echo "Recommended: 18-23 (high), 24-28 (medium), 29-36 (low)"
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
echo "(4/5) Frame Rate (FPS)"
echo =========================================
echo "Target frame rate: Higher = Smoother motion"
echo "Common values: 24, 30, 60, 120"
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
echo "(5/5) Video Scaling"
echo =========================================
echo "Scaling percentage (50-200)"
echo "100 = Original size, 50 = Half size, 200 = Double size"
echo =========================================
set /p scaleValue="Enter scale percentage (default 100): "

:: Validate scaling input
if "%scaleValue%"=="" set "scaleValue=100"
echo %scaleValue%| findstr /r "^[0-9][0-9]*$" >nul
if %ERRORLEVEL% neq 0 (
    echo Invalid input. Using default: 100
    set "scaleValue=100"
)

:: ===== BUILD COMMAND PARAMETERS =====

:: Encoder parameters


:: Set encoder and codec based on choice
if "%encoderChoice%"=="1" (
    set "firstPassEncoder=-c:v hevc_nvenc -preset slow -profile:v main -tune uhq -cq %qualityValue%"
    set "finalEncoder=-c:v h264_nvenc -preset slow -profile:v main -tune hq -cq %qualityValue%"
    set "encoderName=NVIDIA H.264 (HEVC First Process)"
    set "hwaccel=cuda"
    set "hwOutput=cuda"
    set "twoPassH264=1"
)
if "%encoderChoice%"=="2" (
    set "encoderParam=-c:v hevc_nvenc -preset slow -profile:v main -tune uhq -cq %qualityValue%"
    set "encoderName=NVIDIA H.265/HEVC"
    set "hwaccel=cuda"
    set "hwOutput=cuda"
    set "twoPassH264=0"
)
if "%encoderChoice%"=="3" (
    set "firstPassEncoder=-c:v hevc_amf -preset quality -profile:v main -quality quality -usage high_quality -qp %qualityValue%"
    set "finalEncoder=-c:v h264_amf -preset quality -profile:v main -quality quality -usage high_quality -qp %qualityValue%"
    set "encoderName=AMD H.264 (HEVC First Process)"
    set "hwaccel=d3d11va"
    set "hwOutput=d3d11"
    set "twoPassH264=1"
)
if "%encoderChoice%"=="4" (
    set "encoderParam=-c:v hevc_amf -preset quality -profile:v main -quality quality -usage high_quality -qp %qualityValue%"
    set "encoderName=AMD H.265/HEVC"
    set "hwaccel=d3d11va"
    set "hwOutput=d3d11"
    set "twoPassH264=0"
)
if "%encoderChoice%"=="5" (
    set "firstPassEncoder=-c:v hevc_qsv -preset veryslow -profile:v main -tier main -global_quality %qualityValue%"
    set "finalEncoder=-c:v h264_qsv -preset veryslow -profile:v main -tier main -global_quality %qualityValue%"
    set "encoderName=Intel H.264 (HEVC First Process)"
    set "hwaccel=qsv"
    set "hwOutput=qsv"
    set "twoPassH264=1"
)
if "%encoderChoice%"=="6" (
    set "encoderParam=-c:v hevc_qsv -preset veryslow -profile:v main -tier main -global_quality %qualityValue%"
    set "encoderName=Intel H.265/HEVC"
    set "hwaccel=qsv"
    set "hwOutput=qsv"
    set "twoPassH264=0"
)

:: Audio parameters
if "%audioChoice%"=="1" (
    set "audioParams=-c:a aac -q:a 0.75"
) else (
    set "audioParams=-an"
)

:: Hardware acceleration and output format
if "%scaleValue%"=="100" (
    :: No scaling - use hwaccel_output_format for better performance with FPS filter
    set "scaleFilter="
    set "hwaccelParams=-hwaccel %hwaccel% -hwaccel_output_format %hwOutput%"
) else (
    :: Scaling - keep surface in system memory and combine with FPS
    set "scaleFilter=-vf scale=w=iw*%scaleValue%/100:h=ih*%scaleValue%/100:flags=lanczos"
    set "hwaccelParams=-hwaccel %hwaccel%"
)

:: Base parameters
set "baseParams=-hide_banner -loglevel warning -stats -nostdin"
set "outputParams=-movflags faststart"

:: ===== DISPLAY SETTINGS AND START ENCODING =====
cls
echo =========================================
echo ENCODING SETTINGS
echo =========================================
echo Encoder: %encoderName%
echo Audio: %audioChoice% ^(1=Yes, 2=No^)
echo Quality: %qualityValue%
echo FPS: %fpsValue%
echo Scale: %scaleValue%%%
echo =========================================
echo Starting encoding...
echo.

:: ===== PROCESS FILES =====
for /r "Input" %%F in (*.mp4 *.avi *.mkv *.mov *.wmv *.webm *.flv *.m4v *.ts *.mts *.mpeg *.mpg) do (
    set "inputFile=%%F"
    set "fileName=%%~nF"
    set "fileDir=%%~dpF"
    
    :: Calculate relative path for output structure
    set "relativePath=!fileDir:*Input\=!"
    if "!relativePath!"=="!fileDir!" set "relativePath="
    
    :: Create output directory
    set "outputDir=Output\!relativePath!"
    if not exist "!outputDir!" mkdir "!outputDir!" 2>nul
    
    :: Set output file
    set "outputFile=!outputDir!!fileName!.mp4"
    
    :: Display current file
    if "!relativePath!"=="" (
        echo Processing: %%~nxF
    ) else (
        echo Processing: !relativePath!%%~nxF
    )

    :: Check if two-process H.264 encoding is needed
    if "!twoPassH264!"=="1" (
        :: Two-process encoding: HEVC first, then H.264
        echo   Process 1/2: HEVC encoding...
        
        :: Set temporary HEVC output file
        set "tempHevcFile=!outputDir!!fileName!_temp_hevc.mp4"
        
        :: First process: Encode to HEVC
        ffmpeg %baseParams% %hwaccelParams% -i "%%F" %scaleFilter% !firstPassEncoder! -r %fpsValue% %audioParams% %outputParams% -y "!tempHevcFile!"

        if !ERRORLEVEL! equ 0 (
            echo   Process 2/2: H.264 encoding from HEVC...

            :: Second process: Re-encode HEVC to H.264
            ffmpeg %baseParams% %hwaccelParams% -i "!tempHevcFile!" !finalEncoder! %audioParams% %outputParams% -y "!outputFile!"
            
            :: Clean up temporary HEVC file
            del "!tempHevcFile!" 2>nul
        ) else (
            echo   Error in HEVC encoding, skipping H.264 process
            del "!tempHevcFile!" 2>nul
        )
    ) else (
        :: Single-process encoding (HEVC only)
        ffmpeg %baseParams% %hwaccelParams% -i "%%F" %scaleFilter% %encoderParam% -r %fpsValue% %audioParams% %outputParams% -y "!outputFile!"
    )

    :: Clean up temporary files
    del "ffmpeg2pass-0.log" 2>nul
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