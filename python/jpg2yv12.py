import cv2

def jpg_to_yuv422_opencv(jpg_path, yuv_path):
    img = cv2.imread(jpg_path)
    if img is None:
        print(f"Error: Cannot read image {jpg_path}")
        return

    yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV_YV12)

    yuv.tofile(yuv_path)
    print(f"Conversion successful! YUV422 file saved to {yuv_path}")

if __name__ == "__main__":
    input_jpg = "../data/color2.jpg"
    output_yuv = "../data/color2_320x466_yv12.yuv"
    jpg_to_yuv422_opencv(input_jpg, output_yuv)