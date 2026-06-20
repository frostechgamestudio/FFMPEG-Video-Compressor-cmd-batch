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

:: Software decode -> hardware HEVC encode for the temp pass. No -hwaccel is
:: used because GPU decoders can pad odd widths, which would defeat the
:: even-dimension scale filter. Keep 4:4:4 chroma for better GIF palettes.
set "PIX_FMT=yuv444p"
set "VIDEO_FILTER=-vf scale=trunc(iw*%SCALE%/100/2)*2:trunc(ih*%SCALE%/100/2)*2:flags=lanczos,format=%PIX_FMT%"

:: Pick the first-pass HEVC encoder based on variant
set "HEVC_ENCODER="

if /I "%HW%"=="nvidia" set "HEVC_ENCODER=hevc_nvenc"
if /I "%HW%"=="amd"    set "HEVC_ENCODER=hevc_amf"
if /I "%HW%"=="intel"  set "HEVC_ENCODER=hevc_qsv"
if /I "%HW%"=="cpu"    set "HEVC_ENCODER=libx265"

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
        ffmpeg %BASE_PARAMS% -i "%%F" %VIDEO_FILTER% -c:v libx265 -preset slow -crf %QUALITY% -r %FPS% -an -sn -dn -pix_fmt yuv444p -y "!tempHevcFile!"
    ) else (
        ffmpeg %BASE_PARAMS% -i "%%F" %VIDEO_FILTER% -c:v %HEVC_ENCODER% -preset:v slow -cq %QUALITY% -r %FPS% -an -sn -dn -pix_fmt yuv444p -y "!tempHevcFile!"
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