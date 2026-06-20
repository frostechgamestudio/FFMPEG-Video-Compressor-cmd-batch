#!/usr/bin/env bash

# ===== FFMPEG VIDEO COMPRESSOR TEST SUITE =====
# Generates small 4-frame blank input videos covering common edge cases so
# every lib/ encoder mode can be exercised automatically.
#
# Usage:
#   ./test.sh              Generate test inputs in TestInput/
#   ./test.sh -r|--run     Generate inputs AND run CPU smoke tests through lib/
#   ./test.sh -c|--clean   Remove TestInput/ and Output/
#   ./test.sh -h|--help    Show usage

set -u

TEST_DIR="TestInput"
OUTPUT_DIR="Output"
FFMPEG_BIN="$(command -v ffmpeg)"

show_usage() {
    cat <<EOF
Usage: $0 [OPTION]

Generate 4-frame blank test videos for the FFMPEG-Video-Compressor lib/ scripts.

Options:
  -r, --run     Generate inputs and run a CPU-only smoke test through all lib/ modes
  -c, --clean   Remove ${TEST_DIR}/ and ${OUTPUT_DIR}/
  -h, --help    Show this help message

Examples:
  $0
  $0 --run
  $0 --clean
EOF
}

# Parse arguments
RUN_TESTS=false
CLEAN_ONLY=false

while [ $# -gt 0 ]; do
    case "$1" in
        -r|--run) RUN_TESTS=true; shift ;;
        -c|--clean) CLEAN_ONLY=true; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) echo "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

# Clean mode
if [ "${CLEAN_ONLY}" = true ]; then
    echo "Cleaning test artifacts..."
    rm -rf "${TEST_DIR}" "${OUTPUT_DIR}"
    echo "Done."
    exit 0
fi

# Validate FFmpeg
if [ -z "${FFMPEG_BIN}" ]; then
    echo "ERROR: FFmpeg not found in PATH."
    echo "Install FFmpeg 7.1+ or add it to system PATH."
    echo "Download: https://ffmpeg.org/download.html"
    exit 1
fi

# Prepare test directory
mkdir -p "${TEST_DIR}"
rm -f "${TEST_DIR}"/*

echo "Generating 4-frame blank test videos in ${TEST_DIR}/..."
echo

# Common FFmpeg flags
BASE_FLAGS=(-hide_banner -loglevel warning -stats -y)
FPS=30
FRAMES=4

generate_video() {
    local output_file="$1"
    local width="$2"
    local height="$3"
    local pix_fmt="$4"
    local with_audio="$5"
    local container="$6"

    local size="${width}x${height}"
    local base_name
    base_name="$(basename "${output_file%.*}")"
    local video_source="color=c=black:s=${size}:r=${FPS}"

    if [ "${with_audio}" = "yes" ]; then
        "${FFMPEG_BIN}" "${BASE_FLAGS[@]}" \
            -f lavfi -i "${video_source}" \
            -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
            -c:v libx264 -preset ultrafast -pix_fmt "${pix_fmt}" \
            -c:a aac -q:a 0.75 \
            -frames:v "${FRAMES}" -shortest \
            "${output_file}"
    else
        "${FFMPEG_BIN}" "${BASE_FLAGS[@]}" \
            -f lavfi -i "${video_source}" \
            -c:v libx264 -preset ultrafast -pix_fmt "${pix_fmt}" \
            -an \
            -frames:v "${FRAMES}" \
            "${output_file}"
    fi

    if [ $? -eq 0 ]; then
        echo "  [OK] ${base_name}"
    else
        echo "  [FAIL] ${base_name}"
        return 1
    fi
}

# Generate the test matrix
generate_video "${TEST_DIR}/blank_8bit_even.mp4"     1920 1080 yuv420p      yes mp4
generate_video "${TEST_DIR}/blank_8bit_odd.mp4"      1919 1079 yuv420p      yes mp4
generate_video "${TEST_DIR}/blank_10bit_even.mp4"   1920 1080 yuv420p10le  yes mp4
generate_video "${TEST_DIR}/blank_10bit_odd.mp4"     1919 1079 yuv420p10le  yes mp4
generate_video "${TEST_DIR}/blank_8bit_no_audio.mp4" 1280  720 yuv420p      no  mp4
generate_video "${TEST_DIR}/blank_480p_8bit.mp4"      854  480 yuv420p      yes mp4
generate_video "${TEST_DIR}/blank_8bit_avi.avi"       640  480 yuv420p      yes avi
generate_video "${TEST_DIR}/blank_8bit_mkv.mkv"       640  480 yuv420p      yes mkv

echo
echo "Test inputs ready in ${TEST_DIR}/"
echo

# Print suggested manual test commands
cat <<'EOF'
Suggested lib/ test commands (CPU fallback, safe on any system):

  bash lib/encode_cpu.sh h264 1 23 60 100
  bash lib/encode_cpu.sh hevc 1 23 60 100
  bash lib/encode_cpu.sh h264 2 23 30  50
  bash lib/encode_gif.sh cpu 2 23 15  75

Replace 'cpu' with 'nvidia', 'amd', or 'intel' if hardware encoders are available.
EOF

# Smoke-test mode: run all CPU-safe lib/ scripts
if [ "${RUN_TESTS}" = true ]; then
    echo
    echo "===== RUNNING CPU SMOKE TESTS ====="

    # Temporarily point lib scripts at TestInput. Preserve an existing Input/.
    if [ -d "Input" ] || [ -L "Input" ]; then
        mv "Input" "Input.testbak"
    fi
    mkdir -p "Input"
    cp -r "${TEST_DIR}/"* "Input/"

    run_mode() {
        local script="$1"
        shift
        echo
        echo ">>> Running: bash ${script} $*"
        bash "${script}" "$@"
    }

    # H.264 / HEVC CPU modes
    run_mode "lib/encode_cpu.sh" h264 1 23 60 100
    run_mode "lib/encode_cpu.sh" hevc 1 23 60 100
    run_mode "lib/encode_cpu.sh" h264 2 28 30  50

    # GIF CPU mode
    run_mode "lib/encode_gif.sh" cpu 2 23 15 75

    # Remove the temporary Input/ and restore any backed-up Input/
    rm -rf "Input"
    if [ -d "Input.testbak" ] || [ -L "Input.testbak" ]; then
        mv "Input.testbak" "Input"
    fi

    echo
    echo "===== SMOKE TESTS COMPLETE ====="
    echo "Outputs are in ${OUTPUT_DIR}/"
    echo "Run '$0 --clean' to remove test artifacts."
fi