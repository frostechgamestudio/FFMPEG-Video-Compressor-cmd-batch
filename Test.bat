@echo off
setlocal enabledelayedexpansion

:: ===== FFMPEG VIDEO COMPRESSOR TEST SUITE =====
:: Generates small 4-frame blank input videos covering common edge cases so
:: every lib\ encoder mode can be exercised automatically.
::
:: Usage:
::   Test.bat              Generate test inputs in TestInput\
::   Test.bat /r           Generate inputs AND run CPU smoke tests through lib\
::   Test.bat /c           Remove TestInput\ and Output\
::   Test.bat /h           Show usage

set "TEST_DIR=TestInput"
set "OUTPUT_DIR=Output"

set "RUN_TESTS=false"
set "CLEAN_ONLY=false"

:: Parse arguments
if "%~1"=="/r" set "RUN_TESTS=true"
if "%~1"=="/R" set "RUN_TESTS=true"
if "%~1"=="/c" set "CLEAN_ONLY=true"
if "%~1"=="/C" set "CLEAN_ONLY=true"
if "%~1"=="/h" goto :show_usage
if "%~1"=="/H" goto :show_usage
if "%~1"=="/?" goto :show_usage
if "%~1"=="-h" goto :show_usage
if "%~1"=="--help" goto :show_usage

:: Clean mode
if "%CLEAN_ONLY%"=="true" (
    echo Cleaning test artifacts...
    if exist "%TEST_DIR%\" rmdir /S /Q "%TEST_DIR%"
    if exist "%OUTPUT_DIR%\" rmdir /S /Q "%OUTPUT_DIR%"
    echo Done.
    goto :end
)

:: Validate FFmpeg
where ffmpeg >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: FFmpeg not found in PATH.
    echo Install FFmpeg 7.1+ or add it to system PATH.
    echo Download: https://ffmpeg.org/download.html
    exit /b 1
)

:: Prepare test directory
if not exist "%TEST_DIR%\" mkdir "%TEST_DIR%"
del /Q "%TEST_DIR%\*" >nul 2>&1

echo Generating 4-frame blank test videos in %TEST_DIR%\...
echo.

set "FPS=30"
set "FRAMES=4"
set "BASE_FLAGS=-hide_banner -loglevel warning -stats -y"

call :generate_video "%TEST_DIR%\blank_8bit_even.mp4"     1920 1080 yuv420p     yes
call :generate_video "%TEST_DIR%\blank_8bit_odd.mp4"      1919 1079 yuv420p     yes
call :generate_video "%TEST_DIR%\blank_10bit_even.mp4"   1920 1080 yuv420p10le  yes
call :generate_video "%TEST_DIR%\blank_10bit_odd.mp4"     1919 1079 yuv420p10le  yes
call :generate_video "%TEST_DIR%\blank_8bit_no_audio.mp4" 1280  720 yuv420p     no
call :generate_video "%TEST_DIR%\blank_480p_8bit.mp4"      854  480 yuv420p     yes
call :generate_video "%TEST_DIR%\blank_8bit_avi.avi"        640  480 yuv420p     yes
call :generate_video "%TEST_DIR%\blank_8bit_mkv.mkv"        640  480 yuv420p     yes

echo.
echo Test inputs ready in %TEST_DIR%\
echo.

echo Suggested lib\ test commands (CPU fallback, safe on any system):
echo.
echo   call lib\encode_cpu.bat h264 1 23 60 100
echo   call lib\encode_cpu.bat hevc 1 23 60 100
echo   call lib\encode_cpu.bat h264 2 23 30  50
echo   call lib\encode_gif.bat cpu 2 23 15  75
echo.
echo Replace 'cpu' with 'nvidia', 'amd', or 'intel' if hardware encoders are available.
echo.

:: Smoke-test mode
if "%RUN_TESTS%"=="true" (
    echo ===== RUNNING CPU SMOKE TESTS =====

    :: Prepare Input\ with copies of the test files since lib\ scripts hardcode Input\
    :: Preserve an existing Input\ by moving it aside.
    if exist "Input\" (
        move "Input" "Input.testbak" >nul
    )
    mkdir "Input"
    xcopy /Y /Q "%TEST_DIR%\*" "Input\" >nul

    call :run_mode "lib\encode_cpu.bat" h264 1 23 60 100
    call :run_mode "lib\encode_cpu.bat" hevc 1 23 60 100
    call :run_mode "lib\encode_cpu.bat" h264 2 28 30  50
    call :run_mode "lib\encode_gif.bat" cpu 2 23 15 75

    :: Remove temporary Input\ and restore any backed-up Input\
    rmdir /S /Q "Input"
    if exist "Input.testbak\" (
        move "Input.testbak" "Input" >nul
    )

    echo.
    echo ===== SMOKE TESTS COMPLETE =====
    echo Outputs are in %OUTPUT_DIR%\
    echo Run 'Test.bat /c' to remove test artifacts.
)

goto :end

:: ===== SUBROUTINES =====

:show_usage
echo Usage: %~nx0 [OPTION]
echo.
echo Generate 4-frame blank test videos for the FFMPEG-Video-Compressor lib\ scripts.
echo.
echo Options:
echo   /r         Generate inputs and run a CPU-only smoke test through all lib\ modes
echo   /c         Remove TestInput\ and Output\
echo   /h, /?     Show this help message
echo.
echo Examples:
echo   %~nx0
echo   %~nx0 /r
echo   %~nx0 /c
goto :end

:generate_video
set "output_file=%~1"
set "width=%~2"
set "height=%~3"
set "pix_fmt=%~4"
set "with_audio=%~5"
set "size=%width%x%height%"
set "video_source=color=c=black:s=%size%:r=%FPS%"

if "%with_audio%"=="yes" (
    ffmpeg %BASE_FLAGS% -f lavfi -i "%video_source%" -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" -c:v libx264 -preset ultrafast -pix_fmt %pix_fmt% -c:a aac -q:a 0.75 -frames:v %FRAMES% -shortest "%output_file%"
) else (
    ffmpeg %BASE_FLAGS% -f lavfi -i "%video_source%" -c:v libx264 -preset ultrafast -pix_fmt %pix_fmt% -an -frames:v %FRAMES% "%output_file%"
)

if %ERRORLEVEL% equ 0 (
    echo   [OK] %~n1
) else (
    echo   [FAIL] %~n1
)
goto :eof

:run_mode
echo.
echo ^>^>^> Running: %*
call %*
goto :eof

:end
endlocal