@echo off
setlocal enabledelayedexpansion
set start=%time%

echo NVIDIA GPU GIF Maker
echo Using h264_nvenc for video processing
echo.

:: Check if FFmpeg is available
where ffmpeg >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo =========================================
    echo ERROR: FFmpeg is not found in your PATH.
    echo Please install FFmpeg or add it to your system PATH.
    echo You can download FFmpeg from https://ffmpeg.org/download.html
    echo.
    pause
    exit /b 1
)

:: Check if Input and Output directories exist
if not exist "Input\" (
    echo Input directory not found! Creating it...
    mkdir "Input"
)

if not exist "Output\" (
    echo Output directory not found! Creating it...
    mkdir "Output"
)

:: Hardcoded settings for streamlined workflow
set "frameRate=10"
set "crfValue=30"
set "enableDebug=false"

:: Set parameters
if "%enableDebug%"=="true" (
    set "preParam=-hide_banner -loglevel verbose -stats -nostdin -err_detect ignore_err"
) else (
    set "preParam=-hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err"
)

cls
echo.
echo =========================================
echo "GIF Maker Configuration"
echo "Frame Rate: %frameRate% FPS"
echo "Video Quality (CRF): %crfValue%"
echo "Dither Types: All (Bayer, Sierra2_4a, Sierra3)"
echo "Debug mode: %enableDebug%"
echo =========================================
echo Starting GIF creation...
echo.

:: Process all video files in Input folder
for %%F in (Input\*.mp4 Input\*.avi Input\*.mkv Input\*.mov Input\*.wmv Input\*.webm Input\*.flv Input\*.m4v Input\*.ts Input\*.mts Input\*.mpeg Input\*.mpg) do (
    echo Processing: %%~nxF
    :: First pass with hevc_nvenc
     ffmpeg %preParam% -i "%%F" -c:v hevc_nvenc -preset:v slow -cq %crfValue% -r %frameRate% -an -sn -dn -pix_fmt yuv444p -2pass 1 -y "Output\temp_%%~nF.mp4"
    
    :: Second pass to Create all 3 GIF variants
    ffmpeg %preParam% -i "Output\temp_%%~nF.mp4" -vf "split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=1[p];[s1][p]paletteuse=dither=1" -y "Output\%%~nF_bayer.gif"
    ffmpeg %preParam% -i "Output\temp_%%~nF.mp4" -vf "split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=1[p];[s1][p]paletteuse=dither=5" -y "Output\%%~nF_sierra2_4a.gif"
    ffmpeg %preParam% -i "Output\temp_%%~nF.mp4" -vf "split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=1[p];[s1][p]paletteuse=dither=6" -y "Output\%%~nF_sierra3.gif"
    
    :: Clean up temporary files
    del "Output\temp_%%~nF.mp4" 2>nul
    del "ffmpeg2pass-0.log" 2>nul
)

:: Calculate execution time
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
echo "GIF creation completed!"
echo "Command took %hours%:%mins%:%secs%.%ms% (%totalsecs%.%ms%s total)"
echo.

pause
endlocal
