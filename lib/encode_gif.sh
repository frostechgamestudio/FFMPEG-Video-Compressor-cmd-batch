#!/usr/bin/env bash

# ===== GIF ENCODER SUB-SCRIPT =====
# Accepts parameters: hw_variant audio quality fps scale
#   hw_variant: nvidia | amd | intel | cpu
#   audio:      1 (include) | 2 (no audio)  (ignored; GIF has no audio)
#   quality:    CQ/CRF numeric value for the HEVC first pass
#   fps:        target frame rate
#   scale:      percentage (100 = original)

set -u

HW="${1:-nvidia}"
AUDIO="${2:-1}"
QUALITY="${3:-23}"
FPS="${4:-60}"
SCALE="${5:-100}"

BASE_PARAMS="-hide_banner -loglevel warning -stats -nostdin -err_detect ignore_err"

if [ "$SCALE" = "100" ]; then
    SCALE_FILTER=""
else
    SCALE_FILTER="-vf scale=w=iw*${SCALE}/100:h=ih*${SCALE}/100:flags=lanczos"
fi

# Pick first-pass HEVC encoder and hardware acceleration
case "${HW}" in
    nvidia)
        HEVC_ENCODER="hevc_nvenc"
        HWACCEL="cuda"
        HWOUTPUT="cuda"
        if [ "$SCALE" = "100" ]; then
            HWACCEL_PARAMS="-hwaccel ${HWACCEL} -hwaccel_output_format ${HWOUTPUT}"
        else
            HWACCEL_PARAMS="-hwaccel ${HWACCEL}"
        fi
        ;;
    amd)
        HEVC_ENCODER="hevc_amf"
        HWACCEL_PARAMS=""
        ;;
    intel)
        HEVC_ENCODER="hevc_qsv"
        HWACCEL="qsv"
        HWOUTPUT="qsv"
        if [ "$SCALE" = "100" ]; then
            HWACCEL_PARAMS="-hwaccel ${HWACCEL} -hwaccel_output_format ${HWOUTPUT}"
        else
            HWACCEL_PARAMS="-hwaccel ${HWACCEL}"
        fi
        ;;
    cpu)
        HEVC_ENCODER="libx265"
        HWACCEL_PARAMS=""
        ;;
    *)
        echo "ERROR: Unknown hardware variant '${HW}'. Valid: nvidia, amd, intel, cpu."
        exit 1
        ;;
esac

process_file() {
    local input="$1"
    local output_dir="$2"
    local filename="$3"

    local temp_hevc
    temp_hevc="${output_dir}/${filename}_temp_hevc.mp4"

    echo "  Process 1/2: HEVC encoding for GIF..."
    if [ "${HW}" = "cpu" ]; then
        ffmpeg ${BASE_PARAMS} -i "${input}" ${SCALE_FILTER} \
            -c:v libx265 -preset slow -crf "${QUALITY}" -r "${FPS}" \
            -an -sn -dn -pix_fmt yuv444p -y "${temp_hevc}"
    else
        ffmpeg ${BASE_PARAMS} ${HWACCEL_PARAMS} -i "${input}" ${SCALE_FILTER} \
            -c:v "${HEVC_ENCODER}" -preset:v slow -cq "${QUALITY}" -r "${FPS}" \
            -an -sn -dn -pix_fmt yuv444p -y "${temp_hevc}"
    fi

    if [ $? -eq 0 ]; then
        echo "  Process 2/2: Creating GIF variants..."
        ffmpeg ${BASE_PARAMS} -i "${temp_hevc}" \
            -vf "split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=1[p];[s1][p]paletteuse=dither=1" \
            -y "${output_dir}/${filename}_bayer.gif"
        ffmpeg ${BASE_PARAMS} -i "${temp_hevc}" \
            -vf "split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=1[p];[s1][p]paletteuse=dither=5" \
            -y "${output_dir}/${filename}_sierra2_4a.gif"
        ffmpeg ${BASE_PARAMS} -i "${temp_hevc}" \
            -vf "split[s0][s1];[s0]palettegen=reserve_transparent=0:stats_mode=1[p];[s1][p]paletteuse=dither=6" \
            -y "${output_dir}/${filename}_sierra3.gif"
        rm -f "${temp_hevc}"
    else
        echo "  Error in HEVC encoding, skipping GIF process"
        rm -f "${temp_hevc}"
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