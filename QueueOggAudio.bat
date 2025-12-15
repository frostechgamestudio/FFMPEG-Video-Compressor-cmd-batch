@echo off
setlocal enabledelayedexpansion
set start=%time%

echo Audio Conversion to OGG/Opus Format
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

:: Set parameters
set "preParam=-hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err"

cls
echo.
echo =========================================
echo "Converting audio files to OGG/Opus format"
echo "Codec: libopus"
echo "Bitrate: 196k"
echo "Packet Loss: 10"
echo =========================================
echo Starting conversion...
echo.

:: Process audio files recursively through all subfolders
for /r "Input" %%F in (*.mp3 *.wav *.ogg *.flac *.aac *.m4a) do (
    set "inputFile=%%F"
    set "fileName=%%~nF"
    set "fileDir=%%~dpF"
    
    :: Calculate relative path from Input folder
    set "relativePath=!fileDir:*Input\=!"
    if "!relativePath!"=="!fileDir!" set "relativePath="
    
    :: Create output directory structure
    set "outputDir=Output\!relativePath!"
    if not exist "!outputDir!" mkdir "!outputDir!" 2>nul
    
    :: Display processing info with relative path
    if "!relativePath!"=="" (
        echo Processing: %%~nxF
    ) else (
        echo Processing: !relativePath!%%~nxF
    )
    
    :: Convert the file
    ffmpeg %preParam% -channel_layout stereo -i "%%F" -c:a libvorbis -q:a 5 -vn -dn "!outputDir!!fileName!.ogg" -y
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
echo "Conversion completed!"
echo "command took %hours%:%mins%:%secs%.%ms% (%totalsecs%.%ms%s total)"
echo.

pause