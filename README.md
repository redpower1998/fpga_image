# FPGA Image Processing Module

[中文版](README_chs.md)

This repository contains dozens of FPGA image processing modules implemented in Verilog along with their corresponding testbenches. These modules cover a wide range of functionalities from basic image processing to advanced computer vision algorithms.

## Module List

### 1. Basic Image Processing Modules

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_bayer2rgb.v` | `bayer2rgb` | Bayer pattern to RGB color space conversion, supports RGGB, BGGR, GRBG, GBRG four modes |
| `tb_bayer2rgb_python.v` | `bayer2rgb` | Bayer to RGB conversion test integrated with Python verification |
| `tb_rgb2gray.v` | `rgb2gray` | RGB image to grayscale conversion |
| `tb_rgb2gray_high_perf.v` | `rgb2gray` | High-performance RGB to grayscale implementation |
| `tb_rgb2gray_sobel.v` | `rgb2gray` + `sobel` | RGB to grayscale followed by Sobel edge detection |
| `tb_gray_to_color.v` | `gray_to_color` | Grayscale image pseudo-color conversion |
| `tb_ycbcr_accuracy.v` | `rgb2ycbcr` + `ycbcr2rgb` | YCbCr color space conversion accuracy test |
| `tb_rgb2ycbcr.v` | `rgb2ycbcr` | RGB to YCbCr color space conversion |
| `tb_rgb2hsv.v` | `rgb2hsv` | RGB to HSV color space conversion |
| `tb_hsv2rgb.v` | `hsv2rgb` | HSV to RGB color space conversion |
| `tb_yuv422p_to_rgb.v` | `yuv422p_to_rgb` | YUV422 Planar format to RGB conversion |
| `tb_yuyv_to_rgb.v` | `yuyv_to_rgb` | YUYV format to RGB conversion |
| `tb_yv12_to_rgb.v` | `yv12_to_rgb` | YV12 format to RGB conversion |

### 2. Brightness and Contrast Adjustment

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_brightness_contrast.v` | `brightness_contrast` | Linear brightness and contrast transformation (alpha/beta parameters) |
| `tb_gray_brightness.v` | `gray_brightness` | Grayscale image brightness adjustment |
| `tb_rgb_brightness.v` | `rgb_brightness` | RGB image brightness adjustment |
| `tb_white_balance.v` | `white_balance` | White balance adjustment |

### 3. Spatial Filtering and Convolution Operations

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_mean3x3.v` | `mean3x3` | 3x3 mean filtering |
| `tb_mean7x7.v` | `mean7x7` | 7x7 mean filtering |
| `tb_mean9x9.v` | `mean9x9` | 9x9 mean filtering |
| `tb_gauss5x5.v` | `gauss5x5` | 5x5 Gaussian filtering |
| `tb_gauss9x9.v` | `gauss9x9` | 9x9 Gaussian filtering |
| `tb_median3x3.v` | `median3x3` | 3x3 median filtering |
| `tb_median7x7.v` | `median7x7` | 7x7 median filtering |
| `tb_median9x9.v` | `median9x9` | 9x9 median filtering |
| `tb_bilateral3x3.v` | `bilateral3x3` | 3x3 bilateral filtering |
| `tb_bilateral5x5.v` | `bilateral5x5` | 5x5 bilateral filtering |
| `tb_bilateral9x9.v` | `bilateral9x9` | 9x9 bilateral filtering |

### 4. Edge Detection and Feature Extraction

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_sobel.v` | `sobel` | Sobel edge detection operator |
| `tb_sobel_basic.v` | `sobel_basic` | Basic Sobel edge detection |
| `tb_laplacian3x3.v` | `laplacian3x3` | 3x3 Laplacian edge detection |
| `tb_canny_simple.v` | `canny_simple` | Simplified Canny edge detection |
| `tb_canny_baby.v` | `canny` | Full Canny edge detection (using baby image) |
| `tb_emboss.v` | `emboss` | Emboss effect filtering |
| `tb_harris_corner.v` | `harris_corner` | Harris corner detection |
| `tb_harris_corner_standalone.v` | `harris_corner` | Standalone Harris corner detection test |

### 5. Morphological Operations

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_erosion.v` | `erosion` | Erosion operation (supports black/white background) |
| `tb_dilation.v` | `dilation` | Dilation operation (supports black/white background) |
| `tb_binarize.v` | `binarize` | Image binarization |
| `tb_threshold.v` | `threshold` | Threshold processing |

### 6. Image Transformation and Geometric Operations

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_mirror.v` | `mirror` | Image mirroring (horizontal, vertical, all) |
| `tb_homography.v` | `homography` | Homography transformation (identity, translation, scaling) |
| `tb_homography_enhanced.v` | `homography` | Enhanced homography transformation |
| `tb_remap.v` | `remap` | Image remapping |
| `tb_simple_barrel_distortion.v` | `simple_barrel_distortion` | Barrel distortion correction |

