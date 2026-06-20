@echo off
setlocal enabledelayedexpansion

:: ===== INTEL QSV ENCODER SUB-SCRIPT =====
:: Accepts parameters: format audio quality fps scale
::   format: h264 | hevc
::   audio:  1 (include) | 2 (no audio)
::   quality: CQ/CRF numeric value
::   fps: target frame rate
::   scale: percentage (100 = original)

set "FORMAT=%~1"
set "AUDIO=%~2"
set "QUALITY=%~3"
set "FPS=%~4"
set "SCALE=%~5"

set "BASE_PARAMS=-hide_banner -loglevel warning -stats -nostdin"
set "OUTPUT_PARAMS=-movflags faststart"

:: Software decode -> hardware QSV encode. We deliberately do not use
:: -hwaccel qsv here because the QSV decoder may pad odd widths to even
:: values, which makes the scale filter see a different input width than the
:: original file. Force 8-bit 4:2:0 output and even dimensions.
set "PIX_FMT=yuv420p"
set "VIDEO_FILTER=-vf scale=trunc(iw*%SCALE%/100/2)*2:trunc(ih*%SCALE%/100/2)*2:flags=lanczos,format=%PIX_FMT%"

if "%AUDIO%"=="1" (
    set "AUDIO_PARAMS=-c:a aac -q:a 0.75"
) else (
    set "AUDIO_PARAMS=-an"
)

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

    :: Display current file
    if "!relativePath!"=="" (
        echo Processing: %%~nxF
    ) else (
        echo Processing: !relativePath!%%~nxF
    )

    if /I "!FORMAT!"=="h264" (
        :: Two-process encoding: HEVC first, then H.264
        set "tempHevcFile=!outputDir!!fileName!_temp_hevc.mp4"
        set "outputFile=!outputDir!!fileName!.mp4"

        echo   Process 1/2: HEVC encoding...
        ffmpeg %BASE_PARAMS% -i "%%F" %VIDEO_FILTER% -c:v hevc_qsv -preset veryslow -profile:v main -tier main -global_quality %QUALITY% -r %FPS% %AUDIO_PARAMS% %OUTPUT_PARAMS% -y "!tempHevcFile!"

        if !ERRORLEVEL! equ 0 (
            echo   Process 2/2: H.264 encoding from HEVC...
            ffmpeg %BASE_PARAMS% -i "!tempHevcFile!" %VIDEO_FILTER% -c:v h264_qsv -preset veryslow -profile:v main -tier main -global_quality %QUALITY% %AUDIO_PARAMS% %OUTPUT_PARAMS% -y "!outputFile!"
            del "!tempHevcFile!" 2>nul
        ) else (
            echo   Error in HEVC encoding, skipping H.264 process
            del "!tempHevcFile!" 2>nul
        )
    ) else if /I "!FORMAT!"=="hevc" (
        :: Single-process HEVC encoding
        set "outputFile=!outputDir!!fileName!.mp4"
        ffmpeg %BASE_PARAMS% -i "%%F" %VIDEO_FILTER% -c:v hevc_qsv -preset veryslow -profile:v main -tier main -global_quality %QUALITY% -r %FPS% %AUDIO_PARAMS% %OUTPUT_PARAMS% -y "!outputFile!"
    )

    :: Clean up temporary files
    del "ffmpeg2pass-0.log" 2>nul
)

endlocal
