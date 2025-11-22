import cv2

def jpg_to_yuv422_packed(jpg_path, yuv_path):
    img = cv2.imread(jpg_path)
    if img is None:
        print(f"Error: Cannot read image {jpg_path}")
        return

    yuv_yuyv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV_YUYV)

    yuv_yuyv.tofile(yuv_path)
    print(f"Conversion successful! Packed format YUYV (YUV422) file saved to {yuv_path}")

if __name__ == "__main__":
    jpg_to_yuv422_packed("../data/color2.jpg", "../data/color2_320x466.yuyv")