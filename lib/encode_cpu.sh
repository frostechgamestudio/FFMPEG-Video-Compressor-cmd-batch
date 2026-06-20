#!/usr/bin/env bash

# ===== CPU FALLBACK ENCODER SUB-SCRIPT =====
# Accepts parameters: format audio quality fps scale
#   format: h264 | hevc
#   audio:  1 (include) | 2 (no audio)
#   quality: CQ/CRF numeric value
#   fps: target frame rate
#   scale: percentage (100 = original)

set -u

FORMAT="${1:-h264}"
AUDIO="${2:-1}"
QUALITY="${3:-23}"
FPS="${4:-60}"
SCALE="${5:-100}"

BASE_PARAMS="-hide_banner -loglevel warning -stats -nostdin"
OUTPUT_PARAMS="-movflags faststart"

if [ "$SCALE" = "100" ]; then
    SCALE_FILTER=""
else
    SCALE_FILTER="-vf scale=w=iw*${SCALE}/100:h=ih*${SCALE}/100:flags=lanczos"
fi

if [ "$AUDIO" = "1" ]; then
    AUDIO_PARAMS="-c:a aac -q:a 0.75"
else
    AUDIO_PARAMS="-an"
fi

process_file() {
    local input="$1"
    local output_dir="$2"
    local filename="$3"

    local temp_hevc output_file

    if [ "${FORMAT}" = "h264" ]; then
        temp_hevc="${output_dir}/${filename}_temp_hevc.mp4"
        output_file="${output_dir}/${filename}.mp4"

        echo "  Process 1/2: HEVC encoding (CPU fallback)..."
        ffmpeg ${BASE_PARAMS} -i "${input}" ${SCALE_FILTER} \
            -c:v libx265 -preset slow -crf "${QUALITY}" \
            -r "${FPS}" ${AUDIO_PARAMS} ${OUTPUT_PARAMS} -y "${temp_hevc}"

        if [ $? -eq 0 ]; then
            echo "  Process 2/2: H.264 encoding from HEVC..."
            ffmpeg ${BASE_PARAMS} -i "${temp_hevc}" \
                -c:v libx264 -preset slow -crf "${QUALITY}" \
                ${AUDIO_PARAMS} ${OUTPUT_PARAMS} -y "${output_file}"
            rm -f "${temp_hevc}"
        else
            echo "  Error in HEVC encoding, skipping H.264 process"
            rm -f "${temp_hevc}"
        fi
    elif [ "${FORMAT}" = "hevc" ]; then
        output_file="${output_dir}/${filename}.mp4"
        ffmpeg ${BASE_PARAMS} -i "${input}" ${SCALE_FILTER} \
            -c:v libx265 -preset slow -crf "${QUALITY}" \
            -r "${FPS}" ${AUDIO_PARAMS} ${OUTPUT_PARAMS} -y "${output_file}"
    fi

    rm -f "ffmpeg2pass-0.log"
}

# ===== PROCESS FILES =====
find "Input" -type f \( \
    -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o \
    -iname "*.mov" -o -iname "*.wmv" -o -iname "*.webm" -o \
    -iname "*.flv" -o -iname "*.m4v" -o -iname "*.ts" -o \
    -iname "*.mts" -o -iname "*.mpeg" -o -iname "*.mpg" \
\) | while IFS= read -r file; do

    rel_dir=$(dirname "${file}" | sed 's#^Input/*##')
    output_dir="Output/${rel_dir}"
    mkdir -p "${output_dir}"

    filename=$(basename "${file}")
    name="${filename%.*}"

    if [ -z "${rel_dir}" ]; then
        echo "Processing: ${filename}"
    else
        echo "Processing: ${rel_dir}/${filename}"
    fi

    process_file "${file}" "${output_dir}" "${name}"
done