import cv2
import numpy as np

def rgb_to_bayer(rgb_img, pattern='BGGR'):
    if len(rgb_img.shape) != 3 or rgb_img.shape[2] != 3:
        raise ValueError("Input image must be RGB format (H, W, 3)")

    pattern = pattern.upper()
    if pattern not in ['BGGR', 'GRBG', 'GBRG', 'RGGB']:
        raise ValueError("Unsupported Bayer pattern, please choose 'BGGR', 'GRBG', 'GBRG' or 'RGGB'")

    height, width = rgb_img.shape[:2]
    bayer_img = np.zeros((height, width), dtype=np.uint8)

    r_channel = rgb_img[..., 0]
    g_channel = rgb_img[..., 1]
    b_channel = rgb_img[..., 2]

    if pattern == 'BGGR':
        bayer_img[::2, ::2] = b_channel[::2, ::2]
        bayer_img[::2, 1::2] = g_channel[::2, 1::2]
        bayer_img[1::2, ::2] = g_channel[1::2, ::2]
        bayer_img[1::2, 1::2] = r_channel[1::2, 1::2]
    elif pattern == 'GRBG':
        bayer_img[::2, ::2] = g_channel[::2, ::2]
        bayer_img[::2, 1::2] = r_channel[::2, 1::2]
        bayer_img[1::2, ::2] = b_channel[1::2, ::2]
        bayer_img[1::2, 1::2] = g_channel[1::2, 1::2]
    elif pattern == 'GBRG':
        bayer_img[::2, ::2] = g_channel[::2, ::2]
        bayer_img[::2, 1::2] = b_channel[::2, 1::2]
        bayer_img[1::2, ::2] = r_channel[1::2, ::2]
        bayer_img[1::2, 1::2] = g_channel[1::2, 1::2]
    elif pattern == 'RGGB':
        bayer_img[::2, ::2] = r_channel[::2, ::2]
        bayer_img[::2, 1::2] = g_channel[::2, 1::2]
        bayer_img[1::2, ::2] = g_channel[1::2, ::2]
        bayer_img[1::2, 1::2] = b_channel[1::2, 1::2]

    return bayer_img

def jpg_to_bayer(jpg_path, bayer_path, pattern='BGGR'):
    img = cv2.imread(jpg_path)
    if img is None:
        print(f"Error: Cannot read image {jpg_path}")
        return

    rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    bayer_img = rgb_to_bayer(rgb_img, pattern)

    bayer_img.tofile(bayer_path)
    print(f"Conversion successful! Bayer file saved to {bayer_path}")

if __name__ == "__main__":
    jpg_to_bayer("../data/color2.jpg", "../data/color2_bayer_bggr.raw", "BGGR")
    jpg_to_bayer("../data/color2.jpg", "../data/color2_bayer_grbg.raw", "GRBG")
    jpg_to_bayer("../data/color2.jpg", "../data/color2_bayer_gbrg.raw", "GBRG")
    jpg_to_bayer("../data/color2.jpg", "../data/color2_bayer_rggb.raw", "RGGB")