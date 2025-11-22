# FPGA图像处理模块

[English Version](README.md)

本仓库包含几十个FPGA图像处理模块的Verilog实现及其对应的测试平台。这些模块涵盖了从基础图像处理到高级计算机视觉算法的各种功能。

## 模块列表

### 1. 基础图像处理模块

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_bayer2rgb.v` | `bayer2rgb` | Bayer模式到RGB色彩空间转换，支持RGGB、BGGR、GRBG、GBRG四种模式 |
| `tb_bayer2rgb_python.v` | `bayer2rgb` | 与Python验证集成的Bayer到RGB转换测试 |
| `tb_rgb2gray.v` | `rgb2gray` | RGB图像转灰度图像 |
| `tb_rgb2gray_high_perf.v` | `rgb2gray` | 高性能RGB转灰度实现 |
| `tb_rgb2gray_sobel.v` | `rgb2gray` + `sobel` | RGB转灰度后接Sobel边缘检测 |
| `tb_gray_to_color.v` | `gray_to_color` | 灰度图像伪彩色转换 |
| `tb_ycbcr_accuracy.v` | `rgb2ycbcr` + `ycbcr2rgb` | YCbCr色彩空间转换精度测试 |
| `tb_rgb2ycbcr.v` | `rgb2ycbcr` | RGB到YCbCr色彩空间转换 |
| `tb_rgb2hsv.v` | `rgb2hsv` | RGB到HSV色彩空间转换 |
| `tb_hsv2rgb.v` | `hsv2rgb` | HSV到RGB色彩空间转换 |
| `tb_yuv422p_to_rgb.v` | `yuv422p_to_rgb` | YUV422 Planar格式到RGB转换 |
| `tb_yuyv_to_rgb.v` | `yuyv_to_rgb` | YUYV格式到RGB转换 |
| `tb_yv12_to_rgb.v` | `yv12_to_rgb` | YV12格式到RGB转换 |

### 2. 亮度和对比度调整

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_brightness_contrast.v` | `brightness_contrast` | 亮度和对比度线性变换（alpha/beta参数） |
| `tb_gray_brightness.v` | `gray_brightness` | 灰度图像亮度调整 |
| `tb_rgb_brightness.v` | `rgb_brightness` | RGB图像亮度调整 |
| `tb_white_balance.v` | `white_balance` | 白平衡调整 |

### 3. 空间滤波和卷积操作

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_mean3x3.v` | `mean3x3` | 3x3均值滤波 |
| `tb_mean7x7.v` | `mean7x7` | 7x7均值滤波 |
| `tb_mean9x9.v` | `mean9x9` | 9x9均值滤波 |
| `tb_gauss5x5.v` | `gauss5x5` | 5x5高斯滤波 |
| `tb_gauss9x9.v` | `gauss9x9` | 9x9高斯滤波 |
| `tb_median3x3.v` | `median3x3` | 3x3中值滤波 |
| `tb_median7x7.v` | `median7x7` | 7x7中值滤波 |
| `tb_median9x9.v` | `median9x9` | 9x9中值滤波 |
| `tb_bilateral3x3.v` | `bilateral3x3` | 3x3双边滤波 |
| `tb_bilateral5x5.v` | `bilateral5x5` | 5x5双边滤波 |
| `tb_bilateral9x9.v` | `bilateral9x9` | 9x9双边滤波 |

### 4. 边缘检测和特征提取

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_sobel.v` | `sobel` | Sobel边缘检测算子 |
| `tb_sobel_basic.v` | `sobel_basic` | 基础Sobel边缘检测 |
| `tb_laplacian3x3.v` | `laplacian3x3` | 3x3拉普拉斯边缘检测 |
| `tb_canny_simple.v` | `canny_simple` | 简化版Canny边缘检测 |
| `tb_canny_baby.v` | `canny` | 完整Canny边缘检测（使用baby图像） |
| `tb_emboss.v` | `emboss` | 浮雕效果滤波 |
| `tb_harris_corner.v` | `harris_corner` | Harris角点检测 |
| `tb_harris_corner_standalone.v` | `harris_corner` | 独立Harris角点检测测试 |

### 5. 形态学操作

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_erosion.v` | `erosion` | 腐蚀操作（支持黑白背景） |
| `tb_dilation.v` | `dilation` | 膨胀操作（支持黑白背景） |
| `tb_binarize.v` | `binarize` | 图像二值化 |
| `tb_threshold.v` | `threshold` | 阈值处理 |

### 6. 图像变换和几何操作

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_mirror.v` | `mirror` | 图像镜像（水平、垂直、全部） |
| `tb_homography.v` | `homography` | 单应性变换（恒等、平移、缩放） |
| `tb_homography_enhanced.v` | `homography` | 增强版单应性变换 |
| `tb_remap.v` | `remap` | 图像重映射 |
| `tb_simple_barrel_distortion.v` | `simple_barrel_distortion` | 桶形畸变校正 |