### 7. Statistical and Histogram Operations

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_histogram.v` | `histogram` | Grayscale image histogram statistics |
| `tb_histogram_rgb.v` | `histogram_rgb` | RGB image histogram statistics |

### 8. Image Fusion and Arithmetic Operations

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_image_arithmetic.v` | `image_arithmetic` | Image arithmetic operations (add, subtract, multiply, divide) |
| `tb_gray_weighted_merger.v` | `gray_weighted_merger` | Grayscale image weighted fusion |
| `tb_rgb_weighted_merger.v` | `rgb_weighted_merger` | RGB image weighted fusion |
| `tb_rgb_merger.v` | `rgb_merger` | RGB image merging |
| `tb_rgb_extractor.v` | `rgb_extractor` | RGB channel extraction |

### 9. Feature Descriptors

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_census3x3.v` | `census3x3` | 3x3 Census transform |
| `tb_census7x9.v` | `census7x9` | 7x9 Census transform |

### 10. Mask Processing

| Testbench File | Verilog Module | Function Description |
|---------------|----------------|---------------------|
| `tb_mask_processor.v` | `mask_processor` | Image mask processing |

## Input File Format Specifications

### PGM File Format Notes
- **Format Requirement**: Must use P2 format (ASCII grayscale)
- **Comment Handling**: If PGM files contain comment lines (starting with `#`), some tests may fail to load correctly
- **Recommendation**: Use preprocessing scripts to remove comments, or use PGM files without comments

### PPM File Format Notes
- **Format Requirement**: Supports P3 (ASCII) and P6 (binary) formats
- **Comment Handling**: Similar to PGM, comment lines may cause loading failures
- **Recommendation**: Use preprocessed PPM files without comments

### RAW File Format
- Bayer pattern files use raw binary format
- Requires correct image dimensions and Bayer pattern specification

## Simulation Environment Differences

Different simulation environments may cause the following differences:

### 1. Timing Differences
- **Icarus Verilog vs ModelSim**: Clock cycle precision and simulation speed may differ
- **VCS vs QuestaSim**: Simulation accuracy and performance may vary

### 2. Floating-Point Operation Differences
- Modules involving floating-point operations (such as color space conversion) may have precision differences across simulators
- Recommendation: Use fixed-point operation modules for consistent results

### 3. Memory Management Differences
- When processing large images, different simulators' memory management strategies may affect performance
- Recommendation: Use appropriately sized test images

### 4. File I/O Differences
- Different simulators may have varying support for file read/write operations
- Recommendation: Use relative paths and ensure correct file permissions

## Usage Recommendations

1. **Simulator Selection**: Recommended to use Icarus Verilog for functional verification, commercial simulators for timing analysis
2. **Test Images**: Use standard test images from the `data/` directory
3. **Output Directory**: All output files will be saved in the `output/` directory
4. **Debugging**: Enable VCD file generation for waveform debugging

## Running Examples

```bash
# Compile and run a single test
iverilog -o tb_mirror.vvp tb_mirror.v Mirror.v
vvp tb_mirror.vvp

# Batch run all tests (requires script writing)
```

## Module Dependencies

Most modules can run independently, but some advanced modules (such as `tb_rgb2gray_sobel.v`) depend on combinations of basic modules.

## Performance Optimization

- Modules using pipeline design have better timing performance
- Large-size filtering operations use line buffer technology to reduce memory usage
- Parallel processing architecture is used to improve throughput

---


## License

This project is licensed under the Mulan Permissive Software License, Version 2.

### Mulan Permissive Software License, Version 2 (English)

**Mulan Permissive Software License，Version 2 (Mulan PSL v2)**

**January 2020**

**http://license.coscl.org.cn/MulanPSL2**

*Your reproduction, use, modification and distribution of the Software shall be subject to Mulan PSL v2.*

*This software is provided on an "AS IS" basis, without warranty of any kind, either expressed or implied, including without limitation, warranties of merchantability or fitness for a particular purpose.*

*The entire risk as to the quality and performance of the software is with you. Should the software prove defective, you assume the cost of all necessary servicing, repair or correction.*

*In no event unless required by applicable law or agreed to in writing will any copyright holder, or any other party who may modify and/or redistribute the software, be liable to you for damages, including any general, special, incidental or consequential damages arising out of the use or inability to use the software (including but not limited to loss of data or data being rendered inaccurate or losses sustained by you or third parties or a failure of the software to operate with any other software), even if such holder or other party has been advised of the possibility of such damages.*

**END OF TERMS AND CONDITIONS**

---

**Appendix: Mulan Permissive Software License, Version 2 (Chinese)**

**木兰宽松许可证，第2版**

**2020年1月**

**http://license.coscl.org.cn/MulanPSL2**

*您对"软件"的复制、使用、修改及分发受木兰宽松许可证，第2版（"本许可证"）的约束。*

*本软件按"原样"提供，没有任何明示或暗示的保证，包括但不限于对适销性、特定用途适用性和非侵权性的保证。*

*整个软件的质量和性能风险由您承担。如果软件出现缺陷，您应承担所有必要的服务、修复或更正费用。*

*除非适用法律要求或书面同意，任何版权持有人或任何其他可能修改和/或重新分发软件的人，均不对您因使用或无法使用软件而造成的任何损害（包括但不限于数据丢失或数据不准确、您或第三方遭受的损失或软件无法与其他软件一起运行）承担责任，即使此类持有人或其他方已被告知此类损害的可能性。*

**条款和条件结束**