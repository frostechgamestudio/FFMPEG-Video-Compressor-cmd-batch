@echo off
setlocal enabledelayedexpansion

:: ===== GIF ENCODER SUB-SCRIPT =====
:: Accepts parameters: hw_variant audio quality fps scale
::   hw_variant: nvidia | amd | intel | cpu
::   audio:      1 (include) | 2 (no audio)  (ignored; GIF has no audio)
::   quality:    CQ/CRF numeric value for the HEVC first pass
::   fps:        target frame rate
::   scale:      percentage (100 = original)

set "HW=%~1"
set "AUDIO=%~2"
set "QUALITY=%~3"
set "FPS=%~4"
set "SCALE=%~5"

set "BASE_PARAMS=-hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err"

if "%SCALE%"=="100" (
    set "SCALE_FILTER="
) else (
    set "SCALE_FILTER=-vf scale=w=iw*%SCALE%/100:h=ih*%SCALE%/100:flags=lanczos"
)

:: Pick the first-pass HEVC encoder and any hardware acceleration based on variant
set "HEVC_ENCODER="
set "HWACCEL_PARAMS="
set "HWACCEL="
set "HWOUTPUT="

if /I "%HW%"=="nvidia" (
    set "HEVC_ENCODER=hevc_nvenc"
    set "HWACCEL=cuda"
    set "HWOUTPUT=cuda"
)
if /I "%HW%"=="amd" (
    set "HEVC_ENCODER=hevc_amf"
    set "HWACCEL=d3d11va"
    set "HWOUTPUT=d3d11"
)
if /I "%HW%"=="intel" (
    set "HEVC_ENCODER=hevc_qsv"
    set "HWACCEL=qsv"
    set "HWOUTPUT=qsv"
)
if /I "%HW%"=="cpu" (
    set "HEVC_ENCODER=libx265"
)

if "%SCALE%"=="100" (
    if /I "%HW%"=="nvidia" set "HWACCEL_PARAMS=-hwaccel %HWACCEL% -hwaccel_output_format %HWOUTPUT%"
    if /I "%HW%"=="amd"    set "HWACCEL_PARAMS=-hwaccel %HWACCEL% -hwaccel_output_format %HWOUTPUT%"
    if /I "%HW%"=="intel"  set "HWACCEL_PARAMS=-hwaccel %HWACCEL% -hwaccel_output_format %HWOUTPUT%"
) else (
    if /I "%HW%"=="nvidia" set "HWACCEL_PARAMS=-hwaccel %HWACCEL%"
    if /I "%HW%"=="amd"    set "HWACCEL_PARAMS=-hwaccel %HWACCEL%"
    if /I "%HW%"=="intel"  set "HWACCEL_PARAMS=-hwaccel %HWACCEL%"
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

    :: Two-process GIF encoding: HEVC first, then palette GIF variants
    set "tempHevcFile=!outputDir!!fileName!_temp_hevc.mp4"

    echo   Process 1/2: HEVC encoding for GIF...
    if /I "%HW%"=="cpu" (
        ffmpeg %BASE_PARAMS% -i "%%F" %SCALE_FILTER% -c:v libx265 -preset slow -crf %QUALITY% -r %FPS% -an -sn -dn -pix_fmt yuv444p -y "!tempHevcFile!"
    ) else (
        ffmpeg %BASE_PARAMS% %HWACCEL_PARAMS% -i "%%F" %SCALE_FILTER% -c:v %HEVC_ENCODER% -preset:v slow -cq %QUALITY% -r %FPS% -an -sn -dn -pix_fmt yuv444p -y "!tempHevcFile!"
    )

    if !ERRORLEVEL! equ 0 (
        echo   Process 2/2: Creating GIF variants...
        ffmpeg %BASE_PARAMS% -i "!tempHevcFile!" -vf "split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=1[p];[s1][p]paletteuse=dither=1" -y "!outputDir!!fileName!_bayer.gif"
        ffmpeg %BASE_PARAMS% -i "!tempHevcFile!" -vf "split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=1[p];[s1][p]paletteuse=dither=5" -y "!outputDir!!fileName!_sierra2_4a.gif"
        ffmpeg %BASE_PARAMS% -i "!tempHevcFile!" -vf "split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=1[p];[s1][p]paletteuse=dither=6" -y "!outputDir!!fileName!_sierra3.gif"
        del "!tempHevcFile!" 2>nul
    ) else (
        echo   Error in HEVC encoding, skipping GIF process
        del "!tempHevcFile!" 2>nul
    )

    :: Clean up temporary files
    del "ffmpeg2pass-0.log" 2>nul
)

endlocal