### 7. 统计和直方图操作

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_histogram.v` | `histogram` | 灰度图像直方图统计 |
| `tb_histogram_rgb.v` | `histogram_rgb` | RGB图像直方图统计 |

### 8. 图像融合和算术操作

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_image_arithmetic.v` | `image_arithmetic` | 图像算术运算（加、减、乘、除） |
| `tb_gray_weighted_merger.v` | `gray_weighted_merger` | 灰度图像加权融合 |
| `tb_rgb_weighted_merger.v` | `rgb_weighted_merger` | RGB图像加权融合 |
| `tb_rgb_merger.v` | `rgb_merger` | RGB图像合并 |
| `tb_rgb_extractor.v` | `rgb_extractor` | RGB通道提取 |

### 9. 特征描述符

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_census3x3.v` | `census3x3` | 3x3 Census变换 |
| `tb_census7x9.v` | `census7x9` | 7x9 Census变换 |

### 10. 掩码处理

| 测试文件 | Verilog模块 | 功能描述 |
|---------|------------|----------|
| `tb_mask_processor.v` | `mask_processor` | 图像掩码处理 |

## 输入文件格式说明

### PGM文件格式注意事项
- **格式要求**: 必须使用P2格式（ASCII灰度图）
- **注释处理**: 如果PGM文件中包含注释行（以`#`开头），某些测试可能无法正确加载
- **建议**: 使用预处理脚本去除注释，或使用无注释的PGM文件

### PPM文件格式注意事项  
- **格式要求**: 支持P3（ASCII）和P6（二进制）格式
- **注释处理**: 与PGM类似，注释行可能导致加载失败
- **建议**: 使用预处理后的无注释PPM文件

### RAW文件格式
- Bayer模式文件使用原始二进制格式
- 需要指定正确的图像尺寸和Bayer模式

## 仿真环境差异说明

不同仿真环境可能导致以下差异：

### 1. 时序差异
- **Icarus Verilog vs ModelSim**: 时钟周期精度和仿真速度可能不同
- **VCS vs QuestaSim**: 仿真精度和性能表现可能有所差异

### 2. 浮点运算差异
- 涉及浮点运算的模块（如色彩空间转换）在不同仿真器中可能有精度差异
- 建议使用固定点运算的模块以获得一致结果

### 3. 内存管理差异
- 大图像处理时，不同仿真器的内存管理策略可能影响性能
- 建议使用适当大小的测试图像

### 4. 文件I/O差异
- 不同仿真器对文件读写的支持可能不同
- 建议使用相对路径并确保文件权限正确

## 使用建议

1. **仿真器选择**: 推荐使用Icarus Verilog进行功能验证，商用仿真器进行时序分析
2. **测试图像**: 使用`data/`目录下的标准测试图像
3. **输出目录**: 所有输出文件将保存在`output/`目录
4. **调试**: 启用VCD文件生成进行波形调试

## 运行示例

```bash
# 编译和运行单个测试
iverilog -o tb_mirror.vvp tb_mirror.v Mirror.v
vvp tb_mirror.vvp

# 批量运行所有测试（需要编写脚本）
```

## 模块依赖关系

大多数模块可以独立运行，但某些高级模块（如`tb_rgb2gray_sobel.v`）依赖于基础模块的组合。

## 性能优化

- 使用流水线设计的模块具有更好的时序性能
- 大尺寸滤波操作使用行缓冲技术减少内存占用
- 并行处理架构用于提高吞吐量

---


## 许可协议

本项目采用木兰宽松许可证，第2版。

### 木兰宽松许可证，第2版（中文）

**木兰宽松许可证，第2版**

**2020年1月**

**http://license.coscl.org.cn/MulanPSL2**

*您对"软件"的复制、使用、修改及分发受木兰宽松许可证，第2版（"本许可证"）的约束。*

*本软件按"原样"提供，没有任何明示或暗示的保证，包括但不限于对适销性、特定用途适用性和非侵权性的保证。*

*整个软件的质量和性能风险由您承担。如果软件出现缺陷，您应承担所有必要的服务、修复或更正费用。*

*除非适用法律要求或书面同意，任何版权持有人或任何其他可能修改和/或重新分发软件的人，均不对您因使用或无法使用软件而造成的任何损害（包括但不限于数据丢失或数据不准确、您或第三方遭受的损失或软件无法与其他软件一起运行）承担责任，即使此类持有人或其他方已被告知此类损害的可能性。*

**条款和条件结束**

---

**附录：木兰宽松许可证，第2版（英文）**

**Mulan Permissive Software License，Version 2 (Mulan PSL v2)**

**January 2020**

**http://license.coscl.org.cn/MulanPSL2**

*Your reproduction, use, modification and distribution of the Software shall be subject to Mulan PSL v2.*

*This software is provided on an "AS IS" basis, without warranty of any kind, either expressed or implied, including without limitation, warranties of merchantability or fitness for a particular purpose.*

*The entire risk as to the quality and performance of the software is with you. Should the software prove defective, you assume the cost of all necessary servicing, repair or correction.*

*In no event unless required by applicable law or agreed to in writing will any copyright holder, or any other party who may modify and/or redistribute the software, be liable to you for damages, including any general, special, incidental or consequential damages arising out of the use or inability to use the software (including but not limited to loss of data or data being rendered inaccurate or losses sustained by you or third parties or a failure of the software to operate with any other software), even if such holder or other party has been advised of the possibility of such damages.*

**END OF TERMS AND CONDITIONS**