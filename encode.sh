#!/usr/bin/env bash

# ===== FFMPEG VIDEO COMPRESSOR =====
# Orchestrator for Linux / macOS (Bash).
# Picks format + hardware accelerator, then asks for audio, quality, FPS and scale.
# Dispatches to a sub-script in lib/.

set -u

START_TIME=$(date +%s)

echo "FFMPEG Video Compressor"
echo "======================="
echo
echo "Put videos into the Input/ folder."
echo "Encoded files will appear in Output/."
echo

# Check FFmpeg availability
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ERROR: FFmpeg not found in PATH."
    echo "Install FFmpeg 7.1+ or add it to system PATH."
    echo "Download: https://ffmpeg.org/download.html"
    exit 1
fi

# Create required directories
mkdir -p "Input" "Output"

# ===== FORMAT AND HARDWARE ACCELERATOR SELECTION =====
echo "========================================="
echo "Select Format and Hardware Accelerator"
echo "========================================="
echo "[1] H.264 - NVIDIA  (h264_nvenc)"
echo "[2] H.264 - AMD     (h264_amf)"
echo "[3] H.264 - Intel   (h264_qsv)"
echo "[4] H.265/HEVC - NVIDIA  (hevc_nvenc)"
echo "[5] H.265/HEVC - AMD     (hevc_amf)"
echo "[6] H.265/HEVC - Intel   (hevc_qsv)"
echo "[7] GIF - NVIDIA  (hevc_nvenc first pass)"
echo "[8] GIF - AMD     (hevc_amf first pass)"
echo "[9] GIF - Intel   (hevc_qsv first pass)"
echo "========================================="

while true; do
    read -r -p "Select option (1-9): " MENU_CHOICE
    if [[ "$MENU_CHOICE" =~ ^[1-9]$ ]]; then
        break
    fi
    echo "Invalid input. Please enter a number between 1 and 9."
done

# Map choice to format and sub-script
FORMAT=""
HW=""
ENCODER_CHECK=""

case "$MENU_CHOICE" in
    1) FORMAT="h264"; HW="nvidia"; ENCODER_CHECK="h264_nvenc" ;;
    2) FORMAT="h264"; HW="amd";    ENCODER_CHECK="h264_amf" ;;
    3) FORMAT="h264"; HW="intel";  ENCODER_CHECK="h264_qsv" ;;
    4) FORMAT="hevc"; HW="nvidia"; ENCODER_CHECK="hevc_nvenc" ;;
    5) FORMAT="hevc"; HW="amd";    ENCODER_CHECK="hevc_amf" ;;
    6) FORMAT="hevc"; HW="intel";  ENCODER_CHECK="hevc_qsv" ;;
    7) FORMAT="gif";  HW="nvidia"; ENCODER_CHECK="hevc_nvenc" ;;
    8) FORMAT="gif";  HW="amd";    ENCODER_CHECK="hevc_amf" ;;
    9) FORMAT="gif";  HW="intel";  ENCODER_CHECK="hevc_qsv" ;;
esac

# Validate the selected encoder is available in this FFmpeg build
echo
echo "Checking selected encoder availability..."
if ! ffmpeg -encoders 2>/dev/null | grep -qi "^\s*V....*${ENCODER_CHECK}\s"; then
    echo "ERROR: Selected encoder ${ENCODER_CHECK} is not available."
    echo "Reason: no compatible hardware encoder found in this FFmpeg build or system."
    echo "Falling back to CPU encoding. Encoding will be significantly slower."
    HW="cpu"
fi

# ===== AUDIO SETTINGS =====
echo
echo "========================================="
echo "Audio Settings"
echo "========================================="
echo "[1] Include audio (AAC q:a 0.75)"
echo "[2] No audio"
echo "========================================="

