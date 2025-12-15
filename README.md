# FFMPEG Batch Commands

- Efficient H.264 video processing with optimised quality-to-size ratio using two-process encoding.
- First HEVC (H.265) for high quality and efficiency, then downgrade to H.264 for wider hardware support.
- (without this first pass, the final H.264 outputs a larger file based on my testing, Raw to H.264)
- The Encoding commands are intended for archival purposes only, meaning not meant for live streaming.
- This is extremely slow encoding, that's why you need to have a GPU to make this work (Nvidia, Intel and AMD)
- GIF and PNG encoding use palette generation for best quality at minimal file size.
- GIF encoding gives the best results with two-process encoding.

## Requirements:
 - Any one of Nvidia CUDA GPU Or Intel Quick Sync GPU, or AMD DX11 GPU
 - [FFMPEG](https://ffmpeg.org/download.html) v7.1.1
 - Windows OS to run batch command files as is. (Though ffmpeg commands used in these scripts should get exact results on any ffmpeg supported platforms, though need to convert batch operations accordingly.)

## Files
- `QueueEncodeGPU_Mp4.bat` - GPU-accelerated HEVC encoding and two-process H.264 encoding
- `QueueEncode_Gif.bat` - two-process Palette-optimized GIF creation
- `QueueEncode_TinyPng.bat` - Palette-optimized PNG creation (however, tinypng still beats me)

*Note: GitHub Copilot assisted with command structure layout. But all FFmpeg parameters are based on personal research and optimisation.* 
