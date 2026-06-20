# FFMPEG Video Compressor

Cross-platform batch wrapper for FFmpeg hardware-accelerated video encoding.

- Efficient H.264 video processing with an optimised quality-to-size ratio using two-process encoding.
- First pass with HEVC (H.265) for high quality and efficiency, then downgrade to H.264 for wider hardware support. (Without this first pass, the final H.264 outputs a larger file.)
- H.264 and GIF always use a two-stage process; HEVC/H.265 is a single-stage process.
- Supports NVIDIA NVENC, AMD AMF and Intel QSV hardware encoders on Windows and Linux.
- If the selected hardware encoder is unavailable, the script automatically falls back to CPU encoding (`libx264` / `libx265`) and prints the reason.
- GIF encoding produces three palette-optimised variants: Bayer, Sierra2_4a and Sierra3.
- Intended for archival purposes, not live streaming.

## Requirements

- FFmpeg 7.1 or newer with the appropriate hardware encoder enabled:
  - **NVIDIA:** `h264_nvenc`, `hevc_nvenc`
  - **AMD:** `h264_amf`, `hevc_amf` (Windows: DX11 / Linux: Vulkan)
  - **Intel:** `h264_qsv`, `hevc_qsv`
- On Linux, static builds (e.g. johnvansickle.com) usually do **not** include NVENC/AMF/QSV. Use your distribution's `ffmpeg` package for hardware acceleration.
- Windows 10/11 for `Encode.bat`, or a Linux/macOS shell for `encode.sh`.
- Input videos placed in the `Input/` folder. Output is written to `Output/` while preserving the subdirectory structure.

## Files

| File | Purpose |
|------|---------|
| `Encode.bat` | Windows orchestrator |
| `encode.sh` | Linux / macOS orchestrator |
| `lib/encode_nvidia.bat` | Windows NVIDIA H.264/H.265 encoding sub-script |
| `lib/encode_amd.bat` | Windows AMD H.264/H.265 encoding sub-script |
| `lib/encode_intel.bat` | Windows Intel H.264/H.265 encoding sub-script |
| `lib/encode_cpu.bat` | Windows CPU fallback H.264/H.265 sub-script |
| `lib/encode_gif.bat` | Windows GIF encoding sub-script (hardware or CPU first pass) |
| `lib/encode_nvidia.sh` | Linux NVIDIA H.264/H.265 encoding sub-script |
| `lib/encode_amd.sh` | Linux AMD H.264/H.265 encoding sub-script |
| `lib/encode_intel.sh` | Linux Intel H.264/H.265 encoding sub-script |
| `lib/encode_cpu.sh` | Linux CPU fallback H.264/H.265 sub-script |
| `lib/encode_gif.sh` | Linux GIF encoding sub-script (hardware or CPU first pass) |

## Usage

### Windows

1. Place videos in `Input\`.
2. Double-click `Encode.bat` or run it from a command prompt.
3. Select the format and hardware accelerator in one menu.
4. Answer the audio, quality, FPS and scale prompts.
5. Encoded files appear in `Output\`.

### Linux / macOS

1. Place videos in `Input/`.
2. Run:
   ```bash
   ./encode.sh
   ```
3. Select the format and hardware accelerator.
4. Answer the audio, quality, FPS and scale prompts.
5. Encoded files appear in `Output/`.

## Notes

- The FFmpeg command chains and encoder parameters are preserved from the original Windows scripts. Only the wrapper logic, parameter passing and cross-platform paths were changed.
- PNG encoding was removed because it was not as useful as the video and GIF workflows.
- The old batch files have been moved to the `archive/` folder for reference.
- All encoders (Linux `.sh` and Windows `.bat`) now force output to 8-bit `yuv420p` and round width/height to even numbers. This fixes two common failures:
  - odd-resolution inputs causing `Picture width must be an integer multiple of the specified chroma subsampling`
  - 10-bit (or other high-bit-depth) inputs being rejected by 8-bit hardware encoders

*Note: GitHub Copilot assisted with command structure layout. All FFmpeg parameters are based on personal research and optimisation.*