while true; do
    read -r -p "Select audio option (1-2) [default: 1]: " AUDIO_CHOICE
    if [ -z "$AUDIO_CHOICE" ]; then
        AUDIO_CHOICE=1
    fi
    if [[ "$AUDIO_CHOICE" =~ ^[12]$ ]]; then
        break
    fi
    echo "Invalid input. Please enter 1 or 2."
done

# ===== QUALITY SETTINGS =====
echo
echo "========================================="
echo "Video Quality"
echo "========================================="
echo "CQ/CRF value (0-51): Lower = Higher quality"
echo "Recommended: 18-23 (high), 24-28 (medium), 29-36 (low)"
echo "========================================="

while true; do
    read -r -p "Enter quality value [default: 23]: " QUALITY_VALUE
    if [ -z "$QUALITY_VALUE" ]; then
        QUALITY_VALUE=23
    fi
    if [[ "$QUALITY_VALUE" =~ ^[0-9]+$ ]] && [ "$QUALITY_VALUE" -ge 0 ] && [ "$QUALITY_VALUE" -le 51 ]; then
        break
    fi
    echo "Invalid input. Using default: 23"
    QUALITY_VALUE=23
    break
done

# ===== FPS SETTINGS =====
echo
echo "========================================="
echo "Frame Rate (FPS)"
echo "========================================="
echo "Target frame rate: Higher = Smoother motion"
echo "Common values: 24, 30, 60, 120"
echo "========================================="

while true; do
    read -r -p "Enter FPS value [default: 60]: " FPS_VALUE
    if [ -z "$FPS_VALUE" ]; then
        FPS_VALUE=60
    fi
    if [[ "$FPS_VALUE" =~ ^[0-9]+$ ]] && [ "$FPS_VALUE" -gt 0 ]; then
        break
    fi
    echo "Invalid input. Using default: 60"
    FPS_VALUE=60
    break
done

# ===== SCALING SETTINGS =====
echo
echo "========================================="
echo "Video Scaling"
echo "========================================="
echo "Scaling percentage (50-200)"
echo "100 = Original size, 50 = Half size, 200 = Double size"
echo "========================================="

while true; do
    read -r -p "Enter scale percentage [default: 100]: " SCALE_VALUE
    if [ -z "$SCALE_VALUE" ]; then
        SCALE_VALUE=100
    fi
    if [[ "$SCALE_VALUE" =~ ^[0-9]+$ ]] && [ "$SCALE_VALUE" -ge 1 ]; then
        break
    fi
    echo "Invalid input. Using default: 100"
    SCALE_VALUE=100
    break
done

# ===== DISPLAY SETTINGS AND START ENCODING =====
clear 2>/dev/null || true
echo "========================================="
echo "ENCODING SETTINGS"
echo "========================================="
echo "Format: ${FORMAT}"
echo "Hardware: ${HW}"
echo "Audio: ${AUDIO_CHOICE} (1=Yes, 2=No)"
echo "Quality: ${QUALITY_VALUE}"
echo "FPS: ${FPS_VALUE}"
echo "Scale: ${SCALE_VALUE}%"
echo "========================================="
echo "Starting encoding..."
echo

if [ "${FORMAT}" = "gif" ]; then
    bash "lib/encode_gif.sh" "${HW}" "${AUDIO_CHOICE}" "${QUALITY_VALUE}" "${FPS_VALUE}" "${SCALE_VALUE}"
else
    bash "lib/encode_${HW}.sh" "${FORMAT}" "${AUDIO_CHOICE}" "${QUALITY_VALUE}" "${FPS_VALUE}" "${SCALE_VALUE}"
fi

# ===== CALCULATE AND DISPLAY EXECUTION TIME =====
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
HOURS=$((ELAPSED / 3600))
MINUTES=$(((ELAPSED % 3600) / 60))
SECONDS=$((ELAPSED % 60))

echo
echo "========================================="
echo "ENCODING COMPLETED!"
printf "Total time: %02d:%02d:%02d (%ds)\n" "$HOURS" "$MINUTES" "$SECONDS" "$ELAPSED"
echo "========================================="
echo
