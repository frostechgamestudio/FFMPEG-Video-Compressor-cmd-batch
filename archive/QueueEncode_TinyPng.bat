@echo off
setlocal enabledelayedexpansion
set start=%time%

REM Default configuration
set "maxColors=256"
set "ditherMode=5"
set "ditherName=sierra3"
set "paletteMode=full"
set "enableTransparency=1"
set "processAllDithers=0"

REM Prompt user for max colors (2-256)
set /p maxColors=Set the maximum number of colors (2-256) [default: 256]: 
set /a maxColors=maxColors
if %maxColors% lss 2 set maxColors=2
if %maxColors% gtr 256 set maxColors=256

REM Prompt for transparency usage
echo Enable transparency?
choice /c YN /n /m "(Y)es or (N)o [default: Yes]: "
set "transparencyChoice=!errorlevel!"
if !transparencyChoice! equ 2 (
    set "enableTransparency=0"
) else (
    set "enableTransparency=1"
)

REM Prompt for processing all dither modes
echo Process all dither modes?
choice /c YN /n /m "(Y)es or (N)o [default: No]: "
set "ditherChoice=!errorlevel!"
if !ditherChoice! equ 2 (
    set "processAllDithers=0"
) else (
    set "processAllDithers=1"
)

REM If not processing all dither modes, prompt for specific mode
if "!processAllDithers!"=="0" (
    echo Dithering mode options:
    echo   1=bayer, 2=heckbert, 3=floyd, 4=sierra2
    echo   5=sierra2_4a, 6=sierra3, 7=burkes, 8=atkinson
    choice /c 12345678 /n /m "Select dither mode (1-8) [default: 6]: "
    set "ditherMode=!errorlevel!"
)

REM Map dither mode number to name
if "%ditherMode%"=="1" set "ditherName=bayer"
if "%ditherMode%"=="2" set "ditherName=heckbert"
if "%ditherMode%"=="3" set "ditherName=floyd"
if "%ditherMode%"=="4" set "ditherName=sierra2"
if "%ditherMode%"=="5" set "ditherName=sierra2_4a"
if "%ditherMode%"=="6" set "ditherName=sierra3"
if "%ditherMode%"=="7" set "ditherName=burkes"
if "%ditherMode%"=="8" set "ditherName=atkinson"

REM Display processing configuration
if "%processAllDithers%"=="0" (
    echo Processing PNG files with %maxColors% colors, %paletteMode% palette mode, and %ditherName% dithering...
) else (
    echo Processing PNG files with %maxColors% colors and all dithering methods...
)

REM Process each PNG file in Input folder and save to Output folder
if not exist "Input\" (
    echo Error: Input folder does not exist.
    goto eof
)
if not exist "Output\" mkdir "Output\"
for %%F in (Input\*.png) do (
    echo Processing %%~nF.png...

    REM Generate optimized palette
    ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -vf "palettegen=stats_mode=%paletteMode%:max_colors=%maxColors%:reserve_transparent=%enableTransparency%" -y "Output\%%~nF_palette.png"
    
    if "%processAllDithers%"=="0" (
        REM Apply selected dithering method
        ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -i "Output\%%~nF_palette.png" -lavfi "paletteuse=dither=%ditherName%" -compression_level 9 -y "Output\%%~nF_%ditherName%.png"
        if errorlevel 1 echo Error processing %%F with %ditherName% dithering && goto eof
    ) else (
        REM Generate all dither variations
        if not exist "Output\%%~nF_dithers" mkdir "Output\%%~nF_dithers"
        ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -i "Output\%%~nF_palette.png" -lavfi "paletteuse=dither=1" -compression_level 9 -y "Output\%%~nF_dithers\%%~nF_bayer.png"
        ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -i "Output\%%~nF_palette.png" -lavfi "paletteuse=dither=2" -compression_level 9 -y "Output\%%~nF_dithers\%%~nF_heckbert.png"
        ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -i "Output\%%~nF_palette.png" -lavfi "paletteuse=dither=3" -compression_level 9 -y "Output\%%~nF_dithers\%%~nF_floyd.png"
        ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -i "Output\%%~nF_palette.png" -lavfi "paletteuse=dither=4" -compression_level 9 -y "Output\%%~nF_dithers\%%~nF_sierra2.png"
        ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -i "Output\%%~nF_palette.png" -lavfi "paletteuse=dither=5" -compression_level 9 -y "Output\%%~nF_dithers\%%~nF_sierra2_4a.png"
        ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -i "Output\%%~nF_palette.png" -lavfi "paletteuse=dither=6" -compression_level 9 -y "Output\%%~nF_dithers\%%~nF_sierra3.png"
        ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -i "Output\%%~nF_palette.png" -lavfi "paletteuse=dither=7" -compression_level 9 -y "Output\%%~nF_dithers\%%~nF_burkes.png"
        ffmpeg -hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err -i "%%F" -i "Output\%%~nF_palette.png" -lavfi "paletteuse=dither=8" -compression_level 9 -y "Output\%%~nF_dithers\%%~nF_atkinson.png"
        echo Created all dither variations in folder: Output\%%~nF_dithers
    )
    REM del "Output\%%~nF_palette.png"
)

:eof
REM Calculate and display elapsed time
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
echo Command took %hours%:%mins%:%secs%.%ms% (%totalsecs%.%ms%s total)

pause