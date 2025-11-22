import cv2
import numpy as np

def jpg_to_yuv422_planar(jpg_path, yuv_path):
    img = cv2.imread(jpg_path)
    if img is None:
        print(f"Error: Cannot read image {jpg_path}")
        return
    height, width = img.shape[:2]

    yuv_444p = cv2.cvtColor(img, cv2.COLOR_BGR2YUV)
    
    y_plane = yuv_444p[..., 0]
    u_plane = yuv_444p[..., 1]
    v_plane = yuv_444p[..., 2]

    u_plane_downsampled = cv2.resize(u_plane, (width // 2, height), interpolation=cv2.INTER_AREA)
    v_plane_downsampled = cv2.resize(v_plane, (width // 2, height), interpolation=cv2.INTER_AREA)
    
    with open(yuv_path, 'wb') as f:
        f.write(y_plane.tobytes())
        f.write(u_plane_downsampled.tobytes())
        f.write(v_plane_downsampled.tobytes())
        
    print(f"Conversion successful! Planar format I422 (YUV422P) file saved to {yuv_path}")

if __name__ == "__main__":
    jpg_to_yuv422_planar("../data/color2.jpg", "../data/color2_320x466.yuv422p")